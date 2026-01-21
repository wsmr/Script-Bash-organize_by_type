# Organize files by type and detect duplicates: organize_by_type
# Usage: organize_by_type
# Usage: organize_by_type ~/Downloads/mix
# Apply the change without restarting terminal -> source ~/.zshrc
organize_by_type() {
  local root_dir="${1:-.}"
  cd "$root_dir" || { echo "❌ Directory not found: $root_dir"; return 1; }
  
  # Get absolute path for display
  local abs_path="$(pwd)"
  
  # Display warning and structure
  echo "⚠️  ORGANIZE BY TYPE - PREVIEW"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📍 Path: $abs_path"
  echo ""
  
  # Get total size with precise formatting
  local size_bytes=$(du -sk "$root_dir" 2>/dev/null | awk '{print $1}')
  local size_mb=$(awk "BEGIN {printf \"%.1f\", $size_bytes/1024}")
  local size_gb=$(awk "BEGIN {printf \"%.3f\", $size_bytes/1024/1024}")
  
  if (( $(echo "$size_gb >= 1" | bc -l) )); then
    echo "💾 Total Size: ${size_gb}GB (${size_mb}MB)"
  else
    echo "💾 Total Size: ${size_mb}MB"
  fi
  echo ""
  
  # Show top-level structure with sizes
  echo "📁 Current Structure:"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # List directories with sizes
  find "$root_dir" -maxdepth 1 -type d ! -path "$root_dir" -exec du -sh {} \; 2>/dev/null | sort -hr | head -20 | while read -r size dir; do
    dirname="$(basename "$dir")"
    echo "  📂 $size  $dirname"
  done
  
  # Count ALL files by extension (entire directory tree)
  echo ""
  echo "📄 File Types (entire directory tree):"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  typeset -A ext_counts
  local total_files=0
  
  find "$root_dir" -type f | while read -r file; do
    filename="$(basename "$file")"
    # Skip hidden files
    [[ "$filename" == .* ]] && continue
    
    ext="${filename##*.}"
    [[ "$ext" == "$filename" ]] && ext="NO_EXT"
    ext_upper="${(U)ext}"
    
    # Use a temp file to communicate counts back to parent shell
    echo "$ext_upper" >> /tmp/org_ext_count_$$
  done
  
  # Read counts from temp file and display
  if [[ -f /tmp/org_ext_count_$$ ]]; then
    while read -r ext; do
      ((ext_counts[$ext]++))
      ((total_files++))
    done < /tmp/org_ext_count_$$
    
    # Sort and display (using a safer delimiter)
    for ext in ${(k)ext_counts}; do
      printf "  .%-15s %5d files\n" "$ext" "${ext_counts[$ext]}"
    done | sort -k2 -nr | head -15
    
    rm -f /tmp/org_ext_count_$$
    
    echo ""
    echo "📊 Total Files (entire directory): $total_files"
  fi
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⚠️  This will organize all files into:"
  echo "   • FILE_TYPE_* folders (unique files)"
  echo "   • DUPLICATES_* folders (duplicate content)"
  echo ""
  
  # Prompt for confirmation
  echo -n "❓ Do you want to proceed? (yes/no): "
  read -r response
  
  # Check response
  if [[ "$response" != "yes" && "$response" != "y" && "$response" != "Y" && "$response" != "YES" ]]; then
    echo "❌ Operation cancelled."
    return 0
  fi
  
  echo ""
  echo "🚀 Starting organization..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Associative array to track file hashes by extension
  typeset -A file_hashes
  
  # Find all files and process them
  find "$root_dir" -type f | while read -r file; do
    # Skip hidden files
    [[ "$(basename "$file")" == .* ]] && continue
    
    # Skip files already inside FILE_TYPE_ or DUPLICATES_ folders
    rel_path="${file#$root_dir/}"
    top_folder="${rel_path%%/*}"
    [[ "$top_folder" =~ ^FILE_TYPE_ ]] && continue
    [[ "$top_folder" =~ ^DUPLICATES_ ]] && continue
    
    filename="$(basename "$file")"
    ext="${filename##*.}"
    
    # Skip files without extension
    [[ "$ext" == "$filename" ]] && continue
    
    ext_upper="${(U)ext}"
    type_dir="$root_dir/FILE_TYPE_$ext_upper"
    duplicates_dir="$root_dir/DUPLICATES_$ext_upper"
    
    # Calculate file hash (content only)
    file_hash=$(shasum -a 256 "$file" | awk '{print $1}')
    
    # Check if we've seen this hash for this extension before
    hash_key="${ext_upper}_${file_hash}"
    
    if [[ -z "${file_hashes[$hash_key]}" ]]; then
      # First occurrence - move to type directory
      mkdir -p "$type_dir"
      dest_file="$type_dir/$filename"
      
      # Handle filename conflicts in type directory
      if [[ -e "$dest_file" ]]; then
        base="${filename%.*}"
        count=1
        while [[ -e "$type_dir/${base}_$count.$ext" ]]; do
          ((count++))
        done
        dest_file="$type_dir/${base}_$count.$ext"
        mv "$file" "$dest_file"
        echo "✅ Moved (renamed): $file → $dest_file"
      else
        mv "$file" "$dest_file"
        echo "✅ Moved: $file → $dest_file"
      fi
      
      # Mark this hash as seen
      file_hashes[$hash_key]="$dest_file"
    else
      # Duplicate found - move to duplicates directory
      mkdir -p "$duplicates_dir"
      dest_file="$duplicates_dir/$filename"
      
      # Handle filename conflicts in duplicates directory
      if [[ -e "$dest_file" ]]; then
        base="${filename%.*}"
        count=1
        while [[ -e "$duplicates_dir/${base}_$count.$ext" ]]; do
          ((count++))
        done
        dest_file="$duplicates_dir/${base}_$count.$ext"
        mv "$file" "$dest_file"
        echo "🔄 Duplicate (renamed): $file → $dest_file"
      else
        mv "$file" "$dest_file"
        echo "🔄 Duplicate: $file → $dest_file"
      fi
    fi
  done
  
  echo ""
  echo "🎉 Done organizing by type with duplicate detection!"
}
