from contextlib import contextmanager
from types import SimpleNamespace

from app.core import database


class FakeInspector:
    def get_table_names(self) -> list[str]:
        return ["projects"]

    def get_columns(self, table_name: str) -> list[dict[str, object]]:
        assert table_name == "projects"
        return [
            {"name": "source_batch_id", "nullable": False},
            {"name": "description", "nullable": True},
            {"name": "price", "nullable": True},
            {"name": "bamboo_type", "nullable": True},
            {"name": "material_source", "nullable": True},
            {"name": "source_details", "nullable": True},
            {"name": "is_hidden", "nullable": False},
            {"name": "image_url", "nullable": True},
            {"name": "status", "nullable": False},
        ]


class FakeConnection:
    def __init__(self) -> None:
        self.statements: list[str] = []

    def execute(self, statement, parameters=None) -> None:
        self.statements.append(str(statement))


class FakeEngine:
    dialect = SimpleNamespace(name="postgresql")

    def __init__(self) -> None:
        self.connection = FakeConnection()

    @contextmanager
    def begin(self):
        yield self.connection


def test_legacy_project_batch_column_becomes_nullable(monkeypatch) -> None:
    fake_engine = FakeEngine()
    monkeypatch.setattr(database, "engine", fake_engine)
    monkeypatch.setattr(database, "inspect", lambda _engine: FakeInspector())

    database.ensure_project_columns()

    assert any(
        "ALTER TABLE projects ALTER COLUMN source_batch_id DROP NOT NULL"
        in statement
        for statement in fake_engine.connection.statements
    )
