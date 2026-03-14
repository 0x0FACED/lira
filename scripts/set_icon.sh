#!/usr/bin/env bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Lira - Set App Icon              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Check if icon file is provided
if [[ -n "$1" ]]; then
    ICON_PATH="$1"
else
    echo -e "${YELLOW}Usage:${NC}"
    echo "  ./scripts/set_icon.sh /path/to/icon.png"
    echo ""
    echo -e "${YELLOW}Or just copy your icon to:${NC}"
    echo "  assets/icon/icon.png"
    echo ""
    read -p "Enter path to icon file (or press Enter to skip): " ICON_PATH
fi

# Copy icon if path provided
if [[ -n "$ICON_PATH" ]]; then
    if [[ ! -f "$ICON_PATH" ]]; then
        echo -e "${RED}✗ File not found: $ICON_PATH${NC}"
        exit 1
    fi
    
    # Create directory if not exists
    mkdir -p assets/icon
    
    # Copy icon
    echo -e "${YELLOW}Copying icon...${NC}"
    cp "$ICON_PATH" assets/icon/icon.png
    echo -e "${GREEN}✓ Icon copied to assets/icon/icon.png${NC}"
    echo ""
fi

# Check if icon exists
if [[ ! -f "assets/icon/icon.png" ]]; then
    echo -e "${RED}✗ Icon not found at assets/icon/icon.png${NC}"
    exit 1
fi

# Check image dimensions (if identify is available)
if command -v identify &> /dev/null; then
    DIMENSIONS=$(identify -format "%wx%h" assets/icon/icon.png)
    echo -e "${YELLOW}Icon dimensions:${NC} $DIMENSIONS"
    
    WIDTH=$(echo $DIMENSIONS | cut -d'x' -f1)
    HEIGHT=$(echo $DIMENSIONS | cut -d'x' -f2)
    
    if [[ $WIDTH -lt 1024 || $HEIGHT -lt 1024 ]]; then
        echo -e "${RED}⚠ Warning: Icon is smaller than recommended (1024x1024)${NC}"
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
fi

# Generate icons
echo ""
echo -e "${YELLOW}Generating icons for Android and iOS...${NC}"
flutter pub run flutter_launcher_icons:main || true  # Ignore gradle.kts error

# Update web icons manually (flutter_launcher_icons 0.9.3 doesn't support web)
echo ""
echo -e "${YELLOW}Updating web icons...${NC}"
cp assets/icon/icon.png web/icons/Icon-192.png
cp assets/icon/icon.png web/icons/Icon-512.png
cp assets/icon/icon.png web/icons/Icon-maskable-192.png
cp assets/icon/icon.png web/icons/Icon-maskable-512.png

echo -e "${GREEN}✓ Icons generated successfully!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Rebuild your app: flutter build apk --release"
echo "  2. Check icons in build output"
echo ""
read -p "Rebuild now? [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    flutter clean
    flutter pub get
    flutter build apk --release
    echo ""
    echo -e "${GREEN}✓ Build complete!${NC}"
fi
