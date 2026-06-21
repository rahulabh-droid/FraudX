import sys
import os

sys.path.append(
    os.path.dirname(
        os.path.dirname(os.path.abspath(__file__))
    )
)

from suspicious_by_model import detect_suspicious_transactions
from fastapi import FastAPI, HTTPException, Depends, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
import joblib
import pandas as pd
import numpy as np
from typing import List, Optional
import time
from datetime import datetime

app = FastAPI(title="FraudX API", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load models
# Load models
BASE_DIR = os.path.dirname(
    os.path.dirname(
        os.path.abspath(__file__)
    )
)

try:
    model = joblib.load(
        os.path.join(
            BASE_DIR,
            "fraud_detection_model.joblib"
        )
    )

    scaler = joblib.load(
        os.path.join(
            BASE_DIR,
            "fraud_detection_scaler.joblib"
        )
    )

    feature_columns = joblib.load(
        os.path.join(
            BASE_DIR,
            "feature_columns.joblib"
        )
    )
    print("MODEL TYPE:", type(model))
    print("SCALER TYPE:", type(scaler))
    print("FEATURE COUNT:", len(scaler.feature_names_in_))

    print("Models loaded successfully")

except Exception as e:
    print(f"Error loading models: {e}")
    model = None
    scaler = None

class TransactionRequest(BaseModel):
    transaction_id: str
    amount: float
    sender_id: str
    receiver_id: str
    sender_country: str
    receiver_country: str
    payment_method: str

    vpn_usage: bool = False
    ip_address_change: bool = False
    is_new_device: bool = False
    is_new_location: bool = False

    timestamp: Optional[str] = None

class FraudResponse(BaseModel):
    transaction_id: str
    fraud_score: float
    is_suspicious: bool
    confidence: float
    risk_factors: List[str]
    processing_time: float

def identify_risk_factors(transaction: TransactionRequest, fraud_score: float) -> List[str]:
    """Identify risk factors for the transaction"""
    risk_factors = []
    
    if fraud_score > 0.7:
        risk_factors.append("High fraud probability")
    
    if transaction.amount > 10000:
        risk_factors.append("High transaction amount")
    
    if transaction.amount < 10:
        risk_factors.append("Suspiciously low amount")
    
    if transaction.sender_country != transaction.receiver_country:
        risk_factors.append("Cross-border transaction")
    
    if transaction.payment_method in ['crypto', 'bank_transfer']:
        risk_factors.append("High-risk payment method")

    if transaction.vpn_usage:
        risk_factors.append("VPN usage detected")

    if transaction.ip_address_change:
        risk_factors.append("IP address changed")

    if transaction.is_new_device:
        risk_factors.append("New device detected")

    if transaction.is_new_location:
        risk_factors.append("New location detected")
    
    return risk_factors

def calculate_confidence(fraud_score: float) -> float:
    """Calculate confidence based on fraud score"""
    # Higher confidence for extreme scores
    if fraud_score > 0.8 or fraud_score < 0.2:
        return 0.95
    elif fraud_score > 0.6 or fraud_score < 0.4:
        return 0.85
    else:
        return 0.75

@app.get("/")
async def root():
  return {
"message": "FraudX API Running"
}

@app.get("/api/v1/health")
async def health_check():
 return {
"status": "healthy",
"timestamp": datetime.now().isoformat(),
"models_loaded": model is not None and scaler is not None
}

@app.post("/api/v1/detect-fraud", response_model=FraudResponse)
async def detect_fraud(transaction: TransactionRequest):
    start_time = time.time()

    try:
        if model is None or scaler is None:
            raise HTTPException(
                status_code=500,
                detail="Models not loaded"
            )

        input_df = pd.DataFrame([{
            "Transaction_ID": transaction.transaction_id,
            "Sender_ID": transaction.sender_id,
            "Receiver_ID": transaction.receiver_id,
            "Sender_Country": transaction.sender_country,
            "Receiver_Country": transaction.receiver_country,
            "Payment_Method": transaction.payment_method,
            "Transaction_Amount": transaction.amount,
            "Transaction_Currency": "INR",
            "Transaction_Velocity": 1,
            "Unusual_Time": False,
            "Multiple_Currency_Conversions": False,
            "Repeated_Failed_Attempts": 0,
            "Is_Known_Fraudster": False,
            "Is_Sanctioned_Entity": False,
            "VPN_Usage": transaction.vpn_usage,
"           IP_Address_Change": transaction.ip_address_change,
            "Is_New_Device": transaction.is_new_device,
            "Is_New_Location": transaction.is_new_location
        }])

        result_df = detect_suspicious_transactions(
            input_df,
            model,
            scaler,
            threshold=0.5
        )

        fraud_score = float(
            result_df["Suspicion_Score"].iloc[0]
        )

        risk_factors = identify_risk_factors(
            transaction,
            fraud_score
        )

        processing_time = time.time() - start_time

        return FraudResponse(
            transaction_id=transaction.transaction_id,
            fraud_score=fraud_score,
            is_suspicious=bool(
                result_df["Is_Suspicious"].iloc[0]
            ),
            confidence=calculate_confidence(fraud_score),
            risk_factors=risk_factors,
            processing_time=processing_time
        )

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Prediction error: {str(e)}"
        )

@app.post("/api/v1/upload-csv")
async def upload_csv(
    file: UploadFile = File(...)
):
    df = pd.read_csv(file.file)

    result_df = detect_suspicious_transactions( 
        df,
        model,
        scaler,
        threshold=0.5
    )

    total_transactions = len(result_df)

    suspicious_transactions = int(
        result_df["Is_Suspicious"].sum()
    )

    safe_transactions = (
        total_transactions -
        suspicious_transactions
    )

    fraud_rate = round(
        (suspicious_transactions / total_transactions) * 100,
        2
    ) if total_transactions > 0 else 0

    result_df.to_csv(
        "fraud_report.csv",
        index=False
    )

    return {
        "total_transactions":
            total_transactions,

        "suspicious_transactions":
            suspicious_transactions,

        "safe_transactions":
            safe_transactions,

        "fraud_rate":
            fraud_rate
}