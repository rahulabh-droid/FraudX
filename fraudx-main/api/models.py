from sqlalchemy import Column, Integer, String, Float, Boolean
from api.database import Base

class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True)

    transaction_id = Column(String)
    amount = Column(Float)

    sender_id = Column(String)
    receiver_id = Column(String)

    fraud_score = Column(Float)
    is_suspicious = Column(Boolean)