#!/bin/bash

# Function: Check if ffprobe and rsync are installed
check_dependencies() {
    for cmd in ffprobe rsync; do
        if ! command -v $cmd &> /dev/null; then
            echo "$cmd is not installed. Please install it."
            case "$(uname -s)" in
                Linux*)   echo "Try: sudo apt install $cmd (Debian/Ubuntu) or sudo dnf install $cmd (Fedora)";;
                Darwin*)  echo "Try: brew install $cmd";;
                *)        echo "Unknown operating system. Please install $cmd manually.";;
            esac
            exit 1
        fi
    done
}

# Function: Extract video information (resolution and FPS) using ffprobe
get_video_info() {
    local file="$1"
    local info
    # Use ffprobe to extract width, height, and frame rate of the video
    info=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate -of csv=p=0 "$file" 2>/dev/null)
    echo "$info"
}

# Function: Recursively scan directory and sort videos
sort_videos() {
    local dir="$1"
    local sorted_dir="$dir/sorted"  # Directory to store sorted videos
    local others_dir="$dir/others" # Directory for unsupported files
    mkdir -p "$sorted_dir" "$others_dir"  # Create the necessary directories

    # Find all files in the directory and its subdirectories
    find "$dir" -type f | while read -r file; do
        local info resolution fps
        info=$(get_video_info "$file")

        # If ffprobe fails to extract video information, move the file to "others"
        if [ -z "$info" ]; then
            rsync --progress --remove-source-files "$file" "$others_dir/"
            if [ $? -eq 0 ]; then
                echo "Unknown format or no video info: $file -> $others_dir/"
                # Check if the original file is empty after rsync and delete it
                [ ! -s "$file" ] && rm -f "$file"
            else
                echo "Error moving file: $file"
            fi
            continue
        fi

        # Extract resolution and FPS from ffprobe output
        resolution=$(echo "$info" | awk -F',' '{print $1"x"$2}')
        fps=$(echo "$info" | awk -F',' '{print $3}' | bc)

        # Create a directory based on resolution and FPS
        local target_dir="$sorted_dir/${resolution}_${fps}fps"
        mkdir -p "$target_dir"

        # Move the file to the target directory using rsync
        rsync --progress --remove-source-files "$file" "$target_dir/"
        if [ $? -eq 0 ]; then
            echo "Successfully moved: $file -> $target_dir/"
            # Check if the original file is empty after rsync and delete it
            [ ! -s "$file" ] && rm -f "$file"
        else
            echo "Error moving file: $file"
        fi
    done
}

# Main program
main() {
    local dir="${1:-.}" # Default to the current directory if no argument is provided

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

main "$@"