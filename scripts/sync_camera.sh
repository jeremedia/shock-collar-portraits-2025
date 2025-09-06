#!/bin/bash

# Canon R5 Photo Sync Script
# Handles PTPCamera conflicts, downloads new photos, organizes into bursts

set -e

# Configuration
BASE_DIR="/Users/jeremy/Desktop/OK-SHOCK-25"
DOWNLOAD_DIR="${BASE_DIR}/card_download_1"
TEMP_DIR="${BASE_DIR}/sync_temp"
LAST_SYNC_FILE="${BASE_DIR}/.last_sync"
BURST_GAP_SECONDS=30
MIN_BURST_SIZE=3

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Kill PTPCamera and keep it dead
kill_ptpcamera() {
    sudo killall PTPCamera 2>/dev/null || true
    sudo killall PhotoAnalysisService 2>/dev/null || true
    sudo killall photolibraryd 2>/dev/null || true
}

# Get last synced photo number
get_last_sync() {
    if [ -f "$LAST_SYNC_FILE" ]; then
        cat "$LAST_SYNC_FILE"
    else
        # Find highest photo number in existing bursts
        local last_photo=$(find "$DOWNLOAD_DIR" -name "3Q7A*.JPG" 2>/dev/null | \
            sed 's/.*3Q7A\([0-9]*\)\.JPG/\1/' | \
            sort -n | tail -1)
        
        if [ -z "$last_photo" ]; then
            echo "0"
        else
            echo "$last_photo"
        fi
    fi
}

# Save last synced photo number
save_last_sync() {
    echo "$1" > "$LAST_SYNC_FILE"
}

# Get camera file list with retries
get_camera_files() {
    local attempts=3
    local success=false
    
    for i in $(seq 1 $attempts); do
        log "Getting camera file list (attempt $i/$attempts)..."
        kill_ptpcamera
        sleep 2
        
        if gphoto2 --list-files 2>/dev/null > /tmp/camera_files_raw.txt; then
            # Extract JPG files with their indices
            grep "\.JPG" /tmp/camera_files_raw.txt | grep "3Q7A" > /tmp/camera_files.txt || true
            
            if [ -s /tmp/camera_files.txt ]; then
                success=true
                break
            fi
        fi
        
        warn "Failed to get file list, retrying..."
        sleep 3
    done
    
    if [ "$success" = false ]; then
        error "Failed to get camera file list after $attempts attempts"
        return 1
    fi
    
    return 0
}

# Download a single file with retry
download_file() {
    local file_index=$1
    local filename=$2
    local max_attempts=3
    
    for attempt in $(seq 1 $max_attempts); do
        kill_ptpcamera
        
        if gphoto2 --get-file=$file_index 2>/dev/null; then
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            warn "Download failed for $filename, retry $attempt/$max_attempts"
            sleep 2
        fi
    done
    
    return 1
}

# Organize photos into burst sessions
organize_bursts() {
    local source_dir=$1
    log "Organizing photos into burst sessions..."
    
    # Get all JPG files sorted by modification time
    local photos=$(ls -1t "$source_dir"/*.JPG 2>/dev/null)
    
    if [ -z "$photos" ]; then
        warn "No photos found to organize"
        return
    fi
    
    local burst_num=$(find "$DOWNLOAD_DIR" -type d -name "burst_*" 2>/dev/null | wc -l)
    burst_num=$((burst_num + 1))
    
    local last_time=0
    local burst_photos=()
    local burst_start_time=""
    
    while IFS= read -r photo; do
        # Get photo timestamp
        local photo_time=$(stat -f %m "$photo")
        
        # Check if this starts a new burst
        if [ $last_time -eq 0 ] || [ $((photo_time - last_time)) -gt $BURST_GAP_SECONDS ]; then
            # Save previous burst if it exists
            if [ ${#burst_photos[@]} -ge $MIN_BURST_SIZE ]; then
                local burst_date=$(date -r "$burst_start_time" "+%Y%m%d_%H%M%S")
                local burst_dir="${DOWNLOAD_DIR}/burst_$(printf "%03d" $burst_num)_${burst_date}"
                
                mkdir -p "$burst_dir"
                for bp in "${burst_photos[@]}"; do
                    mv "$bp" "$burst_dir/"
                done
                
                log "Created burst $(printf "%03d" $burst_num) with ${#burst_photos[@]} photos"
                burst_num=$((burst_num + 1))
            else
                # Move to misc if too few photos
                if [ ${#burst_photos[@]} -gt 0 ]; then
                    local misc_dir="${DOWNLOAD_DIR}/misc_photos"
                    mkdir -p "$misc_dir"
                    for bp in "${burst_photos[@]}"; do
                        mv "$bp" "$misc_dir/"
                    done
                    log "Moved ${#burst_photos[@]} photos to misc (too few for burst)"
                fi
            fi
            
            # Start new burst
            burst_photos=()
            burst_start_time="$photo_time"
        fi
        
        burst_photos+=("$photo")
        last_time=$photo_time
    done <<< "$photos"
    
    # Handle last burst
    if [ ${#burst_photos[@]} -ge $MIN_BURST_SIZE ]; then
        local burst_date=$(date -r "$burst_start_time" "+%Y%m%d_%H%M%S")
        local burst_dir="${DOWNLOAD_DIR}/burst_$(printf "%03d" $burst_num)_${burst_date}"
        
        mkdir -p "$burst_dir"
        for bp in "${burst_photos[@]}"; do
            mv "$bp" "$burst_dir/"
        done
        
        log "Created burst $(printf "%03d" $burst_num) with ${#burst_photos[@]} photos"
    fi
}

# Main sync function
sync_camera() {
    log "Starting camera sync..."
    
    # Create temp directory
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Get last synced photo
    local last_sync=$(get_last_sync)
    log "Last synced photo: 3Q7A${last_sync}.JPG"
    
    # Get camera file list
    if ! get_camera_files; then
        error "Cannot get camera file list"
        return 1
    fi
    
    # Count new photos
    local new_photos=$(cat /tmp/camera_files.txt | \
        awk -F'3Q7A' '{print $2}' | \
        cut -d'.' -f1 | \
        awk -v last="$last_sync" '$1 > last' | \
        wc -l | tr -d ' ')
    
    if [ "$new_photos" -eq 0 ]; then
        log "No new photos to sync"
        return 0
    fi
    
    log "Found $new_photos new photos to download"
    
    # Download new photos
    local downloaded=0
    local failed=0
    local highest_photo=0
    
    while IFS= read -r line; do
        if [[ $line =~ \#([0-9]+).*3Q7A([0-9]+)\.JPG ]]; then
            local file_index=${BASH_REMATCH[1]}
            local photo_num=${BASH_REMATCH[2]}
            local filename="3Q7A${photo_num}.JPG"
            
            if [ $photo_num -gt $last_sync ]; then
                echo -ne "\rDownloading: $filename ($downloaded/$new_photos)..."
                
                if download_file "$file_index" "$filename"; then
                    downloaded=$((downloaded + 1))
                    if [ $photo_num -gt $highest_photo ]; then
                        highest_photo=$photo_num
                    fi
                else
                    failed=$((failed + 1))
                    error "Failed to download $filename"
                fi
            fi
        fi
    done < /tmp/camera_files.txt
    
    echo "" # New line after progress
    
    log "Downloaded $downloaded photos, $failed failed"
    
    if [ $downloaded -gt 0 ]; then
        # Organize into bursts
        organize_bursts "$TEMP_DIR"
        
        # Update last sync
        save_last_sync "$highest_photo"
        
        # Rebuild index
        log "Rebuilding photo index..."
        cd "${BASE_DIR}/shock-collar-vue"
        node server/scripts/buildIndex.js
        
        log "✅ Sync complete! $downloaded new photos added."
    else
        warn "No photos were successfully downloaded"
    fi
    
    # Cleanup
    cd "$BASE_DIR"
    rm -rf "$TEMP_DIR"
}

# Kill any running PTPCamera killer from previous attempts
pkill -f "while.*PTPCamera" 2>/dev/null || true

# Main execution
log "Canon R5 Photo Sync"
log "===================="

sync_camera

log "Done!"