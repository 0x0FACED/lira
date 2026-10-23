#!/usr/bin/env bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Build type
BUILD_TYPE="${1:-release}"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Lira - Android Build             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Build type:${NC} $BUILD_TYPE"
echo ""

# Release builds must use a configured, persistent signing key.
if [[ "$BUILD_TYPE" == "release" && ! -f "android/key.properties" ]]; then
    echo -e "${RED}Release signing requires android/key.properties.${NC}"
    echo "Configure your keystore as described in RELEASE.md."
    echo "Use './scripts/build_android.sh debug' for a debug-signed test APK."
    exit 1
fi

# Build APK
echo -e "${YELLOW}Building APK...${NC}"
flutter build apk --"$BUILD_TYPE"

if [[ "$BUILD_TYPE" == "release" ]]; then
    echo ""
    echo -e "${GREEN}✓ Release APK created${NC}"
    echo ""
    echo "Output: build/app/outputs/flutter-apk/app-release.apk"
    echo ""
    
    # Build App Bundle
    read -p "Also build App Bundle (.aab) for Google Play? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Building App Bundle...${NC}"
        flutter build appbundle --release
        echo ""
        echo -e "${GREEN}✓ App Bundle created${NC}"
        echo "Output: build/app/outputs/bundle/release/app-release.aab"
    fi
else
    echo ""
    echo -e "${GREEN}✓ Debug APK created${NC}"
    echo "Output: build/app/outputs/flutter-apk/app-debug.apk"
fi

echo ""
echo -e "${YELLOW}To install on connected device:${NC}"
echo "  flutter install"
echo ""
