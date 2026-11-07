"""Прогоняет SQL-файлы из sql/ по порядку и печатает число строк в итоговых таблицах.

Запуск без аргументов выполняет все файлы. Можно передать префиксы имён,
чтобы выполнить только часть: `python src/build.py 04 05`.
"""

import sys
import time
from pathlib import Path

import db

SQL_DIR = Path(__file__).resolve().parent.parent / "sql"

RESULT_TABLES = [
    "core.trips",
    "core.rejected_summary",
    "core.zones",
    "mart.daily_group_metrics",
    "mart.daily_diff",
    "mart.ml_trips",
]


def main(prefixes):
    sql_files = sorted(SQL_DIR.glob("*.sql"))
    if prefixes:
        sql_files = [f for f in sql_files if f.name.startswith(tuple(prefixes))]

    with db.get_connection() as conn:
        for path in sql_files:
            started = time.time()
            db.run_sql_file(conn, path)
            conn.commit()
            print(f"{path.name}: {time.time() - started:.0f} с")

        print("\nстрок в таблицах:")
        for table in RESULT_TABLES:
            exists = conn.execute("SELECT to_regclass(%s)", (table,)).fetchone()[0]
            if exists is None:
                print(f"  {table}: нет")
                continue
            count = conn.execute(f"SELECT count(*) FROM {table}").fetchone()[0]
            print(f"  {table}: {count:,}")


if __name__ == "__main__":
    main(sys.argv[1:])
