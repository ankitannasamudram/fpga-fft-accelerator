def signed_limits(width: int) -> tuple[int, int]:
    return -(1 << (width - 1)), (1 << (width - 1)) - 1


def saturate(value: int, width: int) -> int:
    lo, hi = signed_limits(width)
    return min(max(value, lo), hi)
