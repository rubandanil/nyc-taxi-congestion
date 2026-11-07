"""Загружает parquet-файлы поездок и справочник районов в схему raw.

Загрузка идемпотентна: каждый месяц грузится в одной транзакции — сначала
DELETE строк этого месяца, потом вставка через COPY. Повторный запуск
не создаёт дублей. Справочник районов перезаписывается целиком.
"""

import io
from datetime import date
from pathlib import Path

import pyarrow as pa
import pyarrow.csv as pacsv
import pyarrow.parquet as pq

import db
from download import DATA_DIR, MONTHS

SQL_DIR = Path(__file__).resolve().parent.parent / "sql"

# Колонка в raw.trips -> колонка в parquet (имена parquet в нижнем регистре).
COLUMNS = {
    "pickup_datetime": "tpep_pickup_datetime",
    "dropoff_datetime": "tpep_dropoff_datetime",
    "pulocationid": "pulocationid",
    "dolocationid": "dolocationid",
    "trip_distance": "trip_distance",
    "fare_amount": "fare_amount",
    "tip_amount": "tip_amount",
    "total_amount": "total_amount",
    "payment_type": "payment_type",
    "cbd_congestion_fee": "cbd_congestion_fee",
}

BATCH_ROWS = 500_000


def read_batches(path):
    """Читает parquet частями и отдаёт таблицы с колонками как в raw.trips.

    Регистр имён в файлах отличается (Airport_fee / airport_fee), поэтому
    сравниваем в нижнем регистре. Колонки, которых в файле нет
    (cbd_congestion_fee в 2024 году), заполняются NULL.
    """
    parquet_file = pq.ParquetFile(path)
    name_in_file = {name.lower(): name for name in parquet_file.schema_arrow.names}
    present = [name_in_file[c] for c in COLUMNS.values() if c in name_in_file]

    for batch in parquet_file.iter_batches(batch_size=BATCH_ROWS, columns=present):
        table = pa.Table.from_batches([batch])
        table = table.rename_columns([name.lower() for name in table.column_names])
        columns = []
        for source in COLUMNS.values():
            if source in table.column_names:
                columns.append(table.column(source))
            else:
                columns.append(pa.nulls(table.num_rows, pa.float64()))
        yield pa.table(columns, names=list(COLUMNS))


def copy_table(cursor, table, target, columns):
    """Отправляет pyarrow-таблицу в Postgres через COPY в формате CSV.

    CSV здесь быстрее построчной вставки: pyarrow пишет его целиком в памяти,
    а Postgres разбирает поток сам. Пустое поле в CSV читается как NULL.
    """
    buffer = io.BytesIO()
    pacsv.write_csv(table, buffer, write_options=pacsv.WriteOptions(include_header=False))
    sql = f"COPY {target} ({', '.join(columns)}) FROM STDIN WITH (FORMAT csv)"
    with cursor.copy(sql) as copy:
        copy.write(buffer.getvalue())


def load_month(conn, month):
    path = DATA_DIR / f"yellow_tripdata_{month}.parquet"
    source_month = date.fromisoformat(month + "-01")
    rows = 0
    with conn.cursor() as cursor:
        cursor.execute("DELETE FROM raw.trips WHERE source_month = %s", (source_month,))
        for table in read_batches(path):
            month_column = pa.array([source_month] * table.num_rows, pa.date32())
            table = table.append_column("source_month", month_column)
            copy_table(cursor, table, "raw.trips", list(COLUMNS) + ["source_month"])
            rows += table.num_rows
    conn.commit()  # DELETE и все COPY месяца попадают в базу вместе
    print(f"{month}: загружено {rows:,} строк")


def load_zones(conn):
    path = DATA_DIR / "taxi_zone_lookup.csv"
    with conn.cursor() as cursor:
        cursor.execute("TRUNCATE raw.zones")
        with open(path, "rb") as f, cursor.copy("COPY raw.zones FROM STDIN WITH (FORMAT csv, HEADER)") as copy:
            copy.write(f.read())
    conn.commit()
    print("справочник районов загружен")


def print_row_counts(conn):
    rows = conn.execute(
        "SELECT source_month, count(*) FROM raw.trips GROUP BY source_month ORDER BY source_month"
    ).fetchall()
    print("\nстрок в raw.trips по месяцам:")
    for source_month, count in rows:
        print(f"  {source_month:%Y-%m}: {count:,}")
    zones = conn.execute("SELECT count(*) FROM raw.zones").fetchone()[0]
    print(f"строк в raw.zones: {zones}")


def main():
    with db.get_connection() as conn:
        db.run_sql_file(conn, SQL_DIR / "01_schema.sql")
        conn.commit()
        load_zones(conn)
        for month in MONTHS:
            load_month(conn, month)
        print_row_counts(conn)


if __name__ == "__main__":
    main()
