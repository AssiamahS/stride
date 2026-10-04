# Stride

Guided running for people who aren't runners yet. Think Nike Run Club's guided runs, but the plan
starts wherever you honestly are, and the coach in your ears can be **you**.

## What it does

- **Road to 5K**: a ten-week walk/run progression (Week 0 → Week 9, three runs a week) ending at a
  continuous 30-minute run. A one-question check at first launch picks your starting week, so nobody
  is forced through Week 1 if they can already run ten minutes.
- **Guided library**: First Run (10 min), Easy 15, Comeback Run, 5K Day.
- **A coach that talks**: every segment change, halfway marks, the last 30 seconds of each run,
  pep talks on a cadence you choose, and a final-minute push. Plus the facts: "Run 3 of 8. Ninety seconds."
- **Your voice**: lines are spoken with your Apple Personal Voice (on-device clone, free), or with
  clips you recorded/cloned (`Coach/clips/<id>.m4a`), or a system voice as fallback.
- GPS distance + pace, Health workout export, music ducking, works in the background.

## Layout

```
project.yml              XcodeGen source of truth (iOS 26, com.assiamah.stride)
Stride/
  Models/Plan.swift      segments, workouts, the 10-week plan, the guided library, readiness → week
  Models/CoachScript.swift  cue pools + no-repeat picker
  Engine/RunEngine.swift wall-clock run state machine; fires cues; survives backgrounding
  Engine/CoachVoice.swift   clip → Personal Voice → system voice; AVAudioSession ducking
  Engine/LocationTracker.swift  GPS distance with accuracy filtering
  Engine/WorkoutSaver.swift     HealthKit running workout
  Store/ProgressStore.swift     completed runs + plan position (JSON in Application Support)
  Views/                 Onboarding, Home, Plan, Run, Summary, Coach settings
Coach/cues.json          the script: 41 lines, ids double as clip filenames
Coach/clips/             optional recorded clips (git-ignored)
tools/voice/             recording script + render_clips.py (say / ElevenLabs / import folder)
web/                     landing + ad hoc install page (GitHub Pages)
```

## Build

No local Xcode needed; CI compiles on `macos-26`. Locally: `xcodegen generate && open Stride.xcodeproj`.

Push to `main` → unsigned compile check → TestFlight upload + ad hoc IPA → install page at
https://assiamahs.github.io/stride/install.html

## Your voice in three steps

1. iPhone Settings → Accessibility → Personal Voice → create one (15 min of reading, finishes overnight).
2. Turn on "Allow Apps to Request to Use".
3. Stride → Coach tab → "Use my Personal Voice".

Want studio quality instead? Record the lines in `tools/voice/recording_script.md`, or clone your
voice with any TTS, then `python3 tools/voice/render_clips.py --engine dir --src <takes>` and
AirDrop the folder to the app's Documents › clips, or commit them to `Coach/clips/` in a private fork.
