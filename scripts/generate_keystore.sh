#!/usr/bin/env bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Generate Android Release Keystore   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

ANDROID_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../android" && pwd)"

echo -e "${YELLOW}This will create a keystore for signing your Android release builds.${NC}"
echo ""
echo -e "${RED}⚠ IMPORTANT:${NC}"
echo "  - Store this file safely! If you lose it, you can't update your app."
echo "  - Remember your passwords!"
echo "  - Validity: 10000 days (~27 years)"
echo ""

read -p "Enter keystore file path [default: ~/lira-release-key.jks]: " KEYSTORE_PATH
KEYSTORE_PATH="${KEYSTORE_PATH:-$HOME/lira-release-key.jks}"

read -p "Enter key alias [default: lira]: " KEY_ALIAS
KEY_ALIAS="${KEY_ALIAS:-lira}"

echo ""
echo -e "${YELLOW}Generating keystore at: $KEYSTORE_PATH${NC}"
echo ""

keytool -genkey -v \
    -keystore "$KEYSTORE_PATH" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -alias "$KEY_ALIAS"

echo ""
echo -e "${GREEN}✓ Keystore created successfully!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Copy the keystore path: $KEYSTORE_PATH"
echo "  2. Create android/key.properties with:"
echo ""
echo "     storeFile=$KEYSTORE_PATH"
echo "     keyAlias=$KEY_ALIAS"
echo "     storePassword=<your_password>"
echo "     keyPassword=<your_password>"
echo ""
echo -e "${RED}⚠ Don't forget to add key.properties to .gitignore (already done)${NC}"
echo ""
echo "Store your keystore in a safe place (backup, password manager, etc.)"
