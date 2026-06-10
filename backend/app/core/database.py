from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.core.config import settings


engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def ensure_order_columns() -> None:
    inspector = inspect(engine)
    if "orders" not in inspector.get_table_names():
        return

    existing_columns = {
        column["name"] for column in inspector.get_columns("orders")
    }
    required_columns = {
        "customer_id": "VARCHAR(36)",
        "farmer_id": "VARCHAR(36)",
        "source_request_id": "VARCHAR(36)",
        "product_id": "VARCHAR(36)",
        "batch_id": "VARCHAR(36)",
        "product_type": "VARCHAR(80)",
        "order_type": "VARCHAR(80)",
        "quantity": "INTEGER",
        "quantity_unit": "VARCHAR(40)",
        "fulfillment_type": "VARCHAR(80)",
        "fulfillment_status": "VARCHAR(80)",
        "handover_otp_hash": "VARCHAR(128)",
        "handover_otp_expires_at": "TIMESTAMP",
        "handover_verified_at": "TIMESTAMP",
        "receiver_confirmed_at": "TIMESTAMP",
        "notes": "VARCHAR(1000)",
        "accepted_at": "TIMESTAMP",
        "rejected_at": "TIMESTAMP",
        "completed_at": "TIMESTAMP",
    }

    with engine.begin() as connection:
        for column_name, column_type in required_columns.items():
            if column_name not in existing_columns:
                connection.execute(
                    text(f"ALTER TABLE orders ADD COLUMN {column_name} {column_type}")
                )

        connection.execute(
            text("UPDATE orders SET customer_id = owner_id WHERE customer_id IS NULL")
        )
        connection.execute(
            text("UPDATE orders SET quantity = 1 WHERE quantity IS NULL")
        )
        connection.execute(
            text(
                "UPDATE orders SET order_type = 'product_order' "
                "WHERE order_type IS NULL OR order_type = ''"
            )
        )
        connection.execute(
            text(
                "UPDATE orders SET quantity_unit = 'item' "
                "WHERE quantity_unit IS NULL OR quantity_unit = ''"
            )
        )
        connection.execute(
            text(
                "UPDATE orders SET fulfillment_status = 'pending_handover' "
                "WHERE fulfillment_status IS NULL OR fulfillment_status = ''"
            )
        )
        connection.execute(
            text(
                "UPDATE orders SET status = 'pending' "
                "WHERE status IS NULL OR status = ''"
            )
        )
        connection.execute(
            text("UPDATE orders SET status = 'pending' WHERE lower(status) = 'pending'")
        )
        connection.execute(
            text(
                "UPDATE orders SET status = 'in_progress' "
                "WHERE lower(status) IN ('in progress', 'in_progress')"
            )
        )
        connection.execute(
            text(
                "UPDATE orders SET status = 'completed' "
                "WHERE lower(status) IN ('delivered', 'completed')"
            )
        )


def ensure_project_columns() -> None:
    inspector = inspect(engine)
    if "projects" not in inspector.get_table_names():
        return

    existing_columns = {
        column["name"] for column in inspector.get_columns("projects")
    }
    with engine.begin() as connection:
        if "is_hidden" not in existing_columns:
            connection.execute(
                text("ALTER TABLE projects ADD COLUMN is_hidden BOOLEAN")
            )
        connection.execute(
            text("UPDATE projects SET is_hidden = :is_hidden WHERE is_hidden IS NULL"),
            {"is_hidden": False},
        )


def ensure_batch_columns() -> None:
    inspector = inspect(engine)
    if "batches" not in inspector.get_table_names():
        return

    existing_columns = {
        column["name"] for column in inspector.get_columns("batches")
    }
    required_columns = {
        "quantity_available": "INTEGER",
        "quantity_unit": "VARCHAR(40)",
        "price": "FLOAT",
        "available_now": "BOOLEAN",
        "status": "VARCHAR(80)",
        "available_from_date": "TIMESTAMP",
        "expected_harvest_date": "TIMESTAMP",
    }
    with engine.begin() as connection:
        for column_name, column_type in required_columns.items():
            if column_name not in existing_columns:
                connection.execute(
                    text(f"ALTER TABLE batches ADD COLUMN {column_name} {column_type}")
                )
        connection.execute(
            text(
                "UPDATE batches SET quantity_available = quantity "
                "WHERE quantity_available IS NULL"
            )
        )
        connection.execute(
            text(
                "UPDATE batches SET quantity_unit = 'kg' "
                "WHERE quantity_unit IS NULL OR quantity_unit = ''"
            )
        )
        connection.execute(
            text(
                "UPDATE batches SET available_now = :available_now "
                "WHERE available_now IS NULL"
            ),
            {"available_now": True},
        )
        connection.execute(
            text(
                "UPDATE batches SET status = 'sold_out' "
                "WHERE (quantity_available IS NULL OR quantity_available <= 0) "
                "AND expected_harvest_date IS NULL "
                "AND (status IS NULL OR status = '')"
            )
        )
        connection.execute(
            text(
                "UPDATE batches SET status = 'upcoming' "
                "WHERE (available_now = :available_now OR quantity_available <= 0) "
                "AND expected_harvest_date IS NOT NULL "
                "AND (status IS NULL OR status = '')"
            ),
            {"available_now": False},
        )
        connection.execute(
            text(
                "UPDATE batches SET status = 'available' "
                "WHERE status IS NULL OR status = ''"
            )
        )


def ensure_custom_order_request_columns() -> None:
    inspector = inspect(engine)
    if "custom_order_requests" not in inspector.get_table_names():
        return

    existing_columns = {
        column["name"] for column in inspector.get_columns("custom_order_requests")
    }
    required_columns = {
        "accepted_by_artisan_id": "VARCHAR(36)",
        "rejected_artisan_ids": "VARCHAR(2000)",
    }

    with engine.begin() as connection:
        if engine.dialect.name == "postgresql":
            connection.execute(
                text("ALTER TYPE customrequesttargettype ADD VALUE IF NOT EXISTS 'broadcast'")
            )
            connection.execute(
                text(
                    "ALTER TABLE custom_order_requests "
                    "ALTER COLUMN target_artisan_id DROP NOT NULL"
                )
            )

        for column_name, column_type in required_columns.items():
            if column_name not in existing_columns:
                connection.execute(
                    text(
                        f"ALTER TABLE custom_order_requests "
                        f"ADD COLUMN {column_name} {column_type}"
                    )
                )
        connection.execute(
            text(
                "UPDATE custom_order_requests SET rejected_artisan_ids = '' "
                "WHERE rejected_artisan_ids IS NULL"
            )
        )
