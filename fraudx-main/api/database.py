from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = "postgresql://fraudx_user:qFWf4hEF83evmIV6HjtYPOklw2B2ExoP@dpg-d8tcangk1i2s738i3t50-a.oregon-postgres.render.com/fraudx"

engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

Base = declarative_base()