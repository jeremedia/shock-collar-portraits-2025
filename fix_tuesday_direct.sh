#!/bin/bash

echo "====================================="
echo "FIXING TUESDAY ZERO-BYTE FILES"
echo "====================================="

# First, get list of all zero-byte files
echo "Finding zero-byte files..."
find session_originals/tuesday -name "*.JPG" -size 0 > /tmp/zero_byte_list.txt
TOTAL=$(wc -l < /tmp/zero_byte_list.txt)
echo "Found $TOTAL zero-byte files"

# Extract unique burst patterns to find on Air
echo "Identifying burst sessions..."
cat /tmp/zero_byte_list.txt | while read file; do
  basename "$file" | sed 's/\.JPG//'
done | sort -u > /tmp/files_to_find.txt

# Find each file's source location on Air
echo "Locating source files on MacBook Air..."
rm -f /tmp/source_paths.txt

while read filename; do
  echo -n "Finding $filename... "
  ssh jeremy@jer-air "find /Users/jeremy/Desktop/OKNOTOK/OK-SHOCK-25/card_download_1 -name '${filename}.JPG' -type f | grep -v zero_byte | head -1" >> /tmp/source_paths.txt
  echo "found"
done < /tmp/files_to_find.txt

# Get unique burst folders
cat /tmp/source_paths.txt | xargs -I {} dirname {} | sort -u > /tmp/burst_folders.txt
BURST_COUNT=$(wc -l < /tmp/burst_folders.txt)

echo ""
echo "Found $BURST_COUNT burst folders to copy"
echo ""

# Copy each burst folder's relevant files
FIXED=0
while read burst_folder; do
  if [ -z "$burst_folder" ]; then
    continue
  fi

  BURST_NAME=$(basename "$burst_folder")
  echo "📦 Processing burst: $BURST_NAME"

  # Get list of files we need from this burst
  grep "$burst_folder" /tmp/source_paths.txt | while read source_file; do
    if [ -z "$source_file" ]; then
      continue
    fi

    FILENAME=$(basename "$source_file")
    BASENAME="${FILENAME%.*}"
    LOCAL_PATH="session_originals/tuesday/$BASENAME/$FILENAME"

    # Copy the file
    echo -n "  Copying $FILENAME... "
    scp -q "jeremy@jer-air:'$source_file'" "$LOCAL_PATH" 2>/dev/null

    if [ -s "$LOCAL_PATH" ]; then
      echo "✅ $(ls -lh "$LOCAL_PATH" | awk '{print $5}')"
      FIXED=$((FIXED + 1))
    else
      echo "❌ failed"
    fi
  done
done < /tmp/burst_folders.txt

echo ""
echo "====================================="
echo "SUMMARY"
echo "====================================="
echo "Fixed $FIXED of $TOTAL files"
echo ""

# Verify
REMAINING=$(find session_originals/tuesday -name "*.JPG" -size 0 | wc -l)
echo "Remaining zero-byte files: $REMAINING"

if [ "$REMAINING" -eq 0 ]; then
  echo "✨ All files fixed!"
else
  echo "⚠️  Some files still need fixing"
fi