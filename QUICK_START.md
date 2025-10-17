# Signal Importer Quick Start

A Haskell program to import Signal Desktop messages into a unified PostgreSQL database.

## Prerequisites

1. **Haskell toolchain**: Install GHC and Cabal
   ```bash
   # On macOS
   brew install ghc cabal-install

   # On Linux
   apt-get install ghc cabal-install
   ```

2. **Signal Desktop database**: Extract using signalbackup-tools
   ```bash
   signalbackup-tools --desktopdir /path/to/Signal --dumpdesktopdb desktop_messages.db
   ```

3. **PostgreSQL**: Running instance with database created
   ```bash
   createdb message_unifier
   psql message_unifier -f 001_initial_schema.sql
   psql message_unifier -f 002_add_indexes.sql
   psql message_unifier -f 003_add_full_text_search.sql
   ```

## Building

```bash
# Update package index
cabal update

# Build the project
cabal build

# Install executable
cabal install
```

## Usage

### Basic Import

Import Signal messages from `desktop_messages.db` to local PostgreSQL:

```bash
signal-importer \
  --signal-db desktop_messages.db \
  --pg-database message_unifier \
  --pg-user postgres \
  --pg-password yourpassword
```

### Options

- `--signal-db PATH` - Path to Signal Desktop SQLite database (default: `desktop_messages.db`)
- `--pg-host HOST` - PostgreSQL host (default: `localhost`)
- `--pg-port PORT` - PostgreSQL port (default: `5432`)
- `--pg-database DB` - PostgreSQL database name (default: `message_unifier`)
- `--pg-user USER` - PostgreSQL username (default: `postgres`)
- `--pg-password PASS` - PostgreSQL password (default: empty)
- `--verbose` - Enable verbose output
- `--dry-run` - Read database but don't write to PostgreSQL

### Dry Run

Test reading the Signal database without writing:

```bash
signal-importer --signal-db desktop_messages.db --dry-run --verbose
```

## Database Schema

The importer writes to these tables:

### `messages` Table
- `message_id` - Unique message identifier
- `platform` - Always "Signal" for this importer
- `sender` - JSONB with sender contact info
- `recipients` - JSONB array with recipient contact info
- `content` - JSONB with message text, attachments, and metadata
- `metadata` - JSONB with conversation info
- `timestamp` - When message was sent
- `received_at` - When message was received

### `contacts` Table
- `contact_id` - Unique contact identifier
- `display_name` - Contact's display name
- `signal_id` - Signal-specific ID
- Other platform IDs (discord_id, telegram_id, etc.)

## Example Workflow

1. **Extract Signal database**:
   ```bash
   signalbackup-tools --desktopdir ~/Library/Application\ Support/Signal \
     --dumpdesktopdb desktop_messages.db
   ```

2. **Set up PostgreSQL**:
   ```bash
   createdb message_unifier
   psql message_unifier -f 001_initial_schema.sql
   psql message_unifier -f 002_add_indexes.sql
   psql message_unifier -f 003_add_full_text_search.sql
   ```

3. **Run importer**:
   ```bash
   signal-importer \
     --signal-db desktop_messages.db \
     --pg-database message_unifier \
     --pg-user postgres \
     --verbose
   ```

4. **Query messages**:
   ```sql
   -- Count messages
   SELECT COUNT(*) FROM messages WHERE platform = 'Signal';

   -- Search messages
   SELECT content->>'text', timestamp
   FROM messages
   WHERE search_vector @@ to_tsquery('english', 'search_term')
   ORDER BY timestamp DESC
   LIMIT 10;
   ```

## Using BD Issue Tracker

This project uses [bd](https://github.com/anthropics/bd) for issue tracking:

```bash
# List issues
bd list

# Show issue details
bd show signal-backup-1

# Create new issue
bd create "Add support for message reactions"

# Update issue status
bd update signal-backup-1 --status closed
```

## Troubleshooting

### "Database is locked"
The Signal app must be closed before extracting the database.

### "Connection refused" to PostgreSQL
Ensure PostgreSQL is running:
```bash
# macOS
brew services start postgresql

# Linux
systemctl start postgresql
```

### Build errors
Update dependencies:
```bash
cabal update
cabal clean
cabal build
```

## Project Structure

```
signal-backup/
├── app/
│   └── Main.hs                    # CLI entry point
├── src/
│   └── SignalImporter/
│       ├── Types.hs               # Data types
│       ├── Reader.hs              # SQLite reader
│       └── Writer.hs              # PostgreSQL writer
├── examples/                      # Example modules
├── *.sql                          # Database schema
├── signal-importer.cabal          # Build configuration
└── QUICK_START.md                 # This file
```
