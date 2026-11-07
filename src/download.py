"""Скачивает шесть месяцев поездок жёлтого такси и справочник районов в data/.

Уже скачанные файлы пропускаются. Файл сначала пишется во временное имя
с суффиксом .part и переименовывается только после полной загрузки,
поэтому оборванное скачивание не будет принято за готовый файл.
"""

from pathlib import Path

import requests

MONTHS = ["2024-10", "2024-11", "2024-12", "2025-01", "2025-02", "2025-03"]
TRIPS_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_{month}.parquet"
ZONES_URL = "https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv"

DATA_DIR = Path(__file__).resolve().parent.parent / "data"


def download_file(url, path):
    if path.exists():
        print(f"пропуск, уже есть: {path.name}")
        return

    part = path.with_suffix(path.suffix + ".part")
    with requests.get(url, stream=True, timeout=60) as response:
        response.raise_for_status()
        with open(part, "wb") as f:
            for chunk in response.iter_content(chunk_size=1 << 20):
                f.write(chunk)
    part.rename(path)
    print(f"скачан: {path.name} ({path.stat().st_size / 1e6:.1f} МБ)")


def main():
    DATA_DIR.mkdir(exist_ok=True)
    for month in MONTHS:
        download_file(TRIPS_URL.format(month=month), DATA_DIR / f"yellow_tripdata_{month}.parquet")
    download_file(ZONES_URL, DATA_DIR / "taxi_zone_lookup.csv")


if __name__ == "__main__":
    main()
