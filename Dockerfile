FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY pipelines/ ./pipelines/
COPY models/training/ ./models/training/

EXPOSE 8000

CMD ["uvicorn", "pipelines.api_inferencia:app", "--host", "0.0.0.0", "--port", "8000"]
