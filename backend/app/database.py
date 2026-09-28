import os
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Generator

BASE_DIR = Path(__file__).resolve().parent.parent
DEFAULT_DB_PATH = str(BASE_DIR / "pukaar.db")


def get_db_path() -> str:
    """Returns the SQLite database file path, honoring PUKAAR_DB_PATH env var if set."""
    return os.environ.get("PUKAAR_DB_PATH", DEFAULT_DB_PATH)


@contextmanager
def get_connection() -> Generator[sqlite3.Connection, None, None]:
    """Context manager providing a managed SQLite connection with WAL mode and foreign keys enabled."""
    db_path = get_db_path()
    conn = sqlite3.connect(db_path, timeout=20.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON;")
    # WAL mode improves concurrency for read and write operations
    if db_path != ":memory:":
        conn.execute("PRAGMA journal_mode = WAL;")
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def init_db():
    """Automatically initializes SQLite schema for users, tokens, and emergency incidents."""
    with get_connection() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                mobileNumber TEXT UNIQUE NOT NULL,
                passwordHash TEXT NOT NULL,
                salt TEXT NOT NULL,
                role TEXT NOT NULL,
                name TEXT NOT NULL,
                email TEXT,
                emergencyContactName TEXT,
                emergencyContactPhone TEXT,
                bloodGroup TEXT,
                allergies TEXT,
                medications TEXT
            );

            CREATE TABLE IF NOT EXISTS tokens (
                token TEXT PRIMARY KEY,
                mobileNumber TEXT NOT NULL,
                createdAt TEXT NOT NULL,
                FOREIGN KEY (mobileNumber) REFERENCES users(mobileNumber) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS incidents (
                id TEXT PRIMARY KEY,
                userId TEXT NOT NULL,
                category TEXT NOT NULL,
                intent TEXT NOT NULL,
                latitude REAL,
                longitude REAL,
                accuracy REAL,
                timestamp TEXT NOT NULL,
                priority TEXT NOT NULL,
                status TEXT NOT NULL,
                assignedResponderId TEXT,
                assignedResponderName TEXT,
                assignedResponderPhone TEXT,
                assignedResponderType TEXT,
                responderLatitude REAL,
                responderLongitude REAL,
                estimatedArrivalMinutes INTEGER,
                notes TEXT,
                aiIntelligence TEXT
            );

            CREATE INDEX IF NOT EXISTS idx_users_mobile ON users(mobileNumber);
            CREATE INDEX IF NOT EXISTS idx_tokens_token ON tokens(token);
            CREATE INDEX IF NOT EXISTS idx_incidents_status ON incidents(status);
            CREATE INDEX IF NOT EXISTS idx_incidents_userId ON incidents(userId);
            """
        )
