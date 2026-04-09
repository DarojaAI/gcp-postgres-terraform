-- =============================================================================
-- RAG Research Tool — AI Governance Taxonomy Schema
-- =============================================================================
-- PostgreSQL + pgvector for document ingestion, taxonomy, and verification.
-- Run after PostgreSQL boot via init_sql variable or manually:
--   psql -d $DB_NAME -f schema/extensions/rag_taxonomy.sql
-- =============================================================================

-- Enable pgvector (installed separately via postgres_init.sh)
CREATE EXTENSION IF NOT EXISTS vector;

-- ---------------------------------------------------------------------------
-- Source Documents Registry
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS source_documents (
    id          TEXT PRIMARY KEY,         -- slug, e.g. "eu_ai_act"
    title       TEXT NOT NULL,
    source_type TEXT NOT NULL,            -- 'regulation' | 'convention' | 'principles' | 'framework' | 'guide' | 'report'
    jurisdiction TEXT,                    -- 'EU' | 'international' | 'US' | 'global'
    url         TEXT,
    file_path   TEXT,                   -- local path if available
    doc_length  INT,                    -- character count
    ingested_at TIMESTAMPTZ DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- Document Chunks (pgvector — replaces Weaviate)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS document_chunks (
    id              SERIAL PRIMARY KEY,
    doc_id          TEXT NOT NULL REFERENCES source_documents(id) ON DELETE CASCADE,
    chunk_index     INT NOT NULL,
    content         TEXT NOT NULL,
    embedding       vector(1536),        -- ada-002 dimension; truncate or pad for other models
    page_hint       INT,                -- page number if available
    char_start      INT,                -- offset in source doc
    char_end        INT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(doc_id, chunk_index)
);

-- IVFFlat index for approximate nearest-neighbor search
-- Build after table is populated: CREATE INDEX ON document_chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX IF NOT EXISTS idx_chunks_embedding ON document_chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX IF NOT EXISTS idx_chunks_doc_id ON document_chunks(doc_id);

-- ---------------------------------------------------------------------------
-- Entities (replaces Neo4j nodes)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entities (
    id              SERIAL PRIMARY KEY,
    doc_id          TEXT REFERENCES source_documents(id) ON DELETE SET NULL,
    name            TEXT NOT NULL,
    normalized_name TEXT,                -- lowercased, stripped for matching
    entity_type     TEXT NOT NULL,       -- 'framework' | 'obligation' | 'actor' | 'risk_category'
                                          --   'instrument' | 'condition' | 'definition' | 'principle'
    raw_text        TEXT,                -- original excerpt containing entity
    page_hint       INT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_entities_name ON entities(normalized_name);
CREATE INDEX IF NOT EXISTS idx_entities_type ON entities(entity_type);
CREATE INDEX IF NOT EXISTS idx_entities_doc_id ON entities(doc_id);

-- ---------------------------------------------------------------------------
-- Relationships (replaces Neo4j edges)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS relationships (
    id              SERIAL PRIMARY KEY,
    doc_id          TEXT REFERENCES source_documents(id) ON DELETE SET NULL,
    source_entity_id INT REFERENCES entities(id) ON DELETE SET NULL,
    target_entity_id INT REFERENCES entities(id) ON DELETE SET NULL,
    rel_type         TEXT NOT NULL,     -- 'governs' | 'requires' | 'exempts' | 'penalizes'
                                          --   'applies_to' | 'references' | 'supersedes' | 'complies_with'
    conditions       JSONB,              -- conditional modifiers, e.g. {"risk_level": "high-risk"}
    raw_text         TEXT,              -- original excerpt
    page_hint        INT,
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rel_source ON relationships(source_entity_id);
CREATE INDEX IF NOT EXISTS idx_rel_target ON relationships(target_entity_id);
CREATE INDEX IF NOT EXISTS idx_rel_type   ON relationships(rel_type);

-- ---------------------------------------------------------------------------
-- Taxonomy Nodes (hierarchical — framework → domain → obligation → entity)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS taxonomy_nodes (
    id              SERIAL PRIMARY KEY,
    doc_id          TEXT REFERENCES source_documents(id) ON DELETE SET NULL,

    -- Hierarchy levels (flexible; not all levels used by every framework)
    level_1         TEXT NOT NULL,      -- e.g. "EU AI Act"
    level_2         TEXT,              -- e.g. "Risk Classification"
    level_3         TEXT,              -- e.g. "High-Risk Systems"
    level_4         TEXT,              -- e.g. "Credit Scoring"

    -- Taxonomy metadata
    node_type       TEXT NOT NULL,      -- 'framework' | 'domain' | 'obligation' | 'entity' | 'condition'
    definition      TEXT,
    source_excerpt  TEXT,              -- verbatim text defining this node
    page_hint       INT,

    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_taxonomy_l1 ON taxonomy_nodes(level_1);
CREATE INDEX IF NOT EXISTS idx_taxonomy_l2 ON taxonomy_nodes(level_2);
CREATE INDEX IF NOT EXISTS idx_taxonomy_doc_id ON taxonomy_nodes(doc_id);
CREATE INDEX IF NOT EXISTS idx_taxonomy_type ON taxonomy_nodes(node_type);

-- ---------------------------------------------------------------------------
-- Verification Results (claim verdicts)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS verification_results (
    id                  SERIAL PRIMARY KEY,
    claim_id           TEXT NOT NULL,
    claim_text         TEXT NOT NULL,
    doc_id             TEXT REFERENCES source_documents(id) ON DELETE SET NULL,

    -- Verdict
    verdict            TEXT NOT NULL,   -- 'SUPPORTED' | 'CONTRADICTED' | 'PARTIAL'
                                          --   'UNSUPPORTED' | 'NOT_VERIFIABLE'
    confidence         REAL,            -- 0.0–1.0

    -- Evidence
    supporting_chunks  JSONB,           -- [{chunk_id, content, similarity}]
    contradicting_chunks JSONB,        -- [{chunk_id, content, similarity}]

    -- Hallucination flags
    hallucination_flags JSONB,         -- ['absolute_universal_all', ...]

    -- Taxonomy context (if resolved)
    resolved_framework TEXT,
    resolved_entities  JSONB,

    executed_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_verdict_claim ON verification_results(claim_id);
CREATE INDEX IF NOT EXISTS idx_verdict_doc   ON verification_results(doc_id);
CREATE INDEX IF NOT EXISTS idx_verdict_verdict ON verification_results(verdict);

-- ---------------------------------------------------------------------------
-- Ingestion Log
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ingestion_log (
    id              SERIAL PRIMARY KEY,
    doc_id          TEXT REFERENCES source_documents(id) ON DELETE CASCADE,
    status          TEXT NOT NULL,      -- 'started' | 'chunked' | 'embedded' | 'entities_extracted' | 'done' | 'failed'
    error_message   TEXT,
    chunks_created  INT,
    entities_created INT,
    started_at      TIMESTAMPTZ DEFAULT NOW(),
    completed_at    TIMESTAMPTZ
);

-- ---------------------------------------------------------------------------
-- Grant permissions
-- ---------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO PUBLIC;
