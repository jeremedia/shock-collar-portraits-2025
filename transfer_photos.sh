#!/bin/bash

# Transfer photos from MacBook Air to organized structure

AIR_HOST="jeremy@jer-air"
AIR_BASE="/Users/jeremy/Desktop/OKNOTOK/OK-SHOCK-25"
LOCAL_BASE="session_originals"

echo "🔍 Starting photo transfer from MacBook Air..."
echo "================================================"

# Function to transfer files for a specific pattern
transfer_pattern() {
    local pattern="$1"
    local desc="$2"

    echo -e "\n📦 Transferring $desc..."

    # Find all matching files on Air and transfer them
    ssh $AIR_HOST "find $AIR_BASE -name '$pattern' -type f 2>/dev/null" | while read -r remote_file; do
        filename=$(basename "$remote_file")
        base_name="${filename%.*}"

        # Find the corresponding local directory
        local_dir=$(find "$LOCAL_BASE" -type d -name "$base_name" 2>/dev/null | head -1)

        if [ -n "$local_dir" ]; then
            echo "  → $filename to $local_dir/"
            rsync -az "$AIR_HOST:$remote_file" "$local_dir/" 2>/dev/null
        fi
    done
}

# Transfer Canon photos (3Q7A*.JPG)
echo "📸 Canon R5 Photos"
echo "=================="

# Transfer in batches by number range for better progress tracking
for prefix in 5 6 7 8 9 0 1 2 3 4; do
    echo -e "\n  Processing 3Q7A${prefix}*.JPG files..."
    transfer_pattern "3Q7A${prefix}*.JPG" "Canon photos starting with 3Q7A${prefix}"
done

# Transfer iPhone photos
echo -e "\n📱 iPhone Photos"
echo "================"
transfer_pattern "IMG_*.HEIC" "iPhone HEIC photos"

# Verify transfer
echo -e "\n✅ Verification"
echo "==============="

# Count transferred files
transferred_count=$(find "$LOCAL_BASE" -type f \( -name "*.JPG" -o -name "*.HEIC" \) | wc -l)
echo "Files transferred: $transferred_count"

# Check for empty directories
empty_dirs=$(find "$LOCAL_BASE" -type d -empty | wc -l)
echo "Empty directories (need files): $empty_dirs"

# Sample verification
echo -e "\n📋 Sample of transferred files:"
find "$LOCAL_BASE" -type f \( -name "*.JPG" -o -name "*.HEIC" \) | head -10 | while read -r file; do
    size=$(ls -lh "$file" | awk '{print $5}')
    echo "  ✓ $(basename "$file") ($size) in $(dirname "$file")"
done

echo -e "\n🎉 Transfer complete!"
echo "Next steps:"
echo "  1. Verify all files: find $LOCAL_BASE -type d -empty"
echo "  2. Check file sizes: du -sh $LOCAL_BASE/*"
echo "  3. Proceed with MinIO migration"