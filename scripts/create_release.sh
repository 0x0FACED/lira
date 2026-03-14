#!/usr/bin/env bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Lira - Create Release         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Get current version
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
CURRENT_BUILD=$(grep "^version:" pubspec.yaml | awk '{print $2}' | cut -d'+' -f2)

echo -e "${YELLOW}Current version:${NC} $CURRENT_VERSION+$CURRENT_BUILD"
echo ""

# Prompt for new version
read -p "Enter new version [default: $CURRENT_VERSION]: " NEW_VERSION
NEW_VERSION="${NEW_VERSION:-$CURRENT_VERSION}"

# Validate version format
if [[ ! $NEW_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}✗ Invalid version format. Use semantic versioning (e.g., 0.3.0)${NC}"
    exit 1
fi

# Increment build number
NEW_BUILD=$((CURRENT_BUILD + 1))

echo ""
echo -e "${YELLOW}New version will be:${NC} ${NEW_VERSION}+${NEW_BUILD}"
echo ""

# Confirm
read -p "Continue? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cancelled${NC}"
    exit 0
fi

# Update version in pubspec.yaml
echo -e "${YELLOW}Updating pubspec.yaml...${NC}"
sed -i "s/^version: .*/version: ${NEW_VERSION}+${NEW_BUILD}/" pubspec.yaml

# Update version in settings screen (if exists)
if grep -q "subtitle: const Text('0\." lib/features/settings/presentation/settings_screen.dart 2>/dev/null; then
    echo -e "${YELLOW}Updating settings screen...${NC}"
    # Version is now dynamic via package_info_plus, but update comment if exists
fi

# Update CHANGELOG.md
if [[ -f "CHANGELOG.md" ]]; then
    echo -e "${YELLOW}Updating CHANGELOG.md...${NC}"
    
    # Check if version already exists in changelog
    if grep -q "## \[${NEW_VERSION}\]" CHANGELOG.md 2>/dev/null; then
        echo -e "${YELLOW}Version ${NEW_VERSION} already in CHANGELOG.md${NC}"
    else
        # Add new entry
        TODAY=$(date +%Y-%m-%d)
        sed -i "3i\\
## [${NEW_VERSION}] - ${TODAY}\\
\\
### Added\\
- \\
\\
### Changed\\
- Version updated to ${NEW_VERSION}\\
\\
### Fixed\\
- \\
\\
" CHANGELOG.md
        echo -e "${GREEN}✓ CHANGELOG.md updated${NC}"
    fi
else
    # Create CHANGELOG.md
    echo -e "${YELLOW}Creating CHANGELOG.md...${NC}"
    TODAY=$(date +%Y-%m-%d)
    cat > CHANGELOG.md << EOF
# Changelog

All notable changes to this project will be documented in this file.

## [${NEW_VERSION}] - ${TODAY}

### Added
- 

### Changed
- Version updated to ${NEW_VERSION}

### Fixed
- 

EOF
fi

# Git operations
echo ""
echo -e "${YELLOW}Git operations...${NC}"

# Check for uncommitted changes
if ! git diff --quiet; then
    echo -e "${YELLOW}You have uncommitted changes. Commit them first.${NC}"
    echo ""
    read -p "Commit and continue? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git add .
        git commit -m "chore: prepare release v${NEW_VERSION}"
    else
        echo -e "${YELLOW}Cancelled${NC}"
        exit 0
    fi
fi

# Create git tag
TAG_NAME="v${NEW_VERSION}"
if git rev-parse "${TAG_NAME}" >/dev/null 2>&1; then
    echo -e "${RED}✗ Tag ${TAG_NAME} already exists${NC}"
    exit 1
fi

echo -e "${YELLOW}Creating tag ${TAG_NAME}...${NC}"
git tag "${TAG_NAME}"

echo ""
echo -e "${GREEN}✓ Release v${NEW_VERSION}+${NEW_BUILD} prepared!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review changes: git show ${TAG_NAME}"
echo "  2. Push to GitHub: git push origin main --tags"
echo "  3. GitHub Actions will build all platforms"
echo "  4. Or build locally: ./scripts/build_all.sh release"
echo ""
echo -e "${YELLOW}To push now:${NC}"
echo "  git push origin main --tags"
echo ""
