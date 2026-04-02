#!/usr/bin/env python3
"""Standalone Speech-to-Text tester GUI for the Plasma addon."""

import os
import subprocess
import threading
import time
import math
import tkinter as tk
from tkinter import ttk, messagebox

CONFIG_PATH = os.path.expanduser("~/.config/s2tconfig")
TEMP_AUDIO = "/tmp/s2t_tester.wav"
DURATION = 5


def load_command():
    if not os.path.exists(CONFIG_PATH):
        return None

    import configparser
    cfg = configparser.ConfigParser()
    cfg.read(CONFIG_PATH)
    return cfg.get("SpeechToText", "EngineCommand", fallback=None)


def check_engine_ready():
    """Verify STT engine components are available."""
    cmd = load_command()
    if not cmd:
        return False, "No EngineCommand configured"
    
    # Get the executable path (first word of command)
    exe = cmd.split()[0] if cmd else None
    if not exe:
        return False, "Invalid EngineCommand"
    
    # Check if helper script or command exists
    if exe.startswith("/"):
        if not os.path.exists(exe):
            return False, f"Not found: {exe}"
    else:
        # Check if it's in PATH
        result = subprocess.run(["which", exe], capture_output=True)
        if result.returncode != 0:
            return False, f"Not in PATH: {exe}"
    
    # Check for required tools
    for tool in ["arecord", "sox"]:
        result = subprocess.run(["which", tool], capture_output=True)
        if result.returncode != 0:
            return False, f"Missing tool: {tool}"
    
    # Check for vosk model directory
    model_path = os.path.expanduser("~/.local/share/s2t/model")
    if not os.path.isdir(model_path):
        return False, f"Vosk model not found: {model_path}"
    
    return True, "All components ready"


def on_check_engine():
    """Check engine status on demand."""
    ready, msg = check_engine_ready()
    if ready:
        engine_status.config(text=f"✓ {msg}", foreground="green")
        btn_record.config(state=tk.NORMAL)
        status_var.set("Ready to record")
    else:
        engine_status.config(text=f"✗ {msg}", foreground="red")
        btn_record.config(state=tk.DISABLED)
        status_var.set("Engine not ready")


def on_record():
    """Start recording immediately without delay."""
    cmd = load_command()
    if not cmd:
        messagebox.showwarning("STT Tester", f"No EngineCommand in {CONFIG_PATH}")
        return

    result_var.set("")
    btn_record.config(state=tk.DISABLED)
    btn_check.config(state=tk.DISABLED)

    def worker():
        if os.path.exists(TEMP_AUDIO):
            os.remove(TEMP_AUDIO)

        # IMMEDIATELY start recording (no delay, no countdown)
        arecord_cmd = ["arecord", "-f", "S16_LE", "-r", "16000", "-c", "1", "-d", str(DURATION), TEMP_AUDIO]

        try:
            rec = subprocess.Popen(arecord_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except FileNotFoundError:
            status_var.set("Error")
            result_var.set("arecord not installed")
            btn_record.config(state=tk.NORMAL)
            btn_check.config(state=tk.NORMAL)
            return

        # Show recording progress with countdown
        start_time = time.time()
        while rec.poll() is None:
            elapsed = time.time() - start_time
            remaining = max(0.0, DURATION - elapsed)
            
            # Force stop if we've exceeded duration (safety net for clock drift)
            if elapsed >= DURATION + 0.5:
                rec.terminate()
                rec.wait(timeout=1)
                break
            
            try:
                proc = subprocess.run(["sox", TEMP_AUDIO, "-n", "stat", "-v"], capture_output=True, text=True, timeout=2)
                rms = float(proc.stderr.strip()) if proc.returncode == 0 else 0.0
                level = min(100, max(0, int(abs(20.0 * math.log10(max(rms, 1e-9))))))
            except Exception:
                level = 0
            
            # Show countdown with decimal precision - helps sync visually with actual audio stop
            status_var.set(f"🎙️ RECORDING ({remaining:.1f}s remaining)")
            progress_var.set(min(100, int(100 * elapsed / DURATION)))
            time.sleep(0.05)  # Update more frequently for smoother display

        rec.wait()
        recording_elapsed = time.time() - start_time
        progress_var.set(100)
        
        # Verify audio was actually recorded
        if not os.path.exists(TEMP_AUDIO) or os.path.getsize(TEMP_AUDIO) == 0:
            status_var.set("Error")
            result_var.set("Recording failed: no audio file created")
            btn_record.config(state=tk.NORMAL)
            btn_check.config(state=tk.NORMAL)
            return
        
        audio_size_kb = os.path.getsize(TEMP_AUDIO) / 1024
        elapsed_total = time.time() - start_time
        
        # Begin transcription with timeout tracking
        # Vosk should transcribe 5s of audio in 10-30 seconds typically
        transcribe_timeout = 60
        transcribe_start = time.time()
        status_var.set(f"Transcribing {recording_elapsed:.1f}s of audio... ({transcribe_timeout}s timeout)")
        time.sleep(0.3)

        # prepare engine command
        engine_cmd = cmd
        engine_cmd = engine_cmd.replace("{input}", TEMP_AUDIO)
        if "{input}" not in cmd and "--input" not in cmd:
            engine_cmd = f"{cmd} --input {TEMP_AUDIO}"

        try:
            proc = subprocess.Popen(engine_cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            
            # Monitor transcription progress with timeout display
            while proc.poll() is None:
                elapsed = time.time() - transcribe_start
                remaining_timeout = max(0, transcribe_timeout - elapsed)
                status_var.set(f"Transcribing... ({remaining_timeout:.0f}s timeout)")
                time.sleep(0.2)
                
                if elapsed > transcribe_timeout:
                    proc.terminate()
                    proc.wait(timeout=2)
                    raise subprocess.TimeoutExpired(engine_cmd, transcribe_timeout)
            
            stdout, stderr = proc.communicate()
            
            if proc.returncode != 0:
                status_var.set("Error")
                result_var.set(f"Transcription failed:\n{stderr.strip()}")
            else:
                status_var.set("✓ Done")
                result_var.set(stdout.strip() or "(empty transcription)")
        except subprocess.TimeoutExpired:
            status_var.set("Error")
            result_var.set("Transcription timeout (60s) - check Vosk model")
        except Exception as e:
            status_var.set("Error")
            result_var.set(str(e))
        finally:
            progress_var.set(0)
            btn_record.config(state=tk.NORMAL)
            btn_check.config(state=tk.NORMAL)

    threading.Thread(target=worker, daemon=True).start()


root = tk.Tk()
root.title("Speech-to-Text Tester")
root.geometry("600x280")

frame = ttk.Frame(root, padding=10)
frame.pack(fill=tk.BOTH, expand=True)

command_var = tk.StringVar()
status_var = tk.StringVar(value="Click 'Check Engine' to start")
result_var = tk.StringVar(value="(no result yet)")
progress_var = tk.IntVar(value=0)

# Engine status section
engine_frame = ttk.LabelFrame(frame, text="Engine Status", padding=8)
engine_frame.pack(fill=tk.X, pady=(0, 10))

engine_status = ttk.Label(engine_frame, text="⚠ Not checked", foreground="gray")
engine_status.pack(anchor=tk.W)

btn_check = ttk.Button(engine_frame, text="Check Engine", command=on_check_engine)
btn_check.pack(side=tk.LEFT, padx=4)

# Command display
ttk.Label(frame, text="EngineCommand:").pack(anchor=tk.W)
cmd_entry = ttk.Entry(frame, textvariable=command_var, width=100)
cmd_entry.pack(fill=tk.X)

# Status display
ttk.Label(frame, text="Status:").pack(anchor=tk.W, pady=(10, 0))
status_label = ttk.Label(frame, textvariable=status_var, font=(None, 10, "bold"))
status_label.pack(anchor=tk.W)

# Record button
btn_frame = ttk.Frame(frame)
btn_frame.pack(fill=tk.X, pady=8)
btn_record = ttk.Button(btn_frame, text="🎙️ Start Recording", command=on_record, state=tk.DISABLED)
btn_record.pack(side=tk.LEFT, padx=4)

# Progress bar
ttk.Label(frame, text="Volume/Activity:").pack(anchor=tk.W, pady=(10, 0))
progress = ttk.Progressbar(frame, variable=progress_var, maximum=100)
progress.pack(fill=tk.X)

# Result display
ttk.Label(frame, text="Transcription result:").pack(anchor=tk.W, pady=(8, 0))
result_box = tk.Text(frame, height=6, wrap=tk.WORD)
result_box.pack(fill=tk.BOTH, expand=True)


def update_result():
    result_box.delete("1.0", tk.END)
    result_box.insert(tk.END, result_var.get())
    root.after(200, update_result)


# Load command on startup
def on_load():
    cmd = load_command()
    command_var.set(cmd or "<not configured>")


on_load()
root.after(200, update_result)
root.mainloop()
