# Ableton File Tools

A powerful command-line tool for migrating Ableton Live project files by automatically updating file paths and references. This tool eliminates the need to manually reconcile missing files when moving your Ableton projects to new locations.

## What it Does

Ableton Live stores file paths as absolute references within `.als` project files. When you move your projects to a new location (like from OneDrive to iCloud, or to a new computer), Ableton can't find the referenced samples, recordings, and other assets. Normally, you'd have to open each project individually and manually relocate hundreds of missing files.

**Ableton File Tools automates this process** by directly modifying the XML content inside your `.als` files to update all path references in bulk.

## Features

- 🔍 **Preview Mode**: See what changes will be made without modifying files
- 🔄 **Bulk Migration**: Process dozens or hundreds of projects at once
- 💾 **Smart Backup**: Automatically backup entire project directories before making changes
- 🎯 **Pattern Matching**: Replace any text pattern, not just file paths
- 📊 **Detailed Reporting**: See exactly which files were modified and how many references were updated
- 🛡️ **Safe Operation**: Built-in validation and cleanup of temporary files

## Installation

1. Clone this repository:
```bash
git clone https://github.com/aubsynth/ableton-file-tools.git
cd ableton-file-tools
```

2. Make the script executable:
```bash
chmod +x migrate.sh
```

3. Create your configuration file (optional):
```bash
cp vars.env.example vars.env
# Edit vars.env with your specific paths
```

## Configuration

Create a `vars.env` file to set default paths:

```bash
# Old path to replace (e.g., your old storage location)
old_path="/Users/username/OneDrive/Music Projects/"

# New path to replace with (e.g., your new storage location)  
new_path="/Users/username/iCloud Drive/Music Projects/"

# Backup location (optional, defaults to parent directory)
backup_base_path="/Users/username/Backups"
```

## Usage

The tool provides several commands for different operations:

### 1. Preview Changes (Recommended First Step)

See what files contain your old path without making any changes:

```bash
./migrate.sh dry_run
```

For detailed output showing sample matches:

```bash
./migrate.sh dry_run verbose
```

### 2. Create Backups

**Always backup before making changes!**

```bash
./migrate.sh backup_files
```

This creates a timestamped backup of all directories containing `.als` files.

### 3. Migrate Projects

After reviewing the preview and creating backups:

```bash
./migrate.sh migrate
```

For verbose output during migration:

```bash
./migrate.sh migrate verbose
```

## Example Workflow

```bash
# 1. Navigate to your Ableton projects directory
cd "/Users/username/Music/Ableton Projects"

# 2. Preview what will be changed
./migrate.sh dry_run verbose

# 3. Create backups of all project directories
./migrate.sh backup_files

# 4. Perform the migration
./migrate.sh migrate

# 5. Open Ableton and verify your projects work correctly
```

## Common Use Cases

### Moving from OneDrive to iCloud
```bash
old_path="/Users/username/OneDrive/Music"
new_path="/Users/username/Library/Mobile Documents/com~apple~CloudDocs/Music"
```

### Migrating to a New Computer
```bash
old_path="/Users/oldusername/Documents"
new_path="/Users/newusername/Documents"
```

### Reorganizing Project Structure
```bash
old_path="/Music/Old Structure/Projects"
new_path="/Music/New Structure/Ableton Projects"
```

## How It Works

1. **File Discovery**: Scans for `.als` files in the current directory and subdirectories
2. **Decompression**: Ableton files are gzipped XML - the tool decompresses them temporarily
3. **Pattern Matching**: Searches for your specified old path pattern in the XML content
4. **Replacement**: Replaces all instances with your new path
5. **Recompression**: Compresses the modified XML back to `.als` format
6. **Cleanup**: Removes all temporary files

## Safety Features

- **Backup Integration**: Built-in backup functionality preserves entire project directories
- **Preview Mode**: Always test with `dry_run` before making changes
- **Validation**: Input validation ensures paths meet minimum requirements
- **Error Handling**: Graceful handling of corrupted or non-standard files
- **Atomic Operations**: Each file is processed completely or not at all

## Output Example

```
INFO:  Found 71 .als files to process
INFO:  Processing (1/71): MyProject.als
INFO:  ✓ MATCH: MyProject.als (28 matches)
INFO:  Processing (2/71): AnotherProject.als
INFO:  ✓ NO MATCH: AnotherProject.als
...
INFO:  === SUMMARY ===
INFO:  Completed processing 71 files
INFO:  Files with matches: 45
INFO:  Files without matches: 26
INFO:  Failed to process: 0
```

## Requirements

- macOS or Linux
- Bash 4.0+
- Standard Unix tools (`find`, `grep`, `sed`, `gzip`)

## Troubleshooting

**"No such file or directory" errors**: Ensure you're running the script from the directory containing your Ableton projects.

**"Failed to decompress" errors**: Some `.als` files may be corrupted or in an unexpected format. The tool will skip these and continue processing.

**Changes not taking effect**: Make sure Ableton Live is closed when running the migration, then reopen your projects.

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This tool modifies your Ableton project files. While it includes safety features and backup functionality, always ensure you have backups of your important projects before using any migration tool. Use at your own risk.
