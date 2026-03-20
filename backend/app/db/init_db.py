from .base import Base
from .models import Cart, CartItem, ScanJob, Session, User  # noqa: F401
from .session import engine


def init_db() -> None:
    Base.metadata.create_all(bind=engine)
