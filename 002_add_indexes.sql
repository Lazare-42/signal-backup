-- Message Unifier Indexes
-- Version: 0.1.0
-- Description: Performance indexes for common queries

BEGIN;

-- Messages indexes
CREATE INDEX IF NOT EXISTS idx_messages_platform ON messages(platform);
CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_messages_received_at ON messages(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);

-- JSONB indexes for sender/recipient lookups
CREATE INDEX IF NOT EXISTS idx_messages_sender_contact_id ON messages((sender->>'contactId'));
CREATE INDEX IF NOT EXISTS idx_messages_recipients ON messages USING GIN (recipients);

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_messages_platform_timestamp ON messages(platform, timestamp DESC);

-- Contacts indexes
CREATE INDEX IF NOT EXISTS idx_contacts_phone_number ON contacts(phone_number) WHERE phone_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_email ON contacts(email) WHERE email IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_discord_id ON contacts(discord_id) WHERE discord_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_telegram_id ON contacts(telegram_id) WHERE telegram_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_signal_id ON contacts(signal_id) WHERE signal_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_whatsapp_id ON contacts(whatsapp_id) WHERE whatsapp_id IS NOT NULL;

-- Message tags indexes
CREATE INDEX IF NOT EXISTS idx_message_tags_tag ON message_tags(tag);
CREATE INDEX IF NOT EXISTS idx_message_tags_message_id ON message_tags(message_id);

-- Webhook deliveries indexes
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_message_id ON webhook_deliveries(message_id);
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_status ON webhook_deliveries(status);
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_platform ON webhook_deliveries(platform);

-- Composite index for webhook retry queries
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_retry ON webhook_deliveries(status, last_attempt_at)
    WHERE status = 'pending' OR status = 'failed';

COMMIT;
