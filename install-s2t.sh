#!/bin/bash
# install-s2t.sh - Installer script for Speech-to-Text Plasma addon

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"

echo "=== Installing Speech-to-Text Plasma Addon ==="

# Check if running as root for system install
if [ "$EUID" -eq 0 ]; then
    echo "Running as root - installing system-wide"
    SYSTEM_INSTALL=1
else
    echo "Running as user - installing locally"
    SYSTEM_INSTALL=0
fi

# Ensure universe repository is enabled (for Qt5 packages on some Ubuntu versions)
if command -v add-apt-repository >/dev/null 2>&1; then
    echo "Checking repositories..."
    sudo add-apt-repository -y universe 2>/dev/null || true
fi

# Install system dependencies
echo "Installing dependencies..."
if command -v apt >/dev/null 2>&1; then
    # Ubuntu/Debian
    sudo apt update
    
    # Try standard Qt5 packages first
    echo "Attempting to install Qt5 packages (standard names)..."
    if sudo apt-get install -y \
        cmake \
        extra-cmake-modules \
        qt5-base-dev qt5-declarative-dev \
        libkf5plasma-dev libkf5globalaccel-dev libkf5i18n-dev \
        libkf5kdelibs4support-dev \
        plasma-framework \
        plasma-workspace \
        alsa-utils sox ffmpeg \
        python3-tk \
        pipx wget unzip \
        kpackagetool5 2>&1 | tee /tmp/apt-install.log | grep -q "Unable to locate package"; then
        
        # Fallback: try with qtbase5-dev instead
        echo "Standard Qt5 packages not found, trying alternative names (qtbase5-dev, qtdeclarative5-dev)..."
        sudo apt install -y \
            cmake \
            extra-cmake-modules \
            qtbase5-dev qtdeclarative5-dev \
            libkf5plasma-dev libkf5globalaccel-dev libkf5i18n-dev \
            libkf5kdelibs4support-dev \
            plasma-framework \
            plasma-workspace \
            alsa-utils sox ffmpeg \
            python3-tk \
            pipx wget unzip \
            kpackagetool5
    fi
elif command -v dnf >/dev/null 2>&1; then
    # Fedora
    sudo dnf install -y \
        extra-cmake-modules \
        qt5-qtbase-devel qt5-qtdeclarative-devel \
        kf5-plasma-devel kf5-kglobalaccel-devel kf5-ki18n-devel \
        kf5-kdelibs4support-devel \
        plasma-framework \
        plasma-workspace \
        alsa-utils sox ffmpeg \
        python3-tk \
        pipx wget unzip \
        kpackage
else
    echo "Unsupported package manager. Please install dependencies manually."
    exit 1
fi

# Build project
echo "Building project..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
cmake ..
cmake --build .

# Install plasmoid
echo "Installing plasmoid..."
if [ "$SYSTEM_INSTALL" -eq 1 ]; then
    sudo cmake --install . --prefix /usr
    PLASMOID_DIR="/usr/share/plasma/plasmoids/s2t"
else
    cmake --install . --prefix ~/.local
    PLASMOID_DIR="$HOME/.local/share/plasma/plasmoids/s2t"
fi

# Alternative: use kpackagetool5
# kpackagetool5 --type Plasma/Applet --install "$PROJECT_DIR" --packageroot "$PLASMOID_DIR"

# Install helper script
echo "Installing helper script..."
HELPER_SCRIPT="/usr/local/bin/s2t-helper"
if [ "$SYSTEM_INSTALL" -eq 0 ]; then
    HELPER_SCRIPT="$HOME/.local/bin/s2t-helper"
    mkdir -p "$HOME/.local/bin"
fi

cp "$PROJECT_DIR/s2t-helper.sh" "$HELPER_SCRIPT"
chmod +x "$HELPER_SCRIPT"

# Setup Vosk STT engine
echo ""
echo "Setting up Vosk speech-to-text engine..."
MODEL_DIR="$HOME/.local/share/s2t"
MODEL_PATH="$MODEL_DIR/model"

# Install Vosk via pipx if not present
if ! command -v vosk-transcriber >/dev/null 2>&1; then
    echo "Installing Vosk transcriber via pipx..."
    pipx install vosk
else
    echo "Vosk transcriber already installed"
fi

# Download and setup Vosk model if not present
if [ ! -d "$MODEL_PATH" ]; then
    echo "Downloading Vosk English model (~40MB)..."
    mkdir -p "$MODEL_DIR"
    cd "$MODEL_DIR"
    wget -q --show-progress https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
    echo "Extracting model..."
    unzip -q vosk-model-small-en-us-0.15.zip
    mv vosk-model-small-en-us-0.15 model
    rm vosk-model-small-en-us-0.15.zip
    echo "✓ Vosk model downloaded to: $MODEL_PATH"
else
    echo "✓ Vosk model already exists at: $MODEL_PATH"
fi

# Create config
echo "Setting up configuration..."
mkdir -p ~/.config
cat > ~/.config/s2tconfig << EOF
[SpeechToText]
EngineCommand=$HELPER_SCRIPT
EOF

# Make scripts executable
chmod +x "$PROJECT_DIR/test-s2t.sh"

echo "Installation completed!"
echo ""
echo "✓ Build system: KDE Plasma + Qt5"
echo "✓ Speech engine: Vosk (offline, privacy-first)"
echo "✓ Microphone: ALSA audio capture"
echo "✓ Volume feedback: sox RMS measurement"
echo ""
echo "To test the STT pipeline:"
echo "  python3 s2t-tester.py"
echo ""
echo "To add widget to Plasma panel:"
echo "  Right-click panel -> Add Widgets -> SpeechToTextInputMethod"
echo ""
echo "Or enable in system tray:"
echo "  System Settings -> Startup and Shutdown -> LowLevel System Tray"
echo ""
echo "Installed locations:"
echo "  Plasmoid: $PLASMOID_DIR"
echo "  Helper script: $HELPER_SCRIPT"
echo "  Vosk model: $MODEL_PATH"
echo "  Config: ~/.config/s2tconfig"
