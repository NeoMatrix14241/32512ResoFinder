# Large TIFF File Processor (32512x32512 Resolution Finder)

A PowerShell-based parallel processing tool for handling large TIFF files. This tool identifies TIFF files that exceed specified dimensions (default: 32512x32512) and processes them efficiently using parallel processing.

## Features

- Parallel processing with configurable number of concurrent jobs
- Progress tracking with detailed status updates
- Preserves directory structure when copying files
- Error handling and logging
- Configurable maximum width and height thresholds
- Memory-efficient batch processing

## Requirements

- Windows PowerShell or PowerShell Core
- ImageMagick installed and accessible from command line
- Windows OS (tested on Windows 10/11)

## Installation

1. Clone this repository:
```bash
git clone https://github.com/YourUsername/large-tiff-processor.git
```

2. Ensure ImageMagick is installed:
   - Download from [ImageMagick Official Website](https://imagemagick.org/script/download.php)
   - Make sure it's added to your system's PATH

## Usage

1. Run the batch file:
```bash
LaunchAnalyzeLargeTiffImages.bat
```

2. Enter the requested information:
   - Source folder path (where your TIFF files are located)
   - Destination folder path (where to copy large TIFF files)

3. The script will automatically:
   - Scan for TIFF files in the source directory and subdirectories
   - Process files in parallel (default: 12 concurrent jobs)
   - Copy files exceeding size limits to the destination
   - Maintain original folder structure
   - Display progress and results

## Configuration

Default settings can be modified in the PowerShell script:
- `maxWidth`: 32512 (default)
- `maxHeight`: 32512 (default)
- `maxConcurrentJobs`: 12 (default)

## Output

The script provides real-time feedback including:
- Processing progress
- Files copied
- Error reports
- Final statistics
