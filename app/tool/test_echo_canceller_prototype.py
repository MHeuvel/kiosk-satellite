"""Offline AEC tests. Run with python -m unittest from app/tool."""

import unittest

import numpy as np
from scipy.signal import butter, sosfilt

from echo_canceller_prototype import run


class PrototypeTests(unittest.TestCase):
    def test_silence_does_not_generate_audio(self):
        zero = np.zeros(16000 * 4)
        np.testing.assert_array_equal(run(zero, zero), zero)

    def test_delayed_echo_with_simultaneous_near_sound(self):
        rng = np.random.default_rng(93)
        reference = rng.normal(0, 1500, 16000 * 24)
        echo = np.zeros_like(reference)
        for lag, scale in ((2100, 0.6), (2197, -0.2), (2600, 0.08)):
            echo[lag:] += scale * reference[:-lag]
        near = rng.normal(0, 180, len(reference))
        near[:16000 * 12] = 0
        output = run(reference, echo + near)
        far = slice(16000 * 9, 16000 * 11)
        reduction = 20 * np.log10(np.std(echo[far]) / np.std(output[far]))
        expected = sosfilt(butter(2, 80, fs=16000, btype="highpass", output="sos"), near)
        overlap = slice(16000 * 15, 16000 * 23)
        transfer = np.dot(output[overlap], expected[overlap]) / np.dot(expected[overlap], expected[overlap])
        self.assertGreater(reduction, 25)
        self.assertGreater(transfer, 0.95)
        self.assertLess(transfer, 1.05)

    def test_quiet_near_sound_and_partial_final_block(self):
        rng = np.random.default_rng(7)
        near = rng.normal(0, 30, 16000 * 5 + 77)
        expected = sosfilt(butter(2, 80, fs=16000, btype="highpass", output="sos"), near)
        np.testing.assert_allclose(run(np.zeros_like(near), near), expected, atol=1e-10)


if __name__ == "__main__":
    unittest.main()
