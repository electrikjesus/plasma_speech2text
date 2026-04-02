#!/usr/bin/env bash
# s2t-helper.sh - real microphone capture + Vosk transcription helper script
# Requires: arecord, sox, Vosk model (or custom EngineCommand)

set -euo pipefail

# Config
DURATION=${STT_DURATION:-5}
SAMPLE_RATE=16000
CHANNELS=1
FORMAT=S16_LE
MODEL_PATH=${VOSK_MODEL:-"$HOME/.local/share/s2t/model"}
TEMP_WAV="/tmp/s2t_record_$$.wav"

# optional override command from environment variable:
ENGINE_COMMAND=${ENGINE_COMMAND:-""}

cleanup() {
    rm -f "$TEMP_WAV"
}
trap cleanup EXIT

# prerequisites
for cmd in arecord sox ffmpeg; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: $cmd is required. Install it." >&2
        exit 1
    fi
done

if [ ! -d "$MODEL_PATH" ]; then
    echo "Error: Vosk model directory not found: $MODEL_PATH" >&2
    echo "Download model: https://alphacephei.com/vosk/models/" >&2
    exit 1
fi

# capture voice
echo "Recording $DURATION seconds..." >&2
arecord -f "$FORMAT" -r "$SAMPLE_RATE" -c "$CHANNELS" -d "$DURATION" "$TEMP_WAV" 2>/dev/null

if [ ! -s "$TEMP_WAV" ]; then
    echo "Error: recorded file is empty" >&2
    exit 1
fi

# compute RMS for display
RMS=$(sox "$TEMP_WAV" -n stat -v 2>&1 || echo 0)
echo "RMS=$RMS" >&2

# choose command
if [ -n "$ENGINE_COMMAND" ]; then
    CMD="$ENGINE_COMMAND"
else
    CMD="vosk-transcriber --model '$MODEL_PATH' --input '$TEMP_WAV'"
fi

# if command template includes {input}, expand it
if [[ "$CMD" == *"{input}"* ]]; then
    CMD=${CMD//\{input\}/"$TEMP_WAV"}
fi

# if no --input and no placeholder, append input path
if [[ "$CMD" != *"--input"* && "$CMD" != *"{input}"* ]]; then
    CMD="$CMD --input '$TEMP_WAV'"
fi

# execute and emit transcription text
set +e
eval $CMD
RC=$?
set -e

if [ $RC -ne 0 ]; then
    echo "Error: STT command failed (exit $RC)" >&2
    exit $RC
fi

