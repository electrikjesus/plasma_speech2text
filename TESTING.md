# Testing & Deployment Guide

## Quick Start (5 minutes)

### 1. Install System Dependencies
```bash
sudo apt install -y \
  extra-cmake-modules qt5-base-dev qt5-declarative-dev \
  libkf5plasma-dev libkf5globalaccel-dev libkf5i18n-dev \
  alsa-utils sox ffmpeg kpackagetool5
```

### 2. Setup Vosk (Offline STT Engine)
```bash
./vosk-integration.sh
```
Downloads the 40MB English Vosk model and sets up transcriber.

### 3. Test Audio Pipeline
```bash
python3 s2t-tester.py
```
**Steps:**
1. Click "Check Engine" → see ✓ All components ready
2. Click "🎙️ Start Recording"
3. Speak for 5 seconds (watch countdown)
4. See live volume feedback during recording
5. Read transcription results (60s timeout shown)

### 4. Build & Install Plasma Addon
```bash
./install-s2t.sh
```
Or manually:
```bash
mkdir build && cd build && cmake .. && make
sudo cmake --install . --prefix /usr
```

## Verification Steps

### Audio Capture Works
```bash
arecord -f S16_LE -r 16000 -c 1 -d 5 /tmp/test.wav
```
Should create a 5-second WAV file (~160KB).

### Volume Measurement Works
```bash
sox /tmp/test.wav -n stat -v
```
Should output something like: `0.123456`

### Vosk Transcription Works
```bash
whereis vosk-transcriber
~/.local/share/s2t/model  # should exist (40MB directory)
vosk-transcriber --model ~/.local/share/s2t/model --input /tmp/test.wav
```
Should output transcribed text.

### Helper Script Works End-to-End
```bash
./s2t-helper.sh
```
Records 5 seconds, outputs transcript to stdout, RMS to stderr.

### Applet Compilation Works
```bash
cd build && cmake .. && make
```
Should produce `build/libs2t.so` without errors.

## Visual Test Paths

### Test 1: Standalone GUI (Simplest)
```bash
python3 s2t-tester.py
```
✅ **Status**: Fully working - records, measures, transcribes
- Pros: No Plasma complexity, clear visual feedback
- Use for: Development and quick validation

### Test 2: Plasma Applet Preview
```bash
./test-s2t.sh
```
⚠️ **Status**: Builds and runs but plasmoidviewer rendering varies by desktop
- Pros: Tests actual Plasma applet code
- Use for: Integration verification

### Test 3: Full Plasma Desktop Integration
- Add applet to panel via right-click menu
- Trigger with Meta+S global shortcut
- Watch text insertion into focused fields
- ❌ **Status**: Requires full Plasma session (not available in testing environment)

## Troubleshooting

### "sox is required"
```bash
sudo apt install sox
```

### "ffmpeg is required"
```bash
sudo apt install ffmpeg
```

### Vosk model not found
```bash
./vosk-integration.sh   # Re-run setup
# Or manually:
mkdir -p ~/.local/share/s2t/model
# Download from: https://alphacephei.com/vosk/models/
```

### "No audio file created"
- Check microphone is unmuted: `alsamixer`
- Test microphone: `arecord -vvv /tmp/mic-test.wav` (speak loudly)
- Check ALSA device: `arecord -l`

### Transcription times out (60s)
- Vosk taking too long? Model may be loading slowly on first run
- Check CPU usage during transcription: `top -p $(pidof vosk-transcriber)`
- Increase timeout in `s2t-tester.py` if needed

### Plasma applet not showing
- Verify build completed: `ls build/libs2t.so`
- Restart Plasma: `kquitapp5 plasmashell && plasmashell &`
- Check install: `kpackagetool5 --list | grep s2t`

## Configuration

### Custom STT Engine

Edit `~/.config/s2tconfig`:

```ini
[SpeechToText]
EngineCommand=/path/to/custom-transcriber.py
```

Your command must:
- Accept `--input /path/to/file.wav` argument
- Output transcribed text to stdout
- Return exit code 0 on success

### Duration

Edit `s2t-tester.py` or `s2t-helper.sh`:
```bash
DURATION=10  # Record for 10 seconds instead of 5
```

### Volume Meter

The live volume meter in `s2t-tester.py` uses sox RMS calculation. To adjust sensitivity, edit the dB conversion formula in `on_record()` function.

## Performance Targets

| Component | Typical Time |
|-----------|-------------|
| Check Engine | <1 second |
| Audio Capture (5s) | ~5.1 seconds |
| Vosk Transcription | 10-30 seconds |
| Full cycle | ~20-35 seconds |

First Vosk run on a system may be slower (model initialization).

## Files Used in Testing

- `s2t-tester.py` - GUI test harness (primary)
- `s2t-helper.sh` - Audio + transcription pipeline
- `s2t.cpp` - Plasma applet source
- `build/libs2t.so` - Compiled applet plugin
- `~/.config/s2tconfig` - Runtime configuration
- `~/.local/share/s2t/model/` - Vosk model (~40MB)
