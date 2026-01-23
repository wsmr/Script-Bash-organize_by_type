#!/bin/bash

################################################################################
# organize_by_type.sh
#
# Description:
#   A powerful shell script that organizes files by type with intelligent 
#   duplicate detection. Uses SHA-256 content hashing to identify true 
#   duplicates, moves files to FILE_TYPE_* and DUPLICATES_* folders without 
#   deletion. Shows preview with sizes & counts before execution.
#
# Usage:
#   chmod +x organize_by_type.sh
#   ./organize_by_type.sh                    # Organize current directory
#   ./organize_by_type.sh /path/to/directory # Organize specific directory
#   
#   # Test first with dry run
#   DRY_RUN=true ./organize_by_type.sh ~/Downloads
#   
#   # Organize only images
#   INCLUDE_EXTENSIONS="jpg,png,gif,jpeg" ./organize_by_type.sh ~/Photos
#   
#   # Skip large files
#   MAX_FILE_SIZE=104857600 ./organize_by_type.sh ~/Documents  # 100MB limit
#   
#   # Use timestamp in folder names
#   USE_TIMESTAMP=true ./organize_by_type.sh ~/Downloads
#   
#   # Skip confirmation for automation
#   SKIP_CONFIRMATION=true ./organize_by_type.sh ~/temp
#
#   
# Features:
#   - Content-based duplicate detection using SHA-256 hashing
#   - Zero data loss - never deletes files
#   - Preview before execution with size analysis
#   - Automatic conflict resolution
#   - Comprehensive logging
#   - Compatible with macOS, Linux, and WSL
#
# Author: Sahan (@wsmr)
# Repository: https://github.com/wsmr/Script-Bash-organize_by_type
# License: MIT
################################################################################

# =============================================================================
# CONFIGURATION SECTION - Modify these as needed
# =============================================================================

# File types to process (leave empty to process all extensions)
INCLUDE_EXTENSIONS=""  # Example: "jpg,png,pdf,mp4" or leave empty for all

# File types to ignore completely
EXCLUDE_EXTENSIONS="tmp,temp,log,bak,swp,swo"  # Add extensions to ignore

# File size range (in bytes) - set to 0 to ignore size limits
MIN_FILE_SIZE=0        # Minimum file size (0 = no limit, example: 1024 for 1KB)
MAX_FILE_SIZE=0        # Maximum file size (0 = no limit, example: 104857600 for 100MB)

# Folder naming options
USE_TIMESTAMP=false    # Set to true to add timestamp like FILE_TYPE_JPG_20250123
DATE_FORMAT="%Y%m%d"   # Date format for folder names (YYYYMMDD)
FOLDER_PREFIX="FILE_TYPE"      # Prefix for unique file folders
DUPLICATES_PREFIX="DUPLICATES" # Prefix for duplicate file folders

# Default folders to ignore (case-insensitive, comma-separated)
DEFAULT_IGNORE_FOLDERS="logs,cache,temp,.git,.svn,node_modules,vendor"

# Processing options
MAX_DEPTH=999          # Maximum folder depth to scan (999 = unlimited)
SKIP_CONFIRMATION=false # Set to true to skip confirmation prompt (use with caution!)
DRY_RUN=false          # Set to true to simulate without moving files

# Logging configuration
ENABLE_LOGGING=true    # Enable/disable logging
LOG_DIR="."            # Log directory (default: script location, use absolute path for custom)
LOG_FILENAME="organize_by_type_$(date +%Y%m%d_%H%M%S).log"
LOG_LEVEL="INFO"       # Options: DEBUG, INFO, WARNING, ERROR

# Display options
VERBOSE=true           # Show detailed output
SHOW_COLORS=true       # Enable colored output
SHOW_STATISTICS=true   # Show statistics at the end

# Performance options
HASH_ALGORITHM="256"   # SHA hash algorithm (256, 512, 1)
PARALLEL_PROCESSING=false # Enable parallel processing (experimental, requires GNU parallel)

# Safety options
CREATE_BACKUP_LIST=true  # Create a backup list of all moves
BACKUP_LIST_FILE="organize_backup_$(date +%Y%m%d_%H%M%S).txt"

# =============================================================================
# END CONFIGURATION SECTION
# =============================================================================

# Color codes for better readability
if [[ "$SHOW_COLORS" == "true" ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  PURPLE='\033[0;35m'
  CYAN='\033[0;36m'
  NC='\033[0m' # No Color
else
  RED='' GREEN='' YELLOW='' BLUE='' PURPLE='' CYAN='' NC=''
fi

# Statistics tracking
STATS_UNIQUE_FILES=0
STATS_DUPLICATE_FILES=0
STATS_SKIPPED_FILES=0
STATS_ERRORS=0
STATS_TOTAL_SIZE_MOVED=0

################################################################################
# Function: log_message
# Description: Logs messages to file and optionally to console
# Parameters:
#   $1 - Log level (DEBUG, INFO, WARNING, ERROR)
#   $2 - Message to log
################################################################################
log_message() {
  local level="$1"
  local message="$2"
  local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  
  # Check if we should log this level
  case "$LOG_LEVEL" in
    DEBUG) ;;
    INFO) [[ "$level" == "DEBUG" ]] && return ;;
    WARNING) [[ "$level" == "DEBUG" || "$level" == "INFO" ]] && return ;;
    ERROR) [[ "$level" != "ERROR" ]] && return ;;
  esac
  
  # Write to log file if enabled
  if [[ "$ENABLE_LOGGING" == "true" ]]; then
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
  fi
  
  # Write to console if verbose
  if [[ "$VERBOSE" == "true" ]]; then
    case "$level" in
      ERROR) echo -e "${RED}[$level]${NC} $message" ;;
      WARNING) echo -e "${YELLOW}[$level]${NC} $message" ;;
      INFO) echo -e "${GREEN}[$level]${NC} $message" ;;
      DEBUG) echo -e "${CYAN}[$level]${NC} $message" ;;
    esac
  fi
}

################################################################################
# Function: is_extension_excluded
# Description: Check if file extension should be excluded
# Parameters:
#   $1 - File extension to check
################################################################################
is_extension_excluded() {
  local ext="$1"
  local ext_upper="${ext^^}"
  
  # Check exclude list
  if [[ -n "$EXCLUDE_EXTENSIONS" ]]; then
    IFS=',' read -ra EXCLUDE_ARRAY <<< "$EXCLUDE_EXTENSIONS"
    for excluded in "${EXCLUDE_ARRAY[@]}"; do
      if [[ "${excluded^^}" == "$ext_upper" ]]; then
        return 0
      fi
    done
  fi
  
  # Check include list (if specified, only process these)
  if [[ -n "$INCLUDE_EXTENSIONS" ]]; then
    IFS=',' read -ra INCLUDE_ARRAY <<< "$INCLUDE_EXTENSIONS"
    for included in "${INCLUDE_ARRAY[@]}"; do
      if [[ "${included^^}" == "$ext_upper" ]]; then
        return 1
      fi
    done
    return 0  # Not in include list, so exclude
  fi
  
  return 1  # Not excluded
}

################################################################################
# Function: is_folder_ignored
# Description: Check if folder should be ignored
# Parameters:
#   $1 - Folder name to check
################################################################################
is_folder_ignored() {
  local folder="$1"
  local folder_upper="${folder^^}"
  
  IFS=',' read -ra IGNORE_ARRAY <<< "$DEFAULT_IGNORE_FOLDERS"
  for ignored in "${IGNORE_ARRAY[@]}"; do
    if [[ "${ignored^^}" == "$folder_upper" ]]; then
      return 0
    fi
  done
  
  return 1
}

################################################################################
# Function: get_file_size
# Description: Get file size in bytes
# Parameters:
#   $1 - File path
################################################################################
get_file_size() {
  local file="$1"
  stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0"
}

################################################################################
# Function: format_size
# Description: Format bytes to human readable size
# Parameters:
#   $1 - Size in bytes
################################################################################
format_size() {
  local bytes="$1"
  if (( bytes < 1024 )); then
    echo "${bytes}B"
  elif (( bytes < 1048576 )); then
    echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1024}")KB"
  elif (( bytes < 1073741824 )); then
    echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1048576}")MB"
  else
    echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1073741824}")GB"
  fi
}

################################################################################
# Function: organize_by_type
# Description: Main function to organize files by type with duplicate detection
# Parameters:
#   $1 - Directory path (optional, defaults to current directory)
################################################################################
organize_by_type() {
  local root_dir="${1:-.}"
  
  # Initialize log file path
  if [[ "$LOG_DIR" == "." ]]; then
    LOG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$LOG_FILENAME"
  else
    LOG_FILE="$LOG_DIR/$LOG_FILENAME"
  fi
  
  # Create backup list file path
  if [[ "$CREATE_BACKUP_LIST" == "true" ]]; then
    if [[ "$LOG_DIR" == "." ]]; then
      BACKUP_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$BACKUP_LIST_FILE"
    else
      BACKUP_FILE="$LOG_DIR/$BACKUP_LIST_FILE"
    fi
  fi
  
  # Change to target directory and verify it exists
  cd "$root_dir" || { 
    echo -e "${RED}❌ Directory not found: $root_dir${NC}" 
    log_message "ERROR" "Directory not found: $root_dir"
    return 1
  }
  
  # Get absolute path for display
  local abs_path="$(pwd)"
  
  log_message "INFO" "========================================"
  log_message "INFO" "Starting organize_by_type"
  log_message "INFO" "Target directory: $abs_path"
  log_message "INFO" "Log file: $LOG_FILE"
  log_message "INFO" "========================================"
  
  #=============================================================================
  # PREVIEW PHASE
  #=============================================================================
  echo -e "${YELLOW}⚠️  ORGANIZE BY TYPE - PREVIEW${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${BLUE}📍 Path:${NC} $abs_path"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}🔍 Mode:${NC} DRY RUN (simulation only, no files will be moved)"
  fi
  
  echo ""
  
  # Calculate total size with precise formatting
  local size_bytes=$(du -sk "$root_dir" 2>/dev/null | awk '{print $1}')
  local size_kb=$((size_bytes))
  local size_mb=$(awk "BEGIN {printf \"%.1f\", $size_bytes/1024}")
  local size_gb=$(awk "BEGIN {printf \"%.3f\", $size_bytes/1024/1024}")
  
  if (( $(echo "$size_gb >= 1" | bc -l) )); then
    echo -e "${PURPLE}💾 Total Size:${NC} ${size_gb}GB (${size_mb}MB)"
  else
    echo -e "${PURPLE}💾 Total Size:${NC} ${size_mb}MB"
  fi
  echo ""
  
  # Show configuration
  echo -e "${CYAN}⚙️  Active Configuration:${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  [[ -n "$INCLUDE_EXTENSIONS" ]] && echo "  Include extensions: $INCLUDE_EXTENSIONS"
  [[ -n "$EXCLUDE_EXTENSIONS" ]] && echo "  Exclude extensions: $EXCLUDE_EXTENSIONS"
  [[ $MIN_FILE_SIZE -gt 0 ]] && echo "  Min file size: $(format_size $MIN_FILE_SIZE)"
  [[ $MAX_FILE_SIZE -gt 0 ]] && echo "  Max file size: $(format_size $MAX_FILE_SIZE)"
  echo "  Max depth: $MAX_DEPTH"
  echo "  Logging: $([[ "$ENABLE_LOGGING" == "true" ]] && echo "Enabled → $LOG_FILE" || echo "Disabled")"
  echo ""
  
  # Show top-level directory structure with sizes
  echo -e "${CYAN}📁 Current Structure:${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  find "$root_dir" -maxdepth 1 -type d ! -path "$root_dir" -exec du -sh {} \; 2>/dev/null | \
    sort -hr | head -20 | while read -r size dir; do
    dirname="$(basename "$dir")"
    echo "  📂 $size  $dirname"
  done
  
  # Count ALL files by extension (entire directory tree)
  echo ""
  echo -e "${CYAN}📄 File Types (entire directory tree):${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Use associative array to track file counts
  declare -A ext_counts
  local total_files=0
  local temp_file="/tmp/org_ext_count_$$"
  
  # Collect file extensions
  find "$root_dir" -type f -maxdepth "$MAX_DEPTH" | while read -r file; do
    filename="$(basename "$file")"
    # Skip hidden files
    [[ "$filename" == .* ]] && continue
    
    ext="${filename##*.}"
    [[ "$ext" == "$filename" ]] && ext="NO_EXT"
    ext_upper="${ext^^}"
    
    echo "$ext_upper" >> "$temp_file"
  done
  
  # Read counts from temp file and display
  if [[ -f "$temp_file" ]]; then
    while read -r ext; do
      ((ext_counts[$ext]++))
      ((total_files++))
    done < "$temp_file"
    
    # Sort and display using printf for safe formatting
    for ext in "${!ext_counts[@]}"; do
      printf "  .%-15s %5d files\n" "$ext" "${ext_counts[$ext]}"
    done | sort -k2 -nr | head -15
    
    rm -f "$temp_file"
    
    echo ""
    echo -e "${GREEN}📊 Total Files (entire directory): $total_files${NC}"
  fi
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${YELLOW}⚠️  This will organize all files into:${NC}"
  
  if [[ "$USE_TIMESTAMP" == "true" ]]; then
    local timestamp_example=$(date +"$DATE_FORMAT")
    echo "   • ${FOLDER_PREFIX}_<EXT>_${timestamp_example} folders (unique files)"
    echo "   • ${DUPLICATES_PREFIX}_<EXT>_${timestamp_example} folders (duplicate content)"
  else
    echo "   • ${FOLDER_PREFIX}_<EXT> folders (unique files)"
    echo "   • ${DUPLICATES_PREFIX}_<EXT> folders (duplicate content)"
  fi
  echo ""
  
  #=============================================================================
  # USER CONFIRMATION
  #=============================================================================
  if [[ "$SKIP_CONFIRMATION" != "true" ]]; then
    echo -n "❓ Do you want to proceed? (yes/no): "
    read -r response
    
    # Check response
    if [[ "$response" != "yes" && "$response" != "y" && "$response" != "Y" && "$response" != "YES" ]]; then
      echo -e "${RED}❌ Operation cancelled.${NC}"
      log_message "INFO" "Operation cancelled by user"
      return 0
    fi
  fi
  
  echo ""
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}🔍 Starting DRY RUN (simulation)...${NC}"
  else
    echo -e "${GREEN}🚀 Starting organization...${NC}"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Initialize backup list
  if [[ "$CREATE_BACKUP_LIST" == "true" && "$DRY_RUN" != "true" ]]; then
    echo "# Organize by Type - Backup List" > "$BACKUP_FILE"
    echo "# Date: $(date)" >> "$BACKUP_FILE"
    echo "# Directory: $abs_path" >> "$BACKUP_FILE"
    echo "# Format: SOURCE -> DESTINATION" >> "$BACKUP_FILE"
    echo "" >> "$BACKUP_FILE"
    log_message "INFO" "Backup list created: $BACKUP_FILE"
  fi
  
  #=============================================================================
  # ORGANIZATION PHASE
  #=============================================================================
  
  # Associative array to track file hashes by extension
  declare -A file_hashes
  
  # Get timestamp for folder naming if enabled
  local timestamp_suffix=""
  if [[ "$USE_TIMESTAMP" == "true" ]]; then
    timestamp_suffix="_$(date +"$DATE_FORMAT")"
  fi
  
  # Find all files and process them
  find "$root_dir" -type f -maxdepth "$MAX_DEPTH" | while read -r file; do
    filename="$(basename "$file")"
    
    # Skip hidden files
    [[ "$filename" == .* ]] && {
      log_message "DEBUG" "Skipped hidden file: $file"
      continue
    }
    
    # Skip files already inside organized folders
    rel_path="${file#$root_dir/}"
    top_folder="${rel_path%%/*}"
    [[ "$top_folder" =~ ^${FOLDER_PREFIX}_ ]] && continue
    [[ "$top_folder" =~ ^${DUPLICATES_PREFIX}_ ]] && continue
    
    # Check if folder should be ignored
    is_folder_ignored "$top_folder" && {
      log_message "DEBUG" "Skipped file in ignored folder: $file"
      ((STATS_SKIPPED_FILES++))
      continue
    }
    
    ext="${filename##*.}"
    
    # Skip files without extension
    [[ "$ext" == "$filename" ]] && {
      log_message "DEBUG" "Skipped file without extension: $file"
      ((STATS_SKIPPED_FILES++))
      continue
    }
    
    ext_upper="${ext^^}"
    
    # Check if extension should be excluded
    is_extension_excluded "$ext" && {
      log_message "DEBUG" "Skipped excluded extension: $file"
      ((STATS_SKIPPED_FILES++))
      continue
    }
    
    # Check file size constraints
    file_size=$(get_file_size "$file")
    if [[ $MIN_FILE_SIZE -gt 0 && $file_size -lt $MIN_FILE_SIZE ]]; then
      log_message "DEBUG" "Skipped file below minimum size: $file ($(format_size $file_size))"
      ((STATS_SKIPPED_FILES++))
      continue
    fi
    if [[ $MAX_FILE_SIZE -gt 0 && $file_size -gt $MAX_FILE_SIZE ]]; then
      log_message "DEBUG" "Skipped file above maximum size: $file ($(format_size $file_size))"
      ((STATS_SKIPPED_FILES++))
      continue
    fi
    
    type_dir="$root_dir/${FOLDER_PREFIX}_${ext_upper}${timestamp_suffix}"
    duplicates_dir="$root_dir/${DUPLICATES_PREFIX}_${ext_upper}${timestamp_suffix}"
    
    # Calculate file hash (content only)
    file_hash=$(shasum -a "$HASH_ALGORITHM" "$file" 2>/dev/null | awk '{print $1}')
    
    if [[ -z "$file_hash" ]]; then
      log_message "ERROR" "Failed to calculate hash for: $file"
      ((STATS_ERRORS++))
      continue
    fi
    
    # Check if we've seen this hash for this extension before
    hash_key="${ext_upper}_${file_hash}"
    
    if [[ -z "${file_hashes[$hash_key]}" ]]; then
      # First occurrence - move to type directory
      if [[ "$DRY_RUN" != "true" ]]; then
        mkdir -p "$type_dir"
      fi
      dest_file="$type_dir/$filename"
      
      # Handle filename conflicts in type directory
      if [[ -e "$dest_file" ]]; then
        base="${filename%.*}"
        count=1
        while [[ -e "$type_dir/${base}_$count.$ext" ]]; do
          ((count++))
        done
        dest_file="$type_dir/${base}_$count.$ext"
        
        if [[ "$DRY_RUN" == "true" ]]; then
          echo -e "${GREEN}✅ Would move (renamed):${NC} $file → $dest_file"
        else
          mv "$file" "$dest_file"
          echo -e "${GREEN}✅ Moved (renamed):${NC} $file → $dest_file"
          [[ "$CREATE_BACKUP_LIST" == "true" ]] && echo "$file -> $dest_file" >> "$BACKUP_FILE"
        fi
        log_message "INFO" "Moved (renamed): $file -> $dest_file"
      else
        if [[ "$DRY_RUN" == "true" ]]; then
          echo -e "${GREEN}✅ Would move:${NC} $file → $dest_file"
        else
          mv "$file" "$dest_file"
          echo -e "${GREEN}✅ Moved:${NC} $file → $dest_file"
          [[ "$CREATE_BACKUP_LIST" == "true" ]] && echo "$file -> $dest_file" >> "$BACKUP_FILE"
        fi
        log_message "INFO" "Moved: $file -> $dest_file"
      fi
      
      # Mark this hash as seen
      file_hashes[$hash_key]="$dest_file"
      ((STATS_UNIQUE_FILES++))
      ((STATS_TOTAL_SIZE_MOVED += file_size))
    else
      # Duplicate found - move to duplicates directory
      if [[ "$DRY_RUN" != "true" ]]; then
        mkdir -p "$duplicates_dir"
      fi
      dest_file="$duplicates_dir/$filename"
      
      # Handle filename conflicts in duplicates directory
      if [[ -e "$dest_file" ]]; then
        base="${filename%.*}"
        count=1
        while [[ -e "$duplicates_dir/${base}_$count.$ext" ]]; do
          ((count++))
        done
        dest_file="$duplicates_dir/${base}_$count.$ext"
        
        if [[ "$DRY_RUN" == "true" ]]; then
          echo -e "${CYAN}🔄 Would move duplicate (renamed):${NC} $file → $dest_file"
        else
          mv "$file" "$dest_file"
          echo -e "${CYAN}🔄 Duplicate (renamed):${NC} $file → $dest_file"
          [[ "$CREATE_BACKUP_LIST" == "true" ]] && echo "$file -> $dest_file (DUPLICATE)" >> "$BACKUP_FILE"
        fi
        log_message "INFO" "Moved duplicate (renamed): $file -> $dest_file"
      else
        if [[ "$DRY_RUN" == "true" ]]; then
          echo -e "${CYAN}🔄 Would move duplicate:${NC} $file → $dest_file"
        else
          mv "$file" "$dest_file"
          echo -e "${CYAN}🔄 Duplicate:${NC} $file → $dest_file"
          [[ "$CREATE_BACKUP_LIST" == "true" ]] && echo "$file -> $dest_file (DUPLICATE)" >> "$BACKUP_FILE"
        fi
        log_message "INFO" "Moved duplicate: $file -> $dest_file"
      fi
      
      ((STATS_DUPLICATE_FILES++))
      ((STATS_TOTAL_SIZE_MOVED += file_size))
    fi
  done
  
  #=============================================================================
  # COMPLETION & STATISTICS
  #=============================================================================
  echo ""
  echo -e "${GREEN}🎉 Done organizing by type with duplicate detection!${NC}"
  
  if [[ "$SHOW_STATISTICS" == "true" ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${PURPLE}📊 STATISTICS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "  Unique files moved:     ${GREEN}$STATS_UNIQUE_FILES${NC}"
    echo -e "  Duplicate files moved:  ${CYAN}$STATS_DUPLICATE_FILES${NC}"
    echo -e "  Files skipped:          ${YELLOW}$STATS_SKIPPED_FILES${NC}"
    echo -e "  Errors encountered:     ${RED}$STATS_ERRORS${NC}"
    echo -e "  Total files processed:  $((STATS_UNIQUE_FILES + STATS_DUPLICATE_FILES))"
    echo -e "  Total size moved:       $(format_size $STATS_TOTAL_SIZE_MOVED)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  fi
  
  if [[ "$ENABLE_LOGGING" == "true" ]]; then
    echo -e "${BLUE}📝 Log file saved:${NC} $LOG_FILE"
  fi
  
  if [[ "$CREATE_BACKUP_LIST" == "true" && "$DRY_RUN" != "true" ]]; then
    echo -e "${BLUE}💾 Backup list saved:${NC} $BACKUP_FILE"
  fi
  
  log_message "INFO" "========================================"
  log_message "INFO" "Statistics: Unique=$STATS_UNIQUE_FILES, Duplicates=$STATS_DUPLICATE_FILES, Skipped=$STATS_SKIPPED_FILES, Errors=$STATS_ERRORS"
  log_message "INFO" "Total size moved: $(format_size $STATS_TOTAL_SIZE_MOVED)"
  log_message "INFO" "Operation completed successfully"
  log_message "INFO" "========================================"
}

################################################################################
# MAIN EXECUTION
################################################################################

# Check if script is being sourced or executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Script is being executed directly
  organize_by_type "$@"
else
  # Script is being sourced (e.g., in .bashrc or .zshrc)
  # Function is now available in the shell
  echo "organize_by_type function loaded. Usage: organize_by_type [directory]"
fi
