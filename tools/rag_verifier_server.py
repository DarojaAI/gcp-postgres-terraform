"""
rag_verifier_server — FastAPI wrapper for the hallucination verifier
====================================================================

REST API for anti-hallucination verification of AI governance documents.

Endpoints:
  GET  /health                  — liveness probe
  GET  /ready                   — readiness probe (checks PostgreSQL)
  POST /verify/text             — verify a single claim
  POST /verify/file             — verify claims from a document
  GET  /verify/{claim_id}      — get a previous verification result
  GET  /taxonomy               — get full taxonomy tree
  GET  /taxonomy/framework/{f} — get taxonomy for a specific framework
  GET  /status                 — adapter status (chunk/entity counts)

Run locally:
  POSTGRES_HOST=... python -m tools.rag_verifier_server

Deploy (Cloud Run):
  gcloud run deploy rag-verifier --source . --region=us-central1
"""

from __future__ import annotations

import os
import uuid
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# The PostgreSQL-wired verifier (from rag_research_tool)
# This module must be on the Python path.
# In production Docker image, tools/ is copied alongside hallucination_verifier.py
import sys
sys.path.insert(0, str(Path(__file__).parent.parent))

try:
    from tools.hallucination_verifier import HallucinationVerifier
    from tools.postgres_adapter import PostgresVerifierAdapter
except ImportError as e:
    raise RuntimeError(
        "hallucination_verifier or postgres_adapter not found. "
        "Ensure rag_research_tool code is copied into the Docker image."
    ) from e

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

POSTGRES_CONFIG = {
    "host": os.environ.get("POSTGRES_HOST", "localhost"),
    "port": int(os.environ.get("POSTGRES_PORT", "5432")),
    "database": os.environ.get("POSTGRES_DB", "postgres"),
    "user": os.environ.get("POSTGRES_USER", "postgres"),
    "password": os.environ.get("POSTGRES_PASSWORD", ""),
}

# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

app = FastAPI(
    title="rag-verifier",
    description="Anti-hallucination verification for AI governance synthesis documents",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_verifier: Optional[HallucinationVerifier] = None

def get_verifier() -> HallucinationVerifier:
    global _verifier
    if _verifier is None:
        _verifier = HallucinationVerifier(postgres_config=POSTGRES_CONFIG)
    return _verifier

def get_adapter() -> PostgresVerifierAdapter:
    adapter = PostgresVerifierAdapter(POSTGRES_CONFIG)
    if not adapter.is_available():
        raise HTTPException(503, "PostgreSQL + pgvector not available")
    return adapter


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/ready")
def ready():
    """Readiness probe — checks PostgreSQL connectivity."""
    try:
        adapter = get_adapter()
        return {"status": "ready", **adapter.status()}
    except Exception as e:
        raise HTTPException(503, str(e))


# ---------------------------------------------------------------------------
# Status
# ---------------------------------------------------------------------------

class StatusResponse(BaseModel):
    postgres: str
    schema: str
    chunks: int
    entities: int
    relationships: int
    taxonomy_nodes: int
    source_documents: int

@app.get("/status", response_model=StatusResponse)
def status():
    try:
        s = get_adapter().status()
        return StatusResponse(**s)
    except Exception as e:
        raise HTTPException(503, str(e))


# ---------------------------------------------------------------------------
# Verify single claim
# ---------------------------------------------------------------------------

class VerifyClaimRequest(BaseModel):
    claim: str
    source_document: Optional[str] = None

class SourceRef(BaseModel):
    source_file: str
    page_ref: Optional[str] = None
    excerpt: str
    similarity: float

class VerifyClaimResponse(BaseModel):
    claim_id: str
    claim_text: str
    status: str
    confidence: str
    hallucination_flags: list[str]
    supporting_sources: list[SourceRef]
    contradicting_sources: list[SourceRef]
    recommendations: list[str]

@app.post("/verify/text", response_model=VerifyClaimResponse)
def verify_text(req: VerifyClaimRequest):
    verifier = get_verifier()
    try:
        result = verifier.verify_claim(req.claim)
        return VerifyClaimResponse(
            claim_id=result.claim_id,
            claim_text=result.original_claim,
            status=result.status.value,
            confidence=result.confidence.value,
            hallucination_flags=result.hallucination_flags,
            supporting_sources=[
                SourceRef(
                    source_file=s.source_name,
                    page_ref=s.page_ref,
                    excerpt=s.supporting_excerpt[:200],
                    similarity=getattr(s, "verbatim_match_score", 0.0),
                )
                for s in result.supporting_sources
            ],
            contradicting_sources=[
                SourceRef(
                    source_file=s.source_name,
                    page_ref=s.page_ref,
                    excerpt=s.supporting_excerpt[:200],
                    similarity=getattr(s, "verbatim_match_score", 0.0),
                )
                for s in result.contradicting_sources
            ],
            recommendations=result.recommendations,
        )
    except Exception as e:
        raise HTTPException(500, str(e))


# ---------------------------------------------------------------------------
# Verify file
# ---------------------------------------------------------------------------

@app.post("/verify/file")
async def verify_file(
    file: UploadFile = File(...),
    source_document: Optional[str] = Form(None),
):
    """Upload a .md or .txt file to verify all claims."""
    import tempfile

    verifier = get_verifier()
    suffix = Path(file.filename or "upload").suffix.lower()
    if suffix not in (".md", ".txt"):
        raise HTTPException(400, "Only .md and .txt files supported")

    try:
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
            content = await file.read()
            tmp.write(content)
            tmp_path = tmp.name

        result = verifier.verify_file(tmp_path)
        return {
            "report_id": result.report_id,
            "source_document": result.source_document,
            "total_claims": result.total_claims,
            "overall_confidence": result.overall_confidence.value,
            "breakdown": {
                "supported": result.supported,
                "largely_supported": result.largely_supported,
                "partial": result.partial,
                "unsupported": result.unsupported,
                "contradicted": result.contradicted,
            },
            "hallucination_flags_summary": result.hallucination_flags_summary,
            "cross_claim_contradictions": result.cross_claim.summary() if result.cross_claim else None,
            "verifications": [
                {
                    "claim_id": v.claim_id,
                    "claim_text": v.original_claim[:120],
                    "status": v.status.value,
                    "confidence": v.confidence.value,
                    "hallucination_flags": v.hallucination_flags,
                }
                for v in result.verifications
            ],
        }
    except Exception as e:
        raise HTTPException(500, str(e))
    finally:
        Path(tmp_path).unlink(missing_ok=True)


# ---------------------------------------------------------------------------
# Taxonomy
# ---------------------------------------------------------------------------

@app.get("/taxonomy")
def taxonomy():
    """Get full taxonomy tree across all frameworks."""
    try:
        adapter = get_adapter()
        nodes = adapter.get_taxonomy_tree()
        return {"total": len(nodes), "nodes": nodes}
    except Exception as e:
        raise HTTPException(500, str(e))


@app.get("/taxonomy/framework/{framework}")
def taxonomy_framework(framework: str):
    """Get taxonomy for a specific framework."""
    try:
        adapter = get_adapter()
        nodes = adapter.get_taxonomy_tree(framework=framework)
        return {"framework": framework, "total": len(nodes), "nodes": nodes}
    except Exception as e:
        raise HTTPException(500, str(e))


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", "8080"))
    uvicorn.run(app, host="0.0.0.0", port=port)
