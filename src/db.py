"""Подключение к PostgreSQL.

Параметры берутся из переменных окружения PGHOST, PGPORT, PGDATABASE,
PGUSER, PGPASSWORD (те же имена понимает psql).

Значения по умолчанию рассчитаны на Postgres.app: сервер на localhost:5432,
роль с именем пользователя macOS, без пароля. Для запасного варианта
с docker-compose.yml перед запуском задайте PGUSER=taxi и PGPASSWORD=taxi.
"""

import getpass
import os

import psycopg
from sqlalchemy import create_engine


def get_db_params():
    return {
        "host": os.getenv("PGHOST", "localhost"),
        "port": int(os.getenv("PGPORT", "5432")),
        "dbname": os.getenv("PGDATABASE", "taxi"),
        "user": os.getenv("PGUSER", getpass.getuser()),
        "password": os.getenv("PGPASSWORD", ""),
    }


def get_connection():
    """Подключение psycopg 3: для COPY, DDL и обычных запросов."""
    return psycopg.connect(**get_db_params())


def get_engine():
    """Движок SQLAlchemy: нужен pandas.read_sql в ноутбуках."""
    p = get_db_params()
    url = (
        f"postgresql+psycopg://{p['user']}:{p['password']}"
        f"@{p['host']}:{p['port']}/{p['dbname']}"
    )
    return create_engine(url)


def run_sql_file(conn, path):
    """Выполняет SQL-файл целиком одним запросом (несколько команд через ';')."""
    with open(path, encoding="utf-8") as f:
        conn.execute(f.read())
