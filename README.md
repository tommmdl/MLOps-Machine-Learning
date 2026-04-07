# MLOps Showcase — Anomaly Detection Pipeline

Pipeline MLOps completo para **detecção de anomalias em métricas AWS CloudWatch**, com treinamento de modelo, API de inferência, monitoramento com Prometheus e infraestrutura provisionada via Terraform.

---

## Arquitetura

```
Notebooks (treino)
      │
      ▼
Isolation Forest ──► FastAPI /predict ──► Prometheus metrics
      │                                        │
      ▼                                        ▼
  AWS S3 (modelo)                       Grafana / Alerting
      │
AWS ECR (imagem)
      │
GitHub Actions CI/CD (OIDC keyless auth)
```

---

## Stack de tecnologias

| Camada | Tecnologia |
|--------|------------|
| ML Model | Scikit-learn · Isolation Forest |
| Feature Engineering | Pandas · NumPy · rolling stats · z-score |
| API | FastAPI · Uvicorn · Pydantic |
| Monitoramento | Prometheus · prometheus-fastapi-instrumentator |
| Containerização | Docker · Docker Compose |
| Infraestrutura | Terraform · AWS S3 · AWS ECR |
| CI/CD | GitHub Actions · OIDC (keyless AWS auth) |
| Notebooks | Jupyter · 3 notebooks (exploração → preprocessamento → treino) |

---

## Pipeline MLOps

```
01_exploracao_dados.ipynb
        │  Análise estatística das métricas CloudWatch
        ▼
02_preprocessamento.ipynb
        │  Rolling mean/std (12h, 24h), diff, z-score, hora, dia_semana
        ▼
03_modelo_anomalia.ipynb
        │  Treino do Isolation Forest + StandardScaler
        ▼
models/training/
        ├── isolation_forest.joblib
        ├── scaler.joblib
        └── features.joblib
        ▼
pipelines/api_inferencia.py  (FastAPI)
```

---

## Como executar localmente

### Pré-requisitos
- Docker e Docker Compose
- AWS credentials (para métricas CloudWatch reais)

### Subir a API + Prometheus

```bash
git clone https://github.com/tommmdl/MLOps-Machine-Learning.git
cd MLOps-Machine-Learning

# Configure as variáveis de ambiente
cp .env.example .env  # edite com suas credenciais AWS

docker-compose up -d
```

| Serviço | URL |
|---------|-----|
| API (Swagger) | http://localhost:8000/docs |
| Health check | http://localhost:8000/health |
| Prometheus metrics | http://localhost:8000/metrics |
| Prometheus UI | http://localhost:9090 |

---

## API de Inferência

### `POST /predict`

Recebe um batch de métricas e retorna se cada ponto é anomalia ou não.

```bash
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "nome_metrica": "CPUUtilization",
    "metricas": [{
      "value": 98.5,
      "rolling_mean_12": 45.2,
      "rolling_std_12": 5.1,
      "rolling_mean_24": 44.8,
      "rolling_std_24": 5.3,
      "diff_1": 53.3,
      "diff_12": 12.1,
      "hora": 14,
      "dia_semana": 1,
      "zscore": 3.8
    }]
  }'
```

**Resposta:**
```json
[{
  "anomalia": true,
  "score": -0.1423,
  "timestamp": "2026-04-07T10:00:00",
  "nome_metrica": "CPUUtilization",
  "mensagem": "ALERTA: anomalia detectada!"
}]
```

---

## Monitoramento

O Prometheus coleta automaticamente métricas da API via `/metrics`, incluindo:

- `anomalias_detectadas_total` — contador de anomalias por métrica
- Latência e throughput das requisições (via `prometheus-fastapi-instrumentator`)

---

## Infraestrutura (Terraform)

```bash
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```

Recursos criados na AWS:
- **S3 Bucket** — armazenamento de modelos e logs (lifecycle: 30 dias)
- **ECR Repository** — registro de imagens Docker
- **OIDC Provider** — autenticação keyless do GitHub Actions na AWS
- **IAM Role** — permissões mínimas para o CI/CD fazer push no ECR
- **Budget alerts** — controle de custos

---

## CI/CD

O pipeline no GitHub Actions realiza:

1. Build da imagem Docker
2. Autenticação na AWS via **OIDC (sem chaves estáticas)**
3. Push da imagem para o **ECR**

---

## Estrutura do repositório

```
.
├── notebooks/
│   ├── 01_exploracao_dados.ipynb
│   ├── 02_preprocessamento.ipynb
│   └── 03_modelo_anomalia.ipynb
├── pipelines/
│   └── api_inferencia.py       # FastAPI + Prometheus
├── models/
│   ├── training/               # Modelos treinados (.joblib)
│   └── registry/               # Versionamento de modelos
├── monitoring/
│   └── prometheus.yml
├── infrastructure/
│   └── terraform/              # S3, ECR, OIDC, IAM
├── Dockerfile
├── docker-compose.yml
└── requirements.txt
```

---

## Autor

**Rafael Santiago**
[github.com/tommmdl](https://github.com/tommmdl)
