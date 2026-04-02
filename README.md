# Plasma Speech-to-Text Input Method Add-on (s2t)

This workspace contains a KDE Plasma applet skeleton that can display a speech-to-text bubble next to standard on-screen keyboard input methods, and can be activated by a CoPilot-like keyboard key or a global shortcut.

## Features

- **Input Method Integration**: Shows speech-to-text bubble when on-screen keyboard is active
- **Focus Detection**: Bubble appears when text input fields are focused
- **CoPilot Keyboard Support**: Automatically detects keyboards with "copilot" or "ai" in name
- **Global Shortcut**: Meta+P to trigger speech-to-text from anywhere
- **Configurable STT Engine**: Uses external command for transcription
- **Qt5/Qt6 Compatible**: Works on Ubuntu 24.04 and other distributions
- **Automated Scripts**: Installer and test scripts for easy setup

## Project layout
- `CMakeLists.txt` - build config
- `metadata.json` - plasma plugin metadata
- `contents/ui/main.qml` - widget UI
- `s2t.cpp` - main plugin implementation

## Build dependencies
Install KDE development dependencies before building (Ubuntu 24.04):

```bash
# Enable universe repository first (required on some systems)
sudo add-apt-repository -y universe
sudo apt update

# Install all required packages (including GUI tester dependencies)
sudo apt install -y cmake extra-cmake-modules \
  libkf5plasma-dev libkf5globalaccel-dev libkf5i18n-dev \
  alsa-utils sox ffmpeg python3-tk

# For Qt5: try one of these depending on your system
# Option 1 (most common):
sudo apt install -y qt5-base-dev qt5-declarative-dev

# Option 2 (if Option 1 fails):
# sudo apt install -y qtbase5-dev qtdeclarative5-dev
```

## Quick Install and Test

### Automated Installation

Run the installer script:

```bash
./install-s2t.sh
```

This will:
- Install system dependencies (Qt5, KF5, ALSA, sox, ffmpeg, pipx)
- Build the project
- Install the plasmoid
- Set up the helper script
- **Install Vosk via pipx** (offline speech recognition)
- **Download the Vosk English model** (~40MB)
- Configure the system

### Manual Installation

1. Install dependencies (Ubuntu 24.04):
   ```bash
   # First enable universe repository (needed on some Ubuntu installations)
   sudo add-apt-repository universe
   sudo apt update
   
   # Install dependencies (try standard names first)
   sudo apt install cmake extra-cmake-modules qt5-base-dev qt5-declarative-dev \
     libkf5plasma-dev libkf5globalaccel-dev libkf5i18n-dev plasma-framework plasma-workspace \
     alsa-utils sox ffmpeg python3-tk pipx wget unzip
   
   # If qt5-base-dev is not found, try alternative names:
   # sudo apt install cmake extra-cmake-modules qtbase5-dev qtdeclarative5-dev \
   #   libkf5plasma-dev libkf5globalaccel-dev libkf5i18n-dev alsa-utils sox ffmpeg \
   #   python3-tk pipx wget unzip
   ```

2. Build:
   ```bash
   mkdir -p build && cd build
   cmake ..
   cmake --build .
   ```

3. Install plasmoid:
   ```bash
   sudo cmake --install . --prefix /usr
   # or for local install: cmake --install . --prefix ~/.local
   ```

4. Install Vosk STT engine:
   ```bash
   # Install Vosk transcriber
   pipx install vosk
   
   # Download Vosk English model (~40MB)
   mkdir -p ~/.local/share/s2t
   cd ~/.local/share/s2t
   wget https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
   unzip vosk-model-small-en-us-0.15.zip
   mv vosk-model-small-en-us-0.15 model
   rm vosk-model-small-en-us-0.15.zip
   ```

5. Set up config:
   ```bash
   mkdir -p ~/.config
   echo "[SpeechToText]
EngineCommand=$HOME/.local/bin/s2t-helper" > ~/.config/s2tconfig
   ```

## Testing

### Recommended: Use the Standalone Tester GUI

The `s2t-tester.py` script provides a clean, interactive way to test the full STT pipeline without complexity:

```bash
python3 s2t-tester.py
```

**Workflow:**
1. Click **"Check Engine"** → verifies Vosk, arecord, sox are installed and ready
2. Click **"🎙️ Start Recording"** → records 5 seconds of audio with countdown timer
3. **Speak during the countdown** (when you see "🎙️ RECORDING (4.9s remaining)")
4. Watch **live volume feedback** as the progress bar animates
5. See **transcription results** appear in the output box with timeout countdown

**Features:**
- Visual countdown timer (precise to 0.1 seconds)
- Live microphone volume display
- Engine readiness check before recording
- Timeout display during transcription (60s limit)
- Exact duration of captured audio shown

### Alternative: Test via Plasma Applet Preview / System Tray Widget

To test the applet in Plasma:

```bash
./test-s2t.sh
```

This launches `plasmoidviewer` which demonstrates the applet. It now supports both:
- System tray/panel icon mode (use this on a Panel or Taskbar)
- Popup mode (small bubble with volume bar and status indicator)

Features:
- Microphone icon
toggles when recording
- Live volume bar
- Countdown display (3, 2, 1 before recording)
- Meta+S global shortcut

### Setup Vosk Engine (Required for STT)

Run the setup script to download the Vosk English model (~40MB):

```bash
./vosk-integration.sh
```

This will:
- Install vosk via pipx (if not already installed)
- Download ~40MB English model to `~/.local/share/s2t/model`
- Configure the helper script to use vosk-transcriber

After this, the `~/.config/s2tconfig` file will point to `s2t-helper.sh`, which automatically handles audio capture + Vosk transcription.
- Build if needed
- Configure the helper script
- Launch plasmoidviewer for testing

## Files

- `s2t.cpp` - Main Plasma applet implementation
- `CMakeLists.txt` - Build configuration
- `metadata.json` - Plasma plugin metadata
- `contents/ui/main.qml` - QML UI for the bubble
- `s2t-helper.sh` - Audio recording and transcription helper
- `test-s2t.sh` - Test script
- `install-s2t.sh` - Installation script

## STT Engine Integration

The addon supports offline STT engines. The recommended lightweight solution is **Vosk**, which provides excellent dictation quality comparable to Google/Android while being completely free and offline.

### Vosk Integration

Vosk is the best choice for your requirements:
- **Completely offline** - No internet required
- **Free and open source**
- **Lightweight** - Small models (~40MB for English)
- **High quality** - Good dictation accuracy
- **Embeddable** - Can be included as a library
- **Cross-platform** - Works on Linux, Windows, macOS

#### Installing Vosk

Use the automated setup script:

```bash
./vosk-integration.sh
```

This script will:
- Install `vosk` via pipx (handles Ubuntu 24.04 pip restrictions)
- Download the ~40MB English model
- Extract to `~/.local/share/s2t/model`
- Create `vosk-transcriber` wrapper script

The `~/.config/s2tconfig` file will automatically be configured to use the helper script.

### Alternative Offline Engines

- **Whisper.cpp**: Fast C++ implementation of OpenAI Whisper
  - Excellent quality but larger models (39MB+)
  - `whisper-cpp -m model.bin -f audio.wav`

- **Kaldi**: Very high quality but more complex setup
  - Industry-standard speech recognition
  - Requires more configuration

### Quality Comparison

| Engine | Quality | Size | Setup Complexity | Offline |
|--------|---------|------|------------------|---------|
| Vosk | Excellent | ~40MB | Low | ✅ |
| Whisper.cpp | Excellent | 39MB-1.5GB | Medium | ✅ |
| Kaldi | Excellent | Varies | High | ✅ |
| Google/Android | Excellent | N/A | None | ❌ |

## Architecture

### Helper Script Flow

The `s2t-helper.sh` script handles the full audio capture + transcription pipeline:

1. **Audio Capture**: Uses `arecord` to record 5 seconds at 16kHz mono
2. **Volume Measurement**: Runs `sox stat -v` to compute RMS level for UI feedback
3. **Transcription**: Passes audio to `vosk-transcriber` (or custom EngineCommand)
4. **Output**: Returns transcribed text to stdout, RMS level to stderr

### Applet Integration

The Plasma applet (`s2t.cpp`) provides:
- **3-second visual countdown** before recording starts
- **Live volume bar** animated during capture
- **Global Meta+S shortcut** for activation from anywhere
- **Input method detection** - shows bubble when on-screen keyboard is active
- **Focus detection** - only commits text to focused input fields
- **CoPilot keyboard detection** - enhanced activation for special keyboards

### Configuration

Edit `~/.config/s2tconfig` to customize behavior:

```ini
[SpeechToText]
EngineCommand=/path/to/s2t-helper.sh
```

You can point `EngineCommand` to:
- `s2t-helper.sh` (recommended - handles capture + Vosk)
- `vosk-transcriber` directly (requires manual audio)
- Any custom script that reads WAV from stdin and outputs text

## Future Enhancements

- [ ] Press-to-talk UI with visual hold-to-record feedback
- [ ] Alternative STT engines (Whisper.cpp, Kaldi) configuration GUI
- [ ] KDE config UI (KConfigXT) for user preferences
- [ ] Support for continuous listening mode
- [ ] Custom voice commands and dictation macros
- [ ] Multilingual model support
