import math

FFT_N = 64
TWIDDLE_W = 16
FRAC_W = 15


def quantize(value: float) -> int:
    lo = -(1 << (TWIDDLE_W - 1))
    hi = (1 << (TWIDDLE_W - 1)) - 1
    return min(max(round(value * (1 << FRAC_W)), lo), hi)


for k in range(FFT_N // 2):
    angle = -2.0 * math.pi * k / FFT_N
    print(k, quantize(math.cos(angle)), quantize(math.sin(angle)))
