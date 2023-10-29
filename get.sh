#!/bin/bash

# Help function
usage() {
  echo "Usage: $0 <repo_url> --skip=filename1,filename2,... --destination=/target/folder/"
  exit 1
}

# Check for at least one argument (repo URL)
if [ "$#" -lt 1 ]; then
  usage
fi

# Variables
REPO_URL="$1"
SKIP=""
DESTINATION="."

# Parse optional arguments
shift  # Move off the repo_url
while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip=*)
      SKIP="${1#*=}"
      shift 1
      ;;
    --destination=*)
      DESTINATION="${1#*=}"
      shift 1
      ;;
    *)
      usage
      ;;
  esac
done

# Create an associative array for files to skip for faster lookups
declare -A SKIP_FILES
IFS=',' read -ra FILES_TO_SKIP <<< "$SKIP"
for i in "${FILES_TO_SKIP[@]}"; do
    SKIP_FILES["$i"]=1
done

echo "Cloning repository without LFS files..."
GIT_LFS_SKIP_SMUDGE=1 git clone "$REPO_URL" "$DESTINATION"

# Change to the destination directory
cd "$DESTINATION"

echo "Searching for LFS pointer files to download..."
# Loop through all files and fetch the actual LFS files if they are placeholders
find . -type f | while read -r file; do
    FILENAME=$(basename "$file")
    
    # Check if the file is in our skip list
    if [[ ${SKIP_FILES["$FILENAME"]} ]]; then
        continue
    fi
    
    # Check if the file is an LFS pointer using git lfs pointer --check
    if git lfs pointer --check --file "$file" &>/dev/null; then
        
        # Construct the LFS URL (assuming the LFS is on the same domain as the Git repo)
        LFS_URL="$REPO_URL/resolve/main/$FILENAME"

        echo "Downloading LFS file for $file..."
        # Download the LFS object and overwrite the placeholder file with progress
        wget --progress=bar:force:noscroll -O "$file" "$LFS_URL"
    fi
done

echo "Script completed!"
