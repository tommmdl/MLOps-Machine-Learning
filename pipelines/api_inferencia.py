import joblib
import numpy as np
import pandas as pd
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List
from datetime import datetime
from prometheus_fastapi_instrumentator import Instrumentator
from prometheus_client import Counter
import os

app = FastAPI(
    title="MLOps Showcase — Anomaly Detection API",
    description="Detecção de anomalias em métricas AWS CloudWatch usando Isolation Forest",
    version="1.0.0"
)

Instrumentator().instrument(app).expose(app)

anomalias_detectadas = Counter(
    "anomalias_detectadas_total",
    "Total de anomalias detectadas pelo modelo",
    ["nome_metrica"]
)

BASE_DIR    = os.path.dirname(os.path.abspath(__file__))
MODELS_PATH = os.path.join(BASE_DIR, '..', 'models', 'training')

modelo   = joblib.load(os.path.join(MODELS_PATH, 'isolation_forest.joblib'))
scaler   = joblib.load(os.path.join(MODELS_PATH, 'scaler.joblib'))
FEATURES = joblib.load(os.path.join(MODELS_PATH, 'features.joblib'))

class MetricaInput(BaseModel):
    value: float
    rolling_mean_12: float
    rolling_std_12: float
    rolling_mean_24: float
    rolling_std_24: float
    diff_1: float
    diff_12: float
    hora: int
    dia_semana: int
    zscore: float

class MetricasBatch(BaseModel):
    metricas: List[MetricaInput]
    nome_metrica: str = "desconhecida"

class AnomaliaResponse(BaseModel):
    anomalia: bool
    score: float
    timestamp: str
    nome_metrica: str
    mensagem: str

@app.get("/health")
def health():
    return {
        "status": "ok",
        "modelo": "IsolationForest",
        "versao": "1.0.0",
        "timestamp": datetime.now().isoformat()
    }

@app.post("/predict", response_model=List[AnomaliaResponse])
def predict(batch: MetricasBatch):
    try:
        df = pd.DataFrame([m.dict() for m in batch.metricas])
        X  = df[FEATURES].fillna(0).values
        X_scaled   = scaler.transform(X)
        predicoes  = modelo.predict(X_scaled)
        scores     = modelo.score_samples(X_scaled)
        resultados = []
        for i, (pred, score) in enumerate(zip(predicoes, scores)):
            anomalia = pred == -1
            if anomalia:
                anomalias_detectadas.labels(nome_metrica=batch.nome_metrica).inc()
            resultados.append(AnomaliaResponse(
                anomalia=anomalia,
                score=round(float(score), 4),
                timestamp=datetime.now().isoformat(),
                nome_metrica=batch.nome_metrica,
                mensagem="ALERTA: anomalia detectada!" if anomalia else "Normal"
            ))
        return resultados
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/metricas-suportadas")
def metricas_suportadas():
    return {"features": FEATURES}
