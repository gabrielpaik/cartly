from .base import Base
from .models import (  # noqa: F401
    AdClick,
    AdImpression,
    AdSlot,
    AppEvent,
    AppSetting,
    Cart,
    CartItem,
    ScanFailureLog,
    ScanFeedback,
    ScanJob,
    Session,
    User,
)
from .session import engine


def init_db() -> None:
    Base.metadata.create_all(bind=engine)
