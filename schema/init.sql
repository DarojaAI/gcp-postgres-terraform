-- =============================================================================
-- Base PostgreSQL Schema for gcp-postgres-terraform
-- =============================================================================
-- This is the default schema created when provisioning a new PostgreSQL instance.
-- Use --init-sql flag to override with custom schema.
--
-- pgvector extension is enabled by default (if pgvector_enabled=true).
-- =============================================================================

-- Enable pgvector for vector similarity search
CREATE EXTENSION IF NOT EXISTS vector;

-- Example: Create a table with vector column
-- CREATE TABLE embeddings (
--     id SERIAL PRIMARY KEY,
--     document_id TEXT,
--     content TEXT,
--     embedding vector(1536),
--     created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
-- );

-- Example: Create index for vector similarity search
-- CREATE INDEX ON embeddings USING ivfflat (embedding vector_cosine_ops);

-- =============================================================================
-- Default Schema Structure (Empty - extend via --init-sql)
-- =============================================================================
-- The base installation creates:
--   - pgvector extension (if enabled)
--   - Default 'postgres' database with 'postgres' user
--
-- Override this by passing custom SQL via --init-sql when creating instance:
--   gcp-postgres create --name mydb --init-sql "$(cat my_schema.sql)"
--
-- Or reference a SQL file:
--   gcp-postgres create --name mydb --schema ./my_schema.sql
-- =============================================================================

-- Grant usage on public schema
GRANT USAGE ON SCHEMA public TO PUBLIC;

-- Grant all privileges on public schema to postgres user
GRANT ALL PRIVILEGES ON SCHEMA public TO postgres;
