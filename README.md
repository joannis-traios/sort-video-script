# sort-video-script

A powerful Bash script (Linux/MacOS) that automatically organizes your media files by sorting them into structured directories based on their type and properties. Videos are sorted by resolution and frames per second (FPS), while other media files (images, audio) and documents are organized into their respective categories.

## Features

- Sorts videos by resolution and frames per second (FPS)
- Organizes images by format (jpeg, png, etc.)
- Categorizes audio files by type
- Handles documents (PDF, text files)
- Preserves original files (uses `rsync` for safe copying)
- Supports recursive directory scanning

## Dependencies

The script requires the following tools:
- `ffprobe` (part of ffmpeg) - for video metadata extraction
- `rsync` - for safe file operations

The script will check for these dependencies and provide installation instructions if they're missing.

### Installation of Dependencies

#### macOS (using Homebrew)
```sh
brew install ffmpeg rsync
```

#### Debian/Ubuntu
```sh
sudo apt install ffmpeg rsync
```

#### Fedora
```sh
sudo dnf install ffmpeg rsync
```

## Quick Usage

1. Clone the repo:
```sh
git clone https://github.com/joannis-traios/sort-video-script.git
```

2. Change to the script directory:
```sh
cd sort-video-script
```

3. Make the script executable:
```sh
chmod +x sort_video.sh
```

4. Run the script with your media directory:
```sh
./sort_video.sh /path/to/your/media/directory
```

## Output Structure

The script creates the following directory structure in your target directory:

```
target_directory/
├── sorted/
│   ├── 1920x1080_30fps/
│   ├── 1280x720_60fps/
│   └── ...
├── media/
│   ├── images/
│   │   ├── jpeg/
│   │   └── png/
│   └── audio/
│       ├── mp3/
│       └── wav/
└── documents/
    ├── pdf/
    └── text/
```

## Options

- `-h` or `--help`: Display help message
- Directory argument: Specify the directory containing files to sort

## Examples

Sort files in the current directory:
```sh
./sort_video.sh .
```

Sort files in a specific directory:
```sh
./sort_video.sh /Users/username/Videos
```

Show help message:
```sh
./sort_video.sh --help
```