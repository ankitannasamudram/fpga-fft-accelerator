def bit_reverse(value: int, width: int = 6) -> int:
    result = 0
    for i in range(width):
        result |= ((value >> i) & 1) << (width - 1 - i)
    return result
