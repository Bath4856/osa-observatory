# =============================================================================
# OSA Observatory -- Dockerfile production
# Sprint 18 -- 29 mai 2026
#
# Corrections vs version Sprint 14 :
#   - python:3.11-slim → python:3.12-slim (alignement avec environnement local)
#   - Ajout ENV PYTHONPATH=/app (module api trouvable par uvicorn)
#   - Utilisateur non-root osauser (sécurité production)
#   - Ajout curl pour healthcheck
#   - Contexte de build : racine du repo (pas api/)
# =============================================================================

FROM python:3.12-slim

# Métadonnées
LABEL maintainer="OSA Observatory <noreply@osa-observatory.africa>"
LABEL version="2.0.0"
LABEL description="OSA ISA Public API - Observatoire de la Souverainete Africaine"

# Variables d'environnement
ENV PYTHONPATH=/app
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Dépendances système minimales (curl pour healthcheck)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Dépendances Python
COPY api/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Code source
COPY api/ ./api/

# Utilisateur non-root pour la sécurité de production
RUN adduser --disabled-password --gecos "" osauser \
    && chown -R osauser:osauser /app
USER osauser

# Port exposé
EXPOSE 8000

# Healthcheck intégré
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Démarrage
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
