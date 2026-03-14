#!/usr/bin/env bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build_dist"

# Build type (debug or release)
BUILD_TYPE="${1:-release}"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Lira - Build All Platforms        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Build type:${NC} $BUILD_TYPE"
echo -e "${YELLOW}Output directory:${NC} $BUILD_DIR"
echo ""

# Create output directory
mkdir -p "$BUILD_DIR"

# Clean before build
echo -e "${YELLOW}[1/7] Cleaning...${NC}"
cd "$PROJECT_ROOT"
flutter clean
flutter pub get
echo ""

# Track successful builds
declare -a SUCCESSFUL_BUILDS=()
declare -a FAILED_BUILDS=()

# Function to build platform
build_platform() {
    local platform="$1"
    local target="$2"
    local output_name="$3"
    
    echo -e "${YELLOW}[${SUCCESSFUL_BUILDS[@]+${#SUCCESSFUL_BUILDS[@]} + 1}/${#SUCCESSFUL_BUILDS[@]} + ${#FAILED_BUILDS[@]} + 1] Building $platform...${NC}"
    
    if flutter build "$target" --"$BUILD_TYPE" 2>&1 | tee "$BUILD_DIR/build_${output_name}.log"; then
        echo -e "${GREEN}✓ $platform build successful${NC}"
        
        # Copy artifacts to build_dist
        case "$platform" in
            "Android APK")
                cp "$PROJECT_ROOT/build/app/outputs/flutter-apk/app-${BUILD_TYPE}.apk" "$BUILD_DIR/lira-${BUILD_TYPE}-android.apk"
                ;;
            "Android AppBundle")
                cp "$PROJECT_ROOT/build/app/outputs/bundle/${BUILD_TYPE}Bundle/app-${BUILD_TYPE}.aab" "$BUILD_DIR/lira-${BUILD_TYPE}-android.aab"
                ;;
            "Linux")
                cp -r "$PROJECT_ROOT/build/linux/x64/${BUILD_TYPE}/bundle/"* "$BUILD_DIR/lira-${BUILD_TYPE}-linux/" 2>/dev/null || true
                ;;
            "Web")
                cp -r "$PROJECT_ROOT/build/web/"* "$BUILD_DIR/lira-${BUILD_TYPE}-web/"
                ;;
            "Windows")
                cp -r "$PROJECT_ROOT/build/windows/x64/${BUILD_TYPE}/bundle/"* "$BUILD_DIR/lira-${BUILD_TYPE}-windows/" 2>/dev/null || true
                ;;
            "macOS")
                cp -r "$PROJECT_ROOT/build/macos/Build/Products/${BUILD_TYPE}/Lira.app" "$BUILD_DIR/" 2>/dev/null || true
                ;;
        esac
        
        SUCCESSFUL_BUILDS+=("$platform")
    else
        echo -e "${RED}✗ $platform build failed${NC}"
        FAILED_BUILDS+=("$platform")
    fi
    echo ""
}

# Android APK
echo -e "${BLUE}─── Android ───${NC}"
build_platform "Android APK" "apk" "android_apk"

# Android AppBundle (only for release)
if [[ "$BUILD_TYPE" == "release" ]]; then
    build_platform "Android AppBundle" "appbundle" "android_aab"
fi

# Linux
echo -e "${BLUE}─── Linux ───${NC}"
if flutter devices | grep -q "Linux"; then
    build_platform "Linux" "linux" "linux"
else
    echo -e "${YELLOW}⊘ Linux desktop not available, skipping${NC}"
    FAILED_BUILDS+=("Linux (not available)")
fi
echo ""

# Web
echo -e "${BLUE}─── Web ───${NC}"
build_platform "Web" "web" "web"

# Windows
echo -e "${BLUE}─── Windows ───${NC}"
if flutter devices | grep -q "Windows"; then
    build_platform "Windows" "windows" "windows"
else
    echo -e "${YELLOW}⊘ Windows desktop not available, skipping${NC}"
    FAILED_BUILDS+=("Windows (not available)")
fi
echo ""

# macOS
echo -e "${BLUE}─── macOS ───${NC}"
if flutter devices | grep -q "macOS"; then
    build_platform "macOS" "macos" "macos"
else
    echo -e "${YELLOW}⊘ macOS not available, skipping${NC}"
    FAILED_BUILDS+=("macOS (not available)")
fi
echo ""

# iOS (only on macOS)
echo -e "${BLUE}─── iOS ───${NC}"
if [[ "$(uname)" == "Darwin" ]]; then
    build_platform "iOS" "ios" "ios"
else
    echo -e "${YELLOW}⊘ iOS build requires macOS, skipping${NC}"
    FAILED_BUILDS+=("iOS (requires macOS)")
fi
echo ""

# Summary
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Build Summary               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

if [[ ${#SUCCESSFUL_BUILDS[@]} -gt 0 ]]; then
    echo -e "${GREEN}Successful builds (${#SUCCESSFUL_BUILDS[@]}):${NC}"
    for build in "${SUCCESSFUL_BUILDS[@]}"; do
        echo -e "  ${GREEN}✓${NC} $build"
    done
fi

if [[ ${#FAILED_BUILDS[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}Failed/Skipped builds (${#FAILED_BUILDS[@]}):${NC}"
    for build in "${FAILED_BUILDS[@]}"; do
        echo -e "  ${RED}✗${NC} $build"
    done
fi

echo ""
echo -e "${YELLOW}Build artifacts:${NC} $BUILD_DIR"
echo ""

# Create checksums
if [[ ${#SUCCESSFUL_BUILDS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Creating checksums...${NC}"
    cd "$BUILD_DIR"
    find . -type f -name "*.apk" -o -name "*.aab" | while read -r file; do
        sha256sum "$file" > "${file}.sha256" 2>/dev/null || true
    done
    echo -e "${GREEN}✓ Checksums created${NC}"
fi

echo ""
echo -e "${GREEN}Done!${NC}"

# Exit with error if any builds failed
if [[ ${#FAILED_BUILDS[@]} -gt 0 ]]; then
    exit 1
fi
