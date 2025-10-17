MOST IMPORTANTLY USE BD - terminal command for beads for storing mission and path at all time

# Mission Status: COMPLETED ✓
Created Haskell Signal importer successfully. See bd issue signal-backup-1 (closed).

# Continuous Improvement Loop

When you work on this project, ALWAYS follow this self-testing loop:

1. **Track with BD** - Create/update bd issues for all work
   ```bash
   bd list
   bd create "Description of task"
   bd update signal-backup-X --status in_progress
   ```

2. **Make Changes** - Edit code as needed

3. **Build** - Always build after changes
   ```bash
   cabal clean
   cabal build 2>&1
   ```

4. **Fix Errors** - If build fails:
   - Read error messages carefully
   - Fix compilation errors
   - Re-run build
   - LOOP until build succeeds

5. **Test** - After successful build, test functionality:
   ```bash
   # Dry run test
   cabal run signal-importer -- --signal-db desktop_messages.db --dry-run --verbose

   # Full test with PostgreSQL (if available)
   cabal run signal-importer -- --signal-db desktop_messages.db --pg-database message_unifier --verbose
   ```

6. **Fix Runtime Errors** - If tests fail:
   - Read error output
   - Fix bugs
   - Rebuild and re-test
   - LOOP until tests pass

7. **Update BD** - Mark issues complete
   ```bash
   bd update signal-backup-X --status closed --notes "Description of what was done"
   ```

8. **Document** - Update QUICK_START.md if needed

## Self-Testing Rules

- **NEVER** consider a task complete until `cabal build` succeeds
- **ALWAYS** run at least a dry-run test after building
- **LOOP** through build-fix-test cycle automatically
- **TRACK** all work with bd issues
- If you encounter errors, fix them immediately and rebuild

## Example Loop

```bash
# Start
bd create "Add feature X"
bd list

# Edit code
vim src/SignalImporter/SomeModule.hs

# Build and test loop
cabal build 2>&1
# If errors: fix, then build again
# If success: continue

# Test
cabal run signal-importer -- --help
cabal run signal-importer -- --signal-db desktop_messages.db --dry-run

# If errors: fix, rebuild, re-test
# If success: continue

# Complete
bd update signal-backup-X --status closed
```

---

# Original Mission (COMPLETED)

Create a Haskell program storing in a database, exploiting the database in ./Signal-Archive
we created and used in @scab_final.py to fill in a database compatible with our SQL migration
files and database definition in *.sql

This program is in Haskell. Example files are in "examples" folder.

✓ Completed: See signal-importer.cabal, app/Main.hs, src/SignalImporter/*.hs




















Issues chained together like beads. A lightweight issue tracker with first-class dependency support.

Usage:
  bd [command]

Available Commands:
  blocked     Show blocked issues
  close       Close one or more issues
  completion  Generate the autocompletion script for the specified shell
  create      Create a new issue (or multiple issues from markdown file)
  dep         Manage dependencies
  export      Export issues to JSONL format
  help        Help about any command
  import      Import issues from JSONL format
  init        Initialize bd in the current directory
  list        List issues
  quickstart  Quick start guide for bd
  ready       Show ready work (no blockers)
  show        Show issue details
  stats       Show statistics
  update      Update an issue
  version     Print version information

Flags:
      --actor string     Actor name for audit trail (default: $BD_ACTOR or $USER)
      --db string        Database path (default: auto-discover .beads/*.db or ~/.beads/default.db)
  -h, --help             help for bd
      --json             Output in JSON format
      --no-auto-flush    Disable automatic JSONL sync after CRUD operations
      --no-auto-import   Disable automatic JSONL import when newer than DB

Use "bd [command] --help" for more information about a command.





