# Recording script

Two ways to put your own voice in Stride. Do **A** first; it costs nothing and runs on the phone.

## A. Apple Personal Voice (on-device, free)

1. iPhone → Settings → Accessibility → Personal Voice → Create a Personal Voice.
2. Read the ~150 prompts in a quiet room (about 15 minutes). iOS finishes the voice overnight while the phone charges.
3. In the same screen turn on **Allow Apps to Request to Use**.
4. Open Stride → Coach tab → **Use my Personal Voice** → Allow.

Every coach line is now synthesized in your voice, including the dynamic ones ("Run 3 of 8, two minutes").

## B. Recorded / cloned clips (any TTS, any quality)

Clips override synthesis line-by-line. Record them yourself, or clone your voice with a service and
render the script with `render_clips.py`. File name = line id from `Coach/cues.json`, e.g. `run-01.m4a`.

Read each line like you are talking to one friend who is out of breath. Warm, low, unhurried.
Leave half a second of silence before and after.

Pull the current list with:

```sh
python3 tools/voice/render_clips.py --list
```

### Sample for a voice clone

Most clone services want 1–3 minutes of clean speech. Read this, naturally, in one take:

> Hey. Glad you showed up. That was the hard part. Let's go.
> We're walking first. Shoulders loose, breathe easy. Let the body wake up.
> Here we go. Pick it up to a jog. Slow is fine. Slow is the plan.
> Find a pace where you could still talk to me. That's the one.
> And walk. Breathe. You earned this one.
> Halfway through this one. Same pace. Nothing extra.
> Thirty seconds. This is the part that makes you a runner.
> Every run is a success, because every run has a purpose. Today's purpose is to finish.
> If it's hard, slow down. Slowing down is not quitting.
> Most people are on the couch right now. You're not. Remember that.
> The first ten minutes always lie to you. Keep going. It gets easier.
> Last minute of the whole thing. Finish the way you want to remember it.
> Done. That's it. You said you'd run today, and you ran. See you next time.
> One, two, three, four, five, six, seven, eight, nine, ten.
> Thirty seconds. One minute. Ninety seconds. Two minutes. Three minutes. Five minutes. Eight minutes. Ten minutes.
> Run one of eight. Run two of eight. Run three of eight. Run four of eight.
