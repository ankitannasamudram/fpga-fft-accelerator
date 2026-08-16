from pathlib import Path
from cocotb_tools.runner import get_runner


def run(top: str, test_module: str, sources: list[str]) -> None:
    project_root = Path(__file__).resolve().parents[1]
    rtl_dir = project_root / "rtl"
    source_paths = [rtl_dir / "fft_pkg.sv"] + \
        [rtl_dir / src for src in sources]

    runner = get_runner("icarus")
    runner.build(
        sources=source_paths,
        hdl_toplevel=top,
        always=True,
        build_args=["-g2012"],
    )
    runner.test(hdl_toplevel=top, test_module=test_module)


if __name__ == "__main__":
    run(
        top="fft_top",
        test_module="fft_top_test",
        sources=[
    "complex_mult.sv",
    "fft_butterfly.sv",
    "fft_address_gen.sv",
    "bit_reverse.sv",
    "fft_memory.sv",
    "twiddle_rom.sv",
    "fft_controller.sv",
    "fft_top.sv",
    ],
    )
