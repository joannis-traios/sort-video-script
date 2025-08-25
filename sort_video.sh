#!/bin/bash

# Fuction to check if ffprobe and rsync are installed. Needed in this script.
check_dependencies() {
    for cmd in ffprobe rsync; do
        # Check if the command exists in the system's PATH
        if ! command -v $cmd &> /dev/null; then
            echo "$cmd is not installed. Please install it."
            # Detect the operating system and provide installation instructions
            case "$(uname -s)" in
                Linux*)   echo "Try: sudo apt install $cmd (Debian/Ubuntu) or sudo dnf install $cmd (Fedora)";;
                Darwin*)  echo "Try: brew install $cmd";;  # macOS uses Homebrew for package management
                *)        echo "Unknown operating system. Please install $cmd manually.";;
            esac
            exit 1  # Exit if the required dependency is not found.
        fi
    done
}

# Function: Extract video information (resolution and FPS) using ffprobe
get_video_info() {
    local file="$1"  # The file to analyze
    local info
    # Use ffprobe to extract the width, height, and frame rate of the video
    # -v error: Suppress unnecessary ffprobe logs
    # -select_streams v:0: Focus only on the first video stream
    # -show_entries: Specify the properties to extract (width, height, frame rate)
    # -of csv=p=0: Output as plain CSV without headers
    info=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate -of csv=p=0 "$file" 2>/dev/null)
    # Return the extracted information
    echo "$info"
}

# Function: Get the mime type of a file
get_mime_type() {
    local file="$1"
    file --mime-type "$file" | cut -d' ' -f2
}

# Function: Recursively scan directory and sort files
sort_videos() {
    local dir="$1"  # The directory to process
    local sorted_dir="$dir/sorted"  # Directory to store sorted videos
    local media_dir="$dir/media"    # Directory for other media files
    local docs_dir="$dir/documents" # Directory for documents
    # Create directories if they don't already exist
    mkdir -p "$sorted_dir" "$media_dir" "$docs_dir"

    # Recursively find all files in the specified directory
    find "$dir" -type f | while read -r file; do
        # Skip files that are already in sorted directories
        if [[ "$file" == *"/sorted/"* || "$file" == *"/media/"* || "$file" == *"/documents/"* ]]; then
            continue
        fi

        # Get the mime type of the file
        local mime_type=$(get_mime_type "$file")
        local target_dir

        # Handle different file types
        case "$mime_type" in
            video/*)
                # Process video files with resolution and FPS
                local info resolution fps
                info=$(get_video_info "$file")
                if [ -n "$info" ]; then
                    resolution=$(echo "$info" | awk -F',' '{print $1"x"$2}')
                    fps=$(echo "$info" | awk -F',' '{print $3}' | bc)
                    target_dir="$sorted_dir/${resolution}_${fps}fps"
                else
                    target_dir="$sorted_dir/unknown_format"
                fi
                ;;
            image/*)
                # Sort images by type (jpeg, png, etc.)
                local img_type=${mime_type#image/}
                target_dir="$media_dir/images/$img_type"
                ;;
            audio/*)
                # Sort audio files by type
                local audio_type=${mime_type#audio/}
                target_dir="$media_dir/audio/$audio_type"
                ;;
            application/pdf)
                target_dir="$docs_dir/pdf"
                ;;
            text/*)
                # Sort text files (plain text, markdown, etc.)
                local text_type=${mime_type#text/}
                target_dir="$docs_dir/text/$text_type"
                ;;
            *)
                # Handle other file types based on extension
                local ext=${file##*.}
                if [ "$file" != "$ext" ]; then
                    target_dir="$docs_dir/other/$ext"
                else
                    target_dir="$docs_dir/other/no_extension"
                fi
                ;;
        esac

        # Create target directory and copy file
        mkdir -p "$target_dir"
        rsync --progress "$file" "$target_dir/"
        if [ $? -eq 0 ]; then
            echo "Successfully copied: $file -> $target_dir/"
            # Verify the integrity of the copied file using cmp
            if cmp -s "$file" "$target_dir/$(basename "$file")"; then
                # Delete the original file if the copy matches
                rm -f "$file"
            else
                echo "Warning: File verification failed, original not deleted: $file"
            fi
        else
            echo "Error copying file: $file"
        fi
    done
}

# Function to display help message
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [DIRECTORY]

A script to automatically sort and organize files, with special handling for video files.

Options:
  -h, --help     Display this help message and exit

Arguments:
  DIRECTORY      The directory to process (default: current directory)

Description:
  This script organizes files into categorized directories based on their type:

  - Videos are sorted by resolution and FPS into:        ./sorted/
  - Images are sorted by format (jpeg, png, etc) into:   ./media/images/
  - Audio files are sorted by format into:              ./media/audio/
  - PDFs are stored in:                                 ./documents/pdf/
  - Text files are sorted by type into:                 ./documents/text/
  - Other files are sorted by extension into:           ./documents/other/

Examples:
  $(basename "$0")                   # Sort files in current directory
  $(basename "$0") ~/Downloads      # Sort files in Downloads directory
  $(basename "$0") --help          # Display this help message

Note:
  - The script will create necessary directories if they don't exist
  - Original files are removed after successful copying and verification
  - Requires ffprobe (from ffmpeg) and rsync to be installed.
EOF
}

# Main program
main() {
    # Show help if no arguments or help flag is provided
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_help
        exit 0
    fi

    local dir="$1"  # Use the first argument as the directory

    # Check if required dependencies are installed
    check_dependencies

    # Ensure the target directory exists
    if [ ! -d "$dir" ]; then
        echo "Error: Directory $dir does not exist."
        echo "Use '$(basename "$0") --help' for usage information."
        exit 1
    fi

    # Start sorting files
    sort_videos "$dir"
    echo "Sorting complete. Files have been organized in:"
    echo "  - Videos:     $dir/sorted/"
    echo "  - Media:      $dir/media/"
    echo "  - Documents:  $dir/documents/"
}

# Entry point of the script. I like main functions from other languages :)
# Pass all arguments to the main function.
main "$@"