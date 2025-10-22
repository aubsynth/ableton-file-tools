#!/usr/bin/env bash
set -euo pipefail

# Load environment variables from vars.env if it exists
if [ -f "vars.env" ]; then
    echo "Loading environment variables from vars.env"
    source vars.env
fi

# Logging configuration - set verbosity level (0=ERROR, 1=WARN, 2=INFO, 3=DEBUG)
VERBOSITY=${VERBOSITY:-2}  # Default to INFO level, can be overridden with env var

# Logging functions
log_error() { [ $VERBOSITY -ge 0 ] && echo -e "ERROR: $*" >&2 || true; }
log_warn()  { [ $VERBOSITY -ge 1 ] && echo -e "WARN:  $*" >&2 || true; }
log_info()  { [ $VERBOSITY -ge 2 ] && echo -e "INFO:  $*" >&2 || true; }
log_debug() { [ $VERBOSITY -ge 3 ] && echo -e "DEBUG: $*" >&2 || true; }

# ANSI color codes (much faster than tput)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

# @desc Cleanup function for temporary files - runs on script exit/termination
cleanup() {
    local exit_code=$?
    # Clean up any leftover temporary files
    log_info "Cleaning up temporary files..."
    find . -name "*.tmp.gz" -print -delete 2>/dev/null || true
    find . -name "*.tmp.xml" -print -delete 2>/dev/null || true
    log_info "Cleanup complete."
    exit $exit_code
}

# Set up cleanup trap
trap cleanup EXIT INT TERM


# Initialize variables if not set
old_path="${old_path:-}"
new_path="${new_path:-}"
backup_base_path="${backup_base_path:-..}"

# Prompt for old_path if not provided
if [ -z "$old_path" ]; then
  read -p "Enter the old path/text to replace: " old_path
fi

# Validate old_path is not empty and contains reasonable content
if [ -z "$old_path" ] || [ ${#old_path} -lt 3 ]; then
    log_error "Old path must be at least 3 characters long"
    exit 1
fi

log_info "${YELLOW}Old path:${RESET} $old_path"

# Prompt for new_path if not provided
if [ -z "$new_path" ]; then
  read -p "Enter the new path/text to replace with: " new_path
fi

# Validate new_path is not empty
if [ -z "$new_path" ]; then
    log_error "New path cannot be empty"
    exit 1
fi

log_info "${GREEN}New path:${RESET} $new_path"

# @desc Function that handles processing of .als files for both dry_run and migrate modes - Do not run directly
process_files() {
    # Setup counters
    local file_count=0
    local processed_count=0
    local files_modified=0
    local files_with_matches=0
    local files_without_matches=0
    local failed_files=0

    # Enable verbose logging if requested
    local verbose_mode="$1"
    local mode="$2"
    if [ $mode ]; then
        log_info "Running in $mode mode"
    fi

    log_info "Searching for .als files in current directory..."

    # First, count total files
    while IFS= read -r -d '' file; do
        ((file_count++))
    done < <(find . -name "*.als" -print0)

    log_info "Found $file_count .als files to process"
    
    # Use process substitution and read to handle filenames with spaces properly
    while IFS= read -r -d '' file; do
        ((processed_count++))
        log_info "Processing ($processed_count/$file_count): $(basename "$file")"

        # Set up temporary file names
        local temp_gz="${file}.tmp.gz"
        local temp_xml="${file}.tmp.xml"
        
        # Copy, decompress and rename the file
        if cp "$file" "$temp_gz" && gunzip "$temp_gz"; then
            # The decompressed file will be at ${temp_gz%.gz}
            mv "${temp_gz%.gz}" "$temp_xml"
            log_debug "Successfully decompressed $file as gzipped XML"

            # Find directory paths in the XML file
            if grep -q "$old_path" "$temp_xml"; then
                if [ "$mode" == "dry_run" ]; then
                    local match_count=$(grep -c "$old_path" "$temp_xml" || true)
                    log_info "✓ MATCH: $(basename "$file") ($match_count matches)"
                    # Show sample matches if in verbose mode
                    if [ "$verbose_mode" = true ]; then
                        log_info "Sample matches:"
                        grep "$old_path" "$temp_xml" | head -3 | sed 's/^[[:space:]]*/  /' || true
                    fi
                elif [ "$mode" == "migrate" ]; then
                    # Show sample matches if in verbose mode
                    if [ "$verbose_mode" = true ]; then
                        log_info "Sample matches:"
                        grep "$old_path" "$temp_xml" | head -3 | sed 's/^[[:space:]]*/  /' || true
                    fi
                    # Replace directory paths in the XML file
                    if sed -i '' "s|$old_path|$new_path|g" "$temp_xml"; then
                        # Re-compress and replace original file
                        if gzip -c "$temp_xml" > "$file"; then
                            log_info "✓ Successfully updated $(basename "$file")"
                            ((files_modified++))
                        else
                            log_error "✗ Failed to recompress $(basename "$file")"
                            ((failed_files++))
                        fi
                    else
                        log_error "✗ Failed to replace paths in $(basename "$file")"
                        ((failed_files++))
                    fi
                fi
                ((files_with_matches++))
            else
                log_info "✓ NO MATCH: $(basename "$file")"
                ((files_without_matches++))
            fi

            # Clean up temporary files
            rm -f "$temp_gz" "$temp_xml"
        else
            log_error "✗ Failed to decompress $(basename "$file")"
            # Clean up temporary files
            rm -f "$temp_gz" "$temp_xml"
            ((failed_files++))
        fi
    done < <(find . -name "*.als" -print0)

    log_info "=== SUMMARY ==="
    log_info "Completed processing $processed_count files"
    log_info "Files with matches: $files_with_matches"
    log_info "Files without matches: $files_without_matches"
    log_info "Failed to process: $failed_files"
}

# @desc Preview changes without modifying files - shows what paths would be replaced (use 'verbose' as parameter to show detailed output)
dry_run() {
    # Enable verbose logging if requested
    local verbose_mode=false
    if [ "${1:-}" = "verbose" ]; then
        verbose_mode=true
    fi
    process_files $verbose_mode "dry_run"
}

# @desc Replace old paths with new paths in all .als files (destructive operation)
migrate() {
    # Enable verbose logging if requested
    local verbose_mode=false
    if [ "${1:-}" = "verbose" ]; then
        verbose_mode=true
    fi
    
    # Safety check: Ask if they've created a backup
    log_warn "${RED}${BOLD}IMPORTANT: Migration will modify your .als files directly.${RESET}"
    read -p "Have you created a backup using './migrate.sh backup_files'? (y/n): " backup_confirm
    
    if [[ "$backup_confirm" != "y" && "$backup_confirm" != "Y" ]]; then
        log_error "${RED}WARNING: You haven't confirmed having a backup!${RESET}"
        log_error "${RED}It's strongly recommended to create backups before migration.${RESET}"
        log_info "${GREEN}You can create backups by running: ./migrate.sh backup_files${RESET}"
        read -p "Are you absolutely sure you want to continue without a backup? (y/n): " continue_confirm
        
        if [[ "$continue_confirm" != "y" && "$continue_confirm" != "Y" ]]; then
            log_info "Migration cancelled. Please create a backup first with: ./migrate.sh backup_files"
            exit 0
        fi
        log_warn "${YELLOW}Proceeding without backup confirmation...${RESET}"
    else
        log_info "${GREEN}Backup confirmed. Proceeding with migration...${RESET}"
    fi
    
    process_files $verbose_mode "migrate"
}

# @desc Create backup copies of all directories containing .als files
backup_files() {
    local backup_dir="${backup_base_path}/backup_$(date +%Y%m%d_%H%M%S)"
    log_info "Creating backup directory: $backup_dir"

    # Create backup directory
    if mkdir -p "$backup_dir"; then
        local dir_count=0
        # Find all unique directories containing .als files
        while IFS= read -r project_dir; do
            if [[ -n "$project_dir" && "$project_dir" != "." ]]; then
                log_info "Backing up directory: $project_dir"
                # Copy the entire directory to the backup location
                if cp -r "$project_dir" "$backup_dir/"; then
                    log_debug "Successfully backed up: $project_dir"
                    ((dir_count++))
                # If copy failed, show error message
                else
                    log_error "Failed to backup directory: $project_dir"
                fi
            fi
        done < <(find . -name "*.als" -exec dirname {} \; | sed 's|/Backup$||' | sort -u)

        log_info "Backed up $dir_count directories to $backup_dir"
    else
        log_error "Failed to create backup directory"
        exit 1
    fi
}

# Check if a function name is provided as the first argument
if [ $# -gt 0 ] && [ -n "$1" ] && declare -f "$1" > /dev/null; then
    # Call the function with any remaining arguments
    "$@"
else
    echo "Usage: ./migrate.sh <function_name> [arguments...]"
    echo ""
    echo "Available functions:"

    # Parse function names and descriptions from this script
    while IFS= read -r line; do
        if [[ $line =~ ^#[[:space:]]*@desc[[:space:]]+(.+)$ ]]; then
            description="${BASH_REMATCH[1]}"
        elif [[ $line =~ ^([a-zA-Z_][a-zA-Z0-9_]*)\(\)[[:space:]]*\{ ]]; then
            func_name="${BASH_REMATCH[1]}"
            if [[ $func_name != log_* ]]; then
                if [[ -n ${description:-} ]]; then
                    printf "  %-15s - %s\n" "$func_name" "$description"
                else
                    printf "  %-15s\n" "$func_name"
                fi
                description=""
            fi
        fi
    done < "$0"

    echo ""
    echo "Example: ./migrate.sh dry_run verbose"
fi
