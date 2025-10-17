-- Message Unifier Full-Text Search
-- Version: 0.1.0
-- Description: Full-text search capabilities for message content

BEGIN;

-- Add tsvector column for full-text search
ALTER TABLE messages ADD COLUMN IF NOT EXISTS search_vector tsvector;

-- Create function to update search vector
CREATE OR REPLACE FUNCTION messages_search_vector_update() RETURNS trigger AS $$
BEGIN
    NEW.search_vector :=
        setweight(to_tsvector('english', coalesce(NEW.content::text, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(NEW.sender::text, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(NEW.recipients::text, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(NEW.metadata::text, '')), 'D');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update search vector
CREATE TRIGGER messages_search_vector_trigger
    BEFORE INSERT OR UPDATE OF content, sender, recipients, metadata
    ON messages
    FOR EACH ROW
    EXECUTE FUNCTION messages_search_vector_update();

-- Create GIN index on search vector for fast full-text search
CREATE INDEX IF NOT EXISTS idx_messages_search_vector ON messages USING GIN(search_vector);

-- Update existing rows
UPDATE messages SET search_vector =
    setweight(to_tsvector('english', coalesce(content::text, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(sender::text, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(recipients::text, '')), 'C') ||
    setweight(to_tsvector('english', coalesce(metadata::text, '')), 'D');

COMMIT;
