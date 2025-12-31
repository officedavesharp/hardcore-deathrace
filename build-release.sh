#!/bin/bash

# Build script for Hardcore Deathrace addon
# Increments version number and creates a CurseForge-compatible zip file

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the addon directory (script location)
ADDON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDON_NAME="Hardcore Deathrace"
TOC_FILE="${ADDON_DIR}/${ADDON_NAME}.toc"

echo -e "${YELLOW}Building ${ADDON_NAME} release...${NC}"

# Check if .toc file exists
if [ ! -f "$TOC_FILE" ]; then
    echo "Error: ${TOC_FILE} not found!"
    exit 1
fi

# Read current version from .toc file
CURRENT_VERSION=$(grep "^## Version:" "$TOC_FILE" | sed 's/^## Version: //' | tr -d ' ')

if [ -z "$CURRENT_VERSION" ]; then
    echo "Error: Could not find version in .toc file!"
    exit 1
fi

echo "Current version: ${CURRENT_VERSION}"

# Parse version components (assumes semantic versioning: X.Y.Z)
IFS='.' read -ra VERSION_PARTS <<< "$CURRENT_VERSION"
MAJOR=${VERSION_PARTS[0]}
MINOR=${VERSION_PARTS[1]}
PATCH=${VERSION_PARTS[2]}

# Increment patch version
PATCH=$((PATCH + 1))
NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

echo "New version: ${NEW_VERSION}"

# Update version in .toc file
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/^## Version:.*/## Version: ${NEW_VERSION}/" "$TOC_FILE"
else
    # Linux
    sed -i "s/^## Version:.*/## Version: ${NEW_VERSION}/" "$TOC_FILE"
fi

echo -e "${GREEN}✓ Version updated in .toc file${NC}"

# Create temporary directory for building
BUILD_DIR=$(mktemp -d)
ZIP_ROOT="${BUILD_DIR}/${ADDON_NAME}"

# Copy addon files to build directory, excluding system files and git files
echo "Copying files to build directory..."

# Create the root folder structure
mkdir -p "$ZIP_ROOT"

# Copy all files and folders, excluding:
# - .git directory
# - .DS_Store and other Apple system files
# - .gitignore
# - build-release.sh (this script)
# - Any zip files
rsync -av \
    --exclude='.git' \
    --exclude='.DS_Store' \
    --exclude='._*' \
    --exclude='.Spotlight-V100' \
    --exclude='.Trashes' \
    --exclude='.gitignore' \
    --exclude='.gitattributes' \
    --exclude='build-release.sh' \
    --exclude='*.zip' \
    "${ADDON_DIR}/" "${ZIP_ROOT}/"

# Remove any Apple system files that might have been copied
find "$ZIP_ROOT" -name ".DS_Store" -delete
find "$ZIP_ROOT" -name "._*" -delete

echo -e "${GREEN}✓ Files copied${NC}"

# Create zip file with proper structure (root folder included)
ZIP_NAME="${ADDON_NAME}-${NEW_VERSION}.zip"
ZIP_PATH="${ADDON_DIR}/${ZIP_NAME}"

# Remove old zip if it exists
if [ -f "$ZIP_PATH" ]; then
    rm "$ZIP_PATH"
fi

# Create zip file from build directory (this ensures the root folder is included)
cd "$BUILD_DIR"
zip -r "$ZIP_PATH" "${ADDON_NAME}" -x "*.DS_Store" "*._*" > /dev/null

# Clean up temporary directory
rm -rf "$BUILD_DIR"

echo -e "${GREEN}✓ Zip file created: ${ZIP_NAME}${NC}"
echo ""
echo -e "${GREEN}Release build complete!${NC}"
echo "Version: ${NEW_VERSION}"
echo "File: ${ZIP_PATH}"

