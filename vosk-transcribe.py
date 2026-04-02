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
