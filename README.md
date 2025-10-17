# Signal Desktop Database Extractor

Extract and view your Signal Desktop conversation history as an interactive HTML page.

This tool works with **modern Signal Desktop (v7.x+)** which uses encrypted database keys stored in macOS Keychain. It leverages the excellent [signalbackup-tools](https://github.com/bepaald/signalbackup-tools) by bepaald for database decryption.

## Features

- ✅ Works with modern Signal Desktop (v7.x+) encrypted databases
- ✅ Automatically decrypts database using macOS Keychain
- ✅ Exports all conversations to interactive HTML viewer
- ✅ Preserves conversation structure and metadata
- ✅ Generates JSON exports for further processing

## Prerequisites

- macOS (uses Keychain for decryption)
- Homebrew
- Python 3
- Signal Desktop installed with message history

## Quick Start

### 1. Install Dependencies

```bash
# Install system dependencies
brew install cmake sqlcipher

# Clone and build signalbackup-tools
cd /tmp
git clone https://github.com/bepaald/signalbackup-tools.git
cd signalbackup-tools
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j $(sysctl -n hw.ncpu)
```

### 2. Backup Your Signal Data

```bash
# Copy your Signal Desktop data to a safe location
rsync -avz "/Users/$(whoami)/Library/Application Support/Signal" Signal-Archive
```

### 3. Extract Database

```bash
# Navigate to your Signal backup
cd Signal-Archive/Signal

# Decrypt the database using signalbackup-tools
/tmp/signalbackup-tools/build/signalbackup-tools --desktopdir . --dumpdesktopdb desktop_messages.db
```

This will:
- Automatically retrieve the encryption key from macOS Keychain
- Decrypt the Signal Desktop database
- Save it as `desktop_messages.db`

### 4. Generate HTML Viewer

```bash
# Run the extraction script (from Signal-Archive/Signal directory)
python3 /path/to/scab_final.py
```

### 5. View Your Messages

```bash
open myConversations.html
```

## Output Files

After extraction, you'll have:

- **`myConversations.html`** - Interactive web viewer for all conversations
- **`contacts.json`** - All Signal contacts and conversation metadata
- **`convos.json`** - Complete message history in JSON format
- **`desktop_messages.db`** - Decrypted SQLite database (for advanced users)

## How It Works

Modern Signal Desktop uses multiple layers of encryption:

1. **Encrypted Key in config.json**: The `encryptedKey` field contains the database encryption key in encrypted form
2. **macOS Keychain**: The key to decrypt `encryptedKey` is stored in macOS Keychain under "Signal Safe Storage"
3. **SQLCipher Database**: The actual message database is encrypted using SQLCipher

The `signalbackup-tools` handles all of this automatically by:
- Accessing the macOS Keychain to get the safe storage key
- Decrypting the `encryptedKey` from `config.json`
- Using the decrypted key to open the SQLCipher database

## Advanced Usage

### Show Database Encryption Key

```bash
cd Signal-Archive/Signal
/tmp/signalbackup-tools/build/signalbackup-tools --desktopdir . --showdesktopkey
```

### Export to Other Formats

The `signalbackup-tools` supports many export formats:

```bash
# Export to plain text
/tmp/signalbackup-tools/build/signalbackup-tools --desktopdir . --exporttxt output_dir

# Export with signalbackup-tools HTML exporter (more features)
/tmp/signalbackup-tools/build/signalbackup-tools --desktopdir . --exporthtml output_dir --allhtmlpages
```

See the [signalbackup-tools documentation](https://github.com/bepaald/signalbackup-tools) for more options.

### Query the Database Directly

Once you have `desktop_messages.db`, you can query it with SQLite:

```bash
sqlite3 desktop_messages.db

# Example queries:
sqlite> SELECT COUNT(*) FROM messages;
sqlite> SELECT name FROM conversations WHERE type='private' LIMIT 10;
sqlite> .schema messages
```

## Troubleshooting

### "Failed to get sqlcipher key"

Make sure:
- Signal Desktop is installed and has been opened at least once
- You're running the command from the correct Signal data directory
- You have access to the macOS Keychain (you may be prompted for password)

### "Database was created with a newer version of SQLite3"

This warning is usually harmless. If you encounter issues, update your SQLite3:

```bash
brew upgrade sqlite
```

### Permission Denied

Ensure you have read permissions for the Signal directory:

```bash
ls -la "/Users/$(whoami)/Library/Application Support/Signal"
```

## Privacy & Security

- **Local Only**: All processing happens locally on your machine
- **No Upload**: Your messages are never sent anywhere
- **Keychain Access**: The script requires keychain access to decrypt the database
- **Backup Safety**: Always work on a copy of your Signal data, never the live database

## Credits

- [signalbackup-tools](https://github.com/bepaald/signalbackup-tools) by bepaald - The amazing tool that handles all the decryption
- Original [signal-backup](https://github.com/mattsta/signal-backup) by mattsta - Inspiration for HTML viewer
- Signal Desktop team for the excellent messaging app

## License

This project is for personal use. Respect Signal's terms of service and your local privacy laws.

## Useful Links

- [Signal Desktop on GitHub](https://github.com/signalapp/Signal-Desktop)
- [signalbackup-tools Documentation](https://github.com/bepaald/signalbackup-tools)
- [SQLCipher](https://www.zetetic.net/sqlcipher/)

## Contributing

Found a bug or have an improvement? Feel free to submit issues or pull requests!

---

**Note**: This tool is provided as-is for personal backup purposes. Always ensure you're complying with applicable laws and Signal's terms of service when exporting your data.
