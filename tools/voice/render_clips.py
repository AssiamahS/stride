#!/usr/bin/env python3
"""Render every coach line in Coach/cues.json to an audio clip.

Engines:
  say          macOS built-in TTS (free, for testing the clip pipeline)
  elevenlabs   ElevenLabs instant voice clone. Needs ELEVENLABS_API_KEY and --voice-id.
  dir          Import already-rendered files (wav/mp3/m4a named <id>.*) from a folder.

Output goes to Coach/clips/<id>.m4a (bundled into the app on the next build) or, with --out,
anywhere else, e.g. a folder you AirDrop into the app's Documents/clips.

Examples:
  python3 tools/voice/render_clips.py --list
  python3 tools/voice/render_clips.py --engine say --voice Samantha
  ELEVENLABS_API_KEY=... python3 tools/voice/render_clips.py --engine elevenlabs --voice-id abc123
  python3 tools/voice/render_clips.py --engine dir --src ~/Desktop/my-takes
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CUES = ROOT / "Coach" / "cues.json"
DEFAULT_OUT = ROOT / "Coach" / "clips"


def lines():
    data = json.loads(CUES.read_text())
    for pool, items in data.items():
        for item in items:
            yield pool, item["id"], item["text"]


def to_m4a(src: Path, dst: Path):
    dst.parent.mkdir(parents=True, exist_ok=True)
    # afconvert ships with macOS; AAC in an .m4a plays everywhere AVAudioPlayer does.
    subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "96000", str(src), str(dst)], check=True)


def render_say(text, dst: Path, voice):
    with tempfile.TemporaryDirectory() as td:
        aiff = Path(td) / "take.aiff"
        cmd = ["say", "-o", str(aiff)]
        if voice:
            cmd += ["-v", voice]
        cmd.append(text)
        subprocess.run(cmd, check=True)
        to_m4a(aiff, dst)


def render_elevenlabs(text, dst: Path, voice_id, model):
    key = os.environ.get("ELEVENLABS_API_KEY")
    if not key:
        sys.exit("ELEVENLABS_API_KEY not set")
    body = json.dumps({"text": text, "model_id": model,
                       "voice_settings": {"stability": 0.45, "similarity_boost": 0.8, "style": 0.2}}).encode()
    req = urllib.request.Request(
        f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}?output_format=mp3_44100_128",
        data=body, headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
    with urllib.request.urlopen(req, timeout=120) as r, tempfile.TemporaryDirectory() as td:
        mp3 = Path(td) / "take.mp3"
        mp3.write_bytes(r.read())
        to_m4a(mp3, dst)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--engine", choices=["say", "elevenlabs", "dir"], default="say")
    ap.add_argument("--voice", help="say: macOS voice name (say -v '?')")
    ap.add_argument("--voice-id", help="elevenlabs: cloned voice id")
    ap.add_argument("--model", default="eleven_multilingual_v2")
    ap.add_argument("--src", help="dir: folder of <id>.wav|mp3|m4a takes")
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--only", nargs="*", help="render only these ids")
    ap.add_argument("--force", action="store_true", help="re-render existing clips")
    ap.add_argument("--list", action="store_true", help="print ids + text and exit")
    a = ap.parse_args()

    if a.list:
        for pool, lid, text in lines():
            print(f"{lid:12} [{pool}] {text}")
        return

    done = skipped = 0
    for pool, lid, text in lines():
        if a.only and lid not in a.only:
            continue
        dst = a.out / f"{lid}.m4a"
        if dst.exists() and not a.force:
            skipped += 1
            continue
        if a.engine == "say":
            render_say(text, dst, a.voice)
        elif a.engine == "elevenlabs":
            if not a.voice_id:
                sys.exit("--voice-id required")
            render_elevenlabs(text, dst, a.voice_id, a.model)
        else:
            src_dir = Path(a.src or ".").expanduser()
            take = next((p for p in src_dir.glob(f"{lid}.*") if p.suffix.lower() in (".wav", ".mp3", ".m4a", ".aiff", ".aif")), None)
            if not take:
                print(f"missing take for {lid}", file=sys.stderr)
                continue
            if take.suffix.lower() == ".m4a":
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(take, dst)
            else:
                to_m4a(take, dst)
        done += 1
        print(f"✓ {lid}")
    print(f"{done} rendered, {skipped} already present → {a.out}")


if __name__ == "__main__":
    main()
