"""Python reference for the experimental native kiosk echo canceller.

Requires NumPy and SciPy. Run this file with a probe input and PCM output path.
The input holds 10 ms blocks of reference, microphone and current AEC output,
in that order. Each channel has 160 signed little-endian 16-bit samples.
The output is mono PCM16 at 16 kHz, before any microphone gain.

The opt-in Android prototype uses the matching C++ implementation.
The kioskEchoPrototype build property enables intercom tests. Realtime tests
also require kioskEchoPrototypeRealtime because acoustic validation still fails.
Physical tests still show residual echo. Realtime trials fail either the
self-echo or interruption checks. This prototype is not validated for regular use.
It applies a fixed 80 Hz high-pass filter and subtracts an adaptive echo estimate.
It has no output gate, automatic gain control or generated comfort noise.
"""

import argparse
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfilt


class PartitionedCanceller:
    """Partitioned frequency-domain filter with diagonal uncertainty tracking.

    Call process with one 128-sample block of normalized reference and capture.
    The 32 partitions cover a 256 ms echo path, including reference delay.
    Each coefficient has its own learning rate. Unexpected microphone energy
    reduces learning without changing the output gain during simultaneous speech.
    """

    def __init__(self, block=128, partitions=32, process_noise=0.001):
        if block < 1 or partitions < 1 or not 0 < process_noise <= 0.1:
            raise ValueError("Invalid filter dimensions or process noise")
        self.block = block
        self.partitions = partitions
        self.process_noise = process_noise
        self.weights = np.zeros((partitions, block + 1), dtype=complex)
        self.render = np.zeros_like(self.weights)
        self.previous = np.zeros(block)
        self.uncertainty = np.full(self.weights.shape, 0.1)
        self.innovation = np.full(block + 1, 1e-5)
        self.unstable = 0
        self.recoveries = 0

    def process(self, reference, microphone):
        if np.shape(reference) != (self.block,) or np.shape(microphone) != (self.block,):
            raise ValueError("Each input must contain one complete filter block")
        n = self.block
        self.render[1:] = self.render[:-1]
        self.render[0] = np.fft.rfft(np.concatenate((self.previous, reference)))
        self.previous = np.array(reference, copy=True)
        predicted = np.fft.irfft(np.sum(self.weights * self.render, axis=0))[n:]
        error = microphone - predicted
        power = np.dot(error, error)
        if not np.isfinite(power) or power > 4 * np.dot(microphone, microphone) + 1e-7:
            self.unstable += 1
        else:
            self.unstable = 0
        if self.unstable >= 12 or not np.isfinite(power):
            self.weights.fill(0)
            self.uncertainty.fill(0.1)
            self.innovation.fill(1e-5)
            self.unstable = 0
            self.recoveries += 1
            return microphone.copy()

        spectrum = np.fft.rfft(np.concatenate((np.zeros(n), error)))
        self.innovation = 0.9 * self.innovation + 0.1 * abs(spectrum) ** 2
        render_power = abs(self.render) ** 2
        denominator = np.sum(self.uncertainty * render_power, axis=0) + 2 * self.innovation + 1e-7
        gain = self.uncertainty / denominator
        delta = gain * self.render.conj() * spectrum
        taps = np.fft.irfft(delta, axis=1)
        taps[:, n:] = 0
        self.weights += np.fft.rfft(taps, axis=1)
        self.uncertainty = np.minimum(
            100,
            (1 - 0.5 * gain * render_power) * self.uncertainty
            + self.process_noise * abs(self.weights) ** 2 + 1e-10,
        )
        return error


def run(reference, microphone, process_noise=0.001, partitions=32):
    """Replay PCM-scale arrays with causal filtering and flush a partial block."""
    reference = np.asarray(reference, dtype=float)
    microphone = np.asarray(microphone, dtype=float)
    if reference.ndim != 1 or reference.shape != microphone.shape:
        raise ValueError("Reference and microphone must be equal-length mono arrays")
    if not np.all(np.isfinite(reference)) or not np.all(np.isfinite(microphone)):
        raise ValueError("Audio must contain only finite samples")
    canceller = PartitionedCanceller(process_noise=process_noise, partitions=partitions)
    if not len(microphone):
        return np.zeros(0)
    highpass = butter(2, 80, fs=16000, btype="highpass", output="sos")
    reference = sosfilt(highpass, reference / 32768)
    microphone = sosfilt(highpass, microphone / 32768)
    n = canceller.block
    padding = (-len(microphone)) % n
    reference = np.pad(reference, (0, padding))
    padded = np.pad(microphone, (0, padding))
    out = np.empty_like(padded)
    for at in range(0, len(padded), n):
        out[at:at + n] = canceller.process(reference[at:at + n], padded[at:at + n])
    return out[:len(microphone)] * 32768


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--process-noise", type=float, default=0.001)
    parser.add_argument("--partitions", type=int, default=32)
    args = parser.parse_args()
    if args.input.resolve() == args.output.resolve():
        parser.error("The output must not overwrite the input recording")
    data = np.fromfile(args.input, dtype="<i2")
    if args.input.stat().st_size % 960:
        parser.error("The recording must contain complete 960-byte probe frames")
    frames = data.reshape(-1, 3, 160).astype(float)
    output = run(frames[:, 0].reshape(-1), frames[:, 1].reshape(-1), args.process_noise, args.partitions)
    np.clip(np.rint(output), -32768, 32767).astype("<i2").tofile(args.output)


if __name__ == "__main__":
    main()
