# =============================================================================
# rag-verifier — Anti-Hallucination Verification Service
# =============================================================================
# Serves the hallucination verifier as a REST API on Cloud Run.
# Connects to PostgreSQL + pgvector for evidence retrieval.
#
# Environment variables (required):
#   POSTGRES_HOST     PostgreSQL internal IP
#   POSTGRES_PORT     PostgreSQL port (default: 5432)
#   POSTGRES_DB       Database name
#   POSTGRES_USER     Database user
#   POSTGRES_PASSWORD  Database password (via Secret Manager)
#
# Optional:
#   OPENAI_API_KEY    OpenRouter API key for embeddings
# =============================================================================

FROM python:3.12-slim

WORKDIR /app

# Install system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy app source
COPY tools/ ./tools/
COPY docs/ ./docs/

# Note: The hallucination_verifier.py at tools/hallucination_verifier.py
# should be the one wired for PostgreSQL (pgvector) adapter.
# See: https://github.com/patelmm79/rag_research_tool

EXPOSE 8080

ENV PORT=8080
ENV AUTH_TERMINATION=false

CMD ["python", "-m", "tools.rag_verifier_server"]
