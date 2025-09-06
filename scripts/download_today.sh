#!/bin/bash

# Download Wednesday's photos from Canon R5
# Photos from 6151 onwards

cd /Users/jeremy/Desktop/OK-SHOCK-25
mkdir -p card_download_wednesday
cd card_download_wednesday

echo "📸 Downloading Wednesday's shock collar portraits..."
echo "Will download photos from 3Q7A6151 onwards"

# Keep killing PTPCamera during download
while true; do
    sudo killall PTPCamera 2>/dev/null
    sleep 2
done &
KILL_PID=$!

# Function to clean up background process
cleanup() {
    kill $KILL_PID 2>/dev/null
    exit
}
trap cleanup EXIT

echo "Getting camera file list..."

# Use gphoto2 to list and download files in range
# First check what's on the camera
gphoto2 --list-files | grep "3Q7A" | grep "\.JPG" > /tmp/camera_files.txt

# Count how many we need
to_download=$(cat /tmp/camera_files.txt | awk -F'3Q7A' '{print $2}' | cut -d'.' -f1 | awk '$1 > 6150' | wc -l)
echo "Found $to_download photos to download"

# Download files newer than 6150
cat /tmp/camera_files.txt | while read line; do
    if [[ $line =~ \#([0-9]+).*3Q7A([0-9]+)\.JPG ]]; then
        file_num=${BASH_REMATCH[2]}
        
        if [ $file_num -gt 6150 ]; then
            file_index=$(echo $line | awk '{print $1}' | tr -d '#')
            filename="3Q7A${file_num}.JPG"
            
            echo "Downloading $filename (file #$file_index)..."
            
            # Try download with retry
            for attempt in 1 2 3; do
                if gphoto2 --get-file=$file_index 2>/dev/null; then
                    echo "  ✓ Downloaded"
                    break
                else
                    echo "  ⚠ Attempt $attempt failed, retrying..."
                    sudo killall PTPCamera 2>/dev/null
                    sleep 1
                fi
            done
        fi
    fi
done

# Kill the background PTPCamera killer
kill $KILL_PID 2>/dev/null

# Count results
count=$(ls -1 *.JPG 2>/dev/null | wc -l)
echo "✅ Downloaded $count photos to card_download_wednesday/"

echo "Now organizing into burst sessions..."