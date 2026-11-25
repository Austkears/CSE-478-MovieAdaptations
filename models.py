"""SQLAlchemy ORM models. The SQLite file (movies.db) is the archive for later queries."""
from datetime import datetime

from sqlalchemy import ForeignKey, Index, create_engine
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship

DB_URL = "sqlite:///movies.db"  # swap for a postgresql:// URL if ever needed


class Base(DeclarativeBase):
    pass


class Film(Base):
    __tablename__ = "films"

    qid: Mapped[str] = mapped_column(primary_key=True)
    label: Mapped[str | None]
    pub_year: Mapped[int | None] = mapped_column(index=True)
    is_based_on: Mapped[bool]
    is_sequel: Mapped[bool]
    imdb_id: Mapped[str | None]
    duration_min: Mapped[float | None]
    budget: Mapped[float | None]
    box_office: Mapped[float | None]
    sitelinks: Mapped[int | None]
    fetched_at: Mapped[datetime | None]  # NULL = not yet enriched from Wikidata

    attrs: Mapped[list["FilmAttr"]] = relationship(back_populates="film", cascade="all, delete-orphan")


class FilmAttr(Base):
    """Multi-valued attributes: kind in director/genre/country/language/based_on_work."""
    __tablename__ = "film_attr"

    qid: Mapped[str] = mapped_column(ForeignKey("films.qid"), primary_key=True)
    kind: Mapped[str] = mapped_column(primary_key=True)
    value: Mapped[str] = mapped_column(primary_key=True)

    film: Mapped[Film] = relationship(back_populates="attrs")

    __table_args__ = (Index("idx_attr_kind_value", "kind", "value"),)


def get_engine(url: str = DB_URL):
    return create_engine(url)
