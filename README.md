# 📁 organize_by_type

> A powerful shell script for organizing files by type with intelligent duplicate detection and content-based deduplication.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash%2FZsh-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20WSL-blue.svg)](https://github.com/wsmr/Script-Bash-organize_by_type)

## 🌟 Features

- **Smart File Organization**: Automatically categorizes files by extension into `FILE_TYPE_*` folders
- **Content-Based Duplicate Detection**: Uses SHA-256 hashing to identify duplicates based on actual file content
- **Zero Data Loss**: Never deletes files - only moves them to organized folders
- **Intelligent Conflict Resolution**: Handles filename conflicts automatically with smart renaming
- **Preview Before Execution**: Shows detailed directory structure, sizes, and file counts before organizing
- **User Confirmation**: Requires explicit confirmation before making any changes
- **Comprehensive Logging**: Real-time output showing every file operation
- **Recursive Processing**: Processes all files in subdirectories

## 📋 Table of Contents

- [Features](#-features)
- [Requirements](#-requirements)
- [Installation](#-installation)
  - [macOS](#macos)
  - [Linux](#linux)
  - [Windows (WSL)](#windows-wsl)
- [Usage](#-usage)
- [How It Works](#-how-it-works)
- [Output Structure](#-output-structure)
- [Examples](#-examples)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)

## 🔧 Requirements

- **macOS**: zsh (pre-installed on macOS 10.15+) or bash
- **Linux**: bash or zsh
- **Windows**: WSL (Windows Subsystem for Linux) with bash or zsh
- **Additional tools** (usually pre-installed):
  - `find`
  - `shasum` or `sha256sum`
  - `du`
  - `awk`
  - `bc` (for size calculations)

## 📥 Installation

### macOS

1. **Download the script:**
   ```bash
   curl -o ~/organize_by_type.sh https://raw.githubusercontent.com/wsmr/Script-Bash-organize_by_type/main/organize_by_type.sh
   ```

2. **Add to your shell configuration:**
   
   For **zsh** (default on macOS):
   ```bash
   echo "source ~/organize_by_type.sh" >> ~/.zshrc
   source ~/.zshrc
   ```
   
   For **bash**:
   ```bash
   echo "source ~/organize_by_type.sh" >> ~/.bash_profile
   source ~/.bash_profile
   ```

3. **Verify installation:**
   ```bash
   type organize_by_type
   ```

### Linux

1. **Download the script:**
   ```bash
   wget -O ~/organize_by_type.sh https://raw.githubusercontent.com/wsmr/Script-Bash-organize_by_type/main/organize_by_type.sh
   # or use curl
   curl -o ~/organize_by_type.sh https://raw.githubusercontent.com/wsmr/Script-Bash-organize_by_type/main/organize_by_type.sh
   ```

2. **Add to your shell configuration:**
   
   For **bash**:
   ```bash
   echo "source ~/organize_by_type.sh" >> ~/.bashrc
   source ~/.bashrc
   ```
   
   For **zsh**:
   ```bash
   echo "source ~/organize_by_type.sh" >> ~/.zshrc
   source ~/.zshrc
   ```

3. **Verify installation:**
   ```bash
   type organize_by_type
   ```

### Windows (WSL)

1. **Install WSL** (if not already installed):
   ```powershell
   wsl --install
   ```

2. **Open WSL terminal** and follow the Linux installation steps above.

3. **Access Windows directories** from WSL:
   ```bash
   cd /mnt/c/Users/YourUsername/Downloads
   organize_by_type
   ```

## 🚀 Usage

### Basic Usage

Organize files in the current directory:
```bash
organize_by_type
```

Organize files in a specific directory:
```bash
organize_by_type /path/to/directory
```

### Common Examples

```bash
# Organize Downloads folder
organize_by_type ~/Downloads

# Organize specific project folder
organize_by_type ~/Documents/Projects/messy-folder

# Organize external drive
organize_by_type /Volumes/ExternalDrive/Photos

# On Windows (via WSL)
organize_by_type /mnt/c/Users/YourName/Downloads
```

## 🔍 How It Works

### 1. **Preview Phase**
The script first analyzes the target directory and displays:
- Absolute path of the directory
- Total size (precise GB/MB)
- Current folder structure with sizes (top 20 folders)
- File type breakdown (top 15 extensions)
- Total file count

### 2. **User Confirmation**
Prompts for explicit confirmation (`yes`/`no`) before proceeding.

### 3. **Organization Phase**
For each file:
1. Calculates SHA-256 hash of file content
2. Checks if content is unique for that file type
3. **If unique**: Moves to `FILE_TYPE_[EXTENSION]` folder
4. **If duplicate**: Moves to `DUPLICATES_[EXTENSION]` folder
5. Handles filename conflicts with automatic renaming

### 4. **Results**
Shows real-time progress with emoji indicators:
- ✅ Unique file moved
- 🔄 Duplicate file moved
- (renamed) Filename conflict resolved

## 📂 Output Structure

After running the script, your directory will be organized as follows:

```
your-directory/
├── FILE_TYPE_PNG/          # Unique PNG files
│   ├── photo1.png
│   ├── photo2.png
│   └── screenshot.png
├── DUPLICATES_PNG/         # Duplicate PNG files
│   ├── photo1_copy.png
│   └── duplicate_photo.png
├── FILE_TYPE_PDF/          # Unique PDF files
│   └── document.pdf
├── DUPLICATES_PDF/         # Duplicate PDF files
│   └── document_copy.pdf
└── [other TYPE folders...]
```

## 📊 Examples

### Example Output

```
⚠️  ORGANIZE BY TYPE - PREVIEW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 Path: /Users/sahan/Downloads

💾 Total Size: 2.937GB (3005.4MB)

📁 Current Structure:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📂 850M  old_files
  📂 450M  images
  📂 120M  documents

📄 File Types (entire directory tree):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  .PNG              1245 files
  .JPG               856 files
  .PDF               432 files
  .MP4               234 files
  .JSON              123 files

📊 Total Files (entire directory): 3347

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  This will organize all files into:
   • FILE_TYPE_* folders (unique files)
   • DUPLICATES_* folders (duplicate content)

❓ Do you want to proceed? (yes/no): yes

🚀 Starting organization...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Moved: ./photo.png → FILE_TYPE_PNG/photo.png
✅ Moved: ./document.pdf → FILE_TYPE_PDF/document.pdf
🔄 Duplicate: ./photo_copy.png → DUPLICATES_PNG/photo_copy.png
✅ Moved (renamed): ./report.pdf → FILE_TYPE_PDF/report_1.pdf

🎉 Done organizing by type with duplicate detection!
```

## 🛠️ Troubleshooting

### Permission Denied
```bash
# Make sure you have write permissions
ls -la /path/to/directory

# If needed, use sudo (be careful!)
sudo organize_by_type /path/to/directory
```

### Script Not Found
```bash
# Reload your shell configuration
source ~/.zshrc    # for zsh
source ~/.bashrc   # for bash

# Or check if script is sourced
grep "organize_by_type" ~/.zshrc
```

### "bc: command not found"
```bash
# macOS
brew install bc

# Ubuntu/Debian
sudo apt-get install bc

# CentOS/RHEL
sudo yum install bc
```

### Windows/WSL Issues
- Make sure WSL is properly installed
- Use `/mnt/c/` to access Windows drives
- Ensure line endings are Unix-style (LF, not CRLF)

### Large Directory Processing
For directories with thousands of files, the script may take some time:
- The preview phase scans all files to count them
- The organization phase processes each file sequentially
- Consider organizing subdirectories separately for better performance

## 🎯 Best Practices

1. **Backup First**: Always backup important data before organizing
2. **Test on Small Directory**: Try on a test folder first to understand behavior
3. **Review Preview**: Carefully check the preview before confirming
4. **Check Duplicates**: Review DUPLICATES_* folders before deleting
5. **Avoid System Directories**: Don't run on system folders (/, /System, /Windows)

## ⚠️ Important Notes

- The script **never deletes files** - it only moves them
- Hidden files (starting with `.`) are skipped
- Files without extensions are skipped
- Already organized folders (`FILE_TYPE_*`, `DUPLICATES_*`) are skipped
- Duplicate detection is based on **content**, not filename or size
- Original file permissions and timestamps are preserved

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Sahan** - [@wsmr](https://github.com/wsmr)

## 🙏 Acknowledgments

- Inspired by the need for better file organization
- Built with shell scripting best practices
- Community feedback and contributions

## 📮 Support

If you encounter any issues or have questions:

- Open an [Issue](https://github.com/wsmr/Script-Bash-organize_by_type/issues)
- Check existing issues for solutions
- Star ⭐ the repository if you find it useful!

---

**Made with ❤️ for organized file systems**
