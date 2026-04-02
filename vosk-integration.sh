#!/bin/bash
# Vosk STT Integration Setup Script

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_DIR="$HOME/.local/share/s2t"
MODEL_PATH="$MODEL_DIR/model"

echo "=== Setting up Vosk STT Integration ==="

# Check if Vosk is installed
if ! command -v vosk-transcriber >/dev/null 2>&1; then
    echo "Vosk not found. Installing via pipx..."
    pipx install vosk
fi

echo "Vosk is available: $(vosk-transcriber --help | head -1)"

# Create model directory
mkdir -p "$MODEL_DIR"

# Download Vosk model if not exists
if [ ! -d "$MODEL_PATH" ]; then
    echo "Downloading Vosk English model (~40MB)..."
    cd "$MODEL_DIR"
    wget -q --show-progress https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
    unzip vosk-model-small-en-us-0.15.zip
    mv vosk-model-small-en-us-0.15 model
    rm vosk-model-small-en-us-0.15.zip
    echo "Model downloaded to: $MODEL_PATH"
else
    echo "Vosk model already exists at: $MODEL_PATH"
fi

# Create Python transcription script
cat > "$PROJECT_DIR/vosk-transcribe.py" << 'EOF'
#!/usr/bin/env python3
import sys
import json
import os
from vosk import Model, KaldiRecognizer

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 vosk-transcribe.py <audio_file.wav>", file=sys.stderr)
        sys.exit(1)

    audio_file = sys.argv[1]

    # Find model path
    model_paths = [
        os.path.join(os.path.dirname(__file__), "model"),  # Local model
        os.path.expanduser("~/.local/share/s2t/model"),    # User model
        "/usr/share/s2t/model",                            # System model
    ]

    model_path = None
    for path in model_paths:
        if os.path.exists(path):
            model_path = path
            break

    if not model_path:
        print("Error: Vosk model not found. Run ./vosk-integration.sh first", file=sys.stderr)
        sys.exit(1)

    # Load model
    model = Model(model_path)
    rec = KaldiRecognizer(model, 16000)

    # Process audio file
    try:
        with open(audio_file, "rb") as f:
            data = f.read()

        if rec.AcceptWaveform(data):
            result = json.loads(rec.Result())
            text = result.get("text", "").strip()
            if text:
                print(text)
            else:
                print("No speech detected")
        else:
            # Partial result
            partial = json.loads(rec.PartialResult())
            text = partial.get("partial", "").strip()
            if text:
                print(text)
            else:
                print("No speech detected")

    except Exception as e:
        print(f"Error processing audio: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

chmod +x "$PROJECT_DIR/vosk-transcribe.py"

echo "Vosk integration setup complete!"
echo ""
echo "Python script: $PROJECT_DIR/vosk-transcribe.py"
echo "Model location: $MODEL_PATH"
echo ""
echo "To use with the addon, update ~/.config/s2tconfig:"
echo "[SpeechToText]"
echo "EngineCommand=$PROJECT_DIR/vosk-transcribe.py"