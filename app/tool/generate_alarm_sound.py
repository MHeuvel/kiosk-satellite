"""Generates assets/sounds/alarm.ogg, the built-in alarm tone.

Made here rather than taken from anywhere, so the app ships no sound with a
license of its own. Two rising marimba-like arpeggios, then a rest, sized
to loop: the alarm player repeats the file until Stop, Snooze or Silence
after. Standard library only; ffmpeg does the Vorbis encode.

    python3 tool/generate_alarm_sound.py
"""

import array
import math
import os
import subprocess
import tempfile
import wave

RATE = 44100
LOOP = 2.6  # seconds, the whole file

# C major, low to high, twice; the second pass ends a step higher so the
# phrase lifts instead of stopping.
PHRASE = [523.25, 659.25, 783.99, 1046.50]
ANSWER = [523.25, 659.25, 783.99, 1174.66]
STEP = 0.15
SECOND = 0.78


def note(freq: float, start: float, out: list, gain: float = 1.0) -> None:
    """A struck bar: a fundamental that rings, a fourth partial that
    brightens the attack and dies fast, and a soft click of a tenth."""
    partials = [(1.0, 1.0, 0.42), (3.93, 0.28, 0.10), (9.8, 0.06, 0.025)]
    attack = 0.004
    begin = int(start * RATE)
    length = int(1.1 * RATE)
    for n in range(length):
        i = begin + n
        if i >= len(out):
            break
        t = n / RATE
        env_a = min(1.0, t / attack)
        v = 0.0
        for ratio, amp, tau in partials:
            v += amp * math.exp(-t / tau) * math.sin(2 * math.pi * freq * ratio * t)
        out[i] += gain * env_a * v


def main() -> None:
    samples = [0.0] * int(LOOP * RATE)
    for k, f in enumerate(PHRASE):
        note(f, 0.02 + k * STEP, samples, 0.85 + 0.05 * k)
    for k, f in enumerate(ANSWER):
        note(f, SECOND + k * STEP, samples, 0.9 + 0.05 * k)
    # A quiet tail before the loop point, so the repeat starts clean.
    fade = int(0.05 * RATE)
    for n in range(fade):
        samples[-1 - n] *= n / fade
    peak = max(abs(s) for s in samples) or 1.0
    scale = 0.7 * 32767 / peak  # about -3 dBFS
    pcm = array.array('h', (int(max(-32767, min(32767, s * scale))) for s in samples))

    here = os.path.dirname(os.path.abspath(__file__))
    target = os.path.join(here, '..', 'assets', 'sounds', 'alarm.ogg')
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, 'alarm.wav')
        with wave.open(wav, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        subprocess.run(
            ['ffmpeg', '-y', '-loglevel', 'error', '-i', wav,
             '-c:a', 'libvorbis', '-q:a', '5', os.path.normpath(target)],
            check=True,
        )
    print(f'wrote {os.path.normpath(target)}')


if __name__ == '__main__':
    main()
