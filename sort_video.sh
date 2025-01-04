#!/bin/bash

# Function: Check if ffprobe and rsync are installed
# These tools are essential for extracting video information (ffprobe)
# and safely copying/moving files (rsync).
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
            exit 1  # Exit if the required dependency is not found
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

# Function: Recursively scan directory and sort videos
sort_videos() {
    local dir="$1"  # The directory to process
    local sorted_dir="$dir/sorted"  # Directory to store sorted videos
    local others_dir="$dir/others" # Directory for unsupported or unknown files
    # Create directories if they don't already exist
    mkdir -p "$sorted_dir" "$others_dir"

    # Recursively find all files in the specified directory
    find "$dir" -type f | while read -r file; do
        # Skip files that are already in the 'sorted' or 'others' folders
        if [[ "$file" == *"/sorted/"* || "$file" == *"/others/"* ]]; then
            continue
        fi

        local info resolution fps
        # Extract video information using ffprobe
        info=$(get_video_info "$file")

        # If ffprobe fails to extract information, move the file to "others"
        if [ -z "$info" ]; then
            rsync --progress "$file" "$others_dir/"  # Safely copy the file to "others"
            if [ $? -eq 0 ]; then
                echo "Unknown format or no video info: $file -> $others_dir/"
            else
                echo "Error moving file: $file"
            fi
            continue  # Skip to the next file
        fi

        # Extract resolution and FPS from the ffprobe output
        resolution=$(echo "$info" | awk -F',' '{print $1"x"$2}')  # Combine width and height into "WIDTHxHEIGHT" format
        fps=$(echo "$info" | awk -F',' '{print $3}' | bc)  # Convert frame rate to a simple number using bc

        # Create a directory based on resolution and FPS
        local target_dir="$sorted_dir/${resolution}_${fps}fps"
        mkdir -p "$target_dir"

        # Safely copy the file to the target directory using rsync
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

# Main program
main() {
    local dir="${1:-.}"  # Use the first argument as the directory, or default to the current directory

    # Check if required dependencies are installed
    check_dependencies

    # Ensure the target directory exists
    if [ ! -d "$dir" ]; then
        echo "Error: Directory $dir does not exist."
        exit 1
    fi

    # Start sorting videos
    sort_videos "$dir"
    echo "Sorting complete. Check the '$dir/sorted' and '$dir/others' folders."
}

# Entry point of the script
# Pass all arguments to the main function
main "$@"