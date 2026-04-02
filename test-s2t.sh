#!/bin/bash
# test-s2t.sh - Test script for Speech-to-Text Plasma addon

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"

echo "=== Testing Speech-to-Text Plasma Addon ==="

# Build if needed
if [ ! -f "$BUILD_DIR/libs2t.so" ]; then
    echo "Building project..."
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    cmake ..
    cmake --build .
    cd "$PROJECT_DIR"
fi

# Create config file
echo "Setting up config..."
mkdir -p ~/.config
cat > ~/.config/s2tconfig << EOF
[SpeechToText]
EngineCommand=$PROJECT_DIR/s2t-helper.sh
EOF

# Make helper executable
chmod +x "$PROJECT_DIR/s2t-helper.sh"

# Test plasmoidviewer
echo "Launching plasmoidviewer..."
echo "Instructions:"
echo "1. Click the microphone button or press Meta+S"
echo "2. Check that text is inserted into focused input fields"
echo "3. Close plasmoidviewer when done"
echo ""

plasmoidviewer --applet "$PROJECT_DIR" --formfactor horizontal --location floating

echo "Test completed."
