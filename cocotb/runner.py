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
        top="twiddle_rom",
        test_module="twiddle_rom_test",
        sources=["twiddle_rom.sv"],
    )
