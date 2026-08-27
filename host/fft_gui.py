import tkinter as tk
from tkinter import ttk, messagebox
import math

import numpy as np
import serial
from serial.tools import list_ports

from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure


N = 64
BAUD_RATE = 115200
OUTPUT_BYTES = 64 * 6
Q15_SCALE = 1 << 15


def signed24(value):

    value &= 0xFFFFFF

    if value & 0x800000:
        return value - 0x1000000

    return value


def make_uart_input_bytes(samples_real, samples_imag):

    data = bytearray()

    # each complex input sample is 4 bytes
    # real low, real high, imag low, imag high
    for real_value, imag_value in zip(samples_real, samples_imag):

        real_value &= 0xFFFF
        imag_value &= 0xFFFF

        data.append(real_value & 0xFF)
        data.append((real_value >> 8) & 0xFF)

        data.append(imag_value & 0xFF)
        data.append((imag_value >> 8) & 0xFF)

    return data


def decode_fft_outputs(data):

    outputs_real = []
    outputs_imag = []

    # each FFT output bin is 6 bytes
    for bin_index in range(N):

        base = bin_index * 6

        real_value = (
            data[base]
            | (data[base + 1] << 8)
            | (data[base + 2] << 16)
        )

        imag_value = (
            data[base + 3]
            | (data[base + 4] << 8)
            | (data[base + 5] << 16)
        )

        outputs_real.append(signed24(real_value))
        outputs_imag.append(signed24(imag_value))

    return np.array(outputs_real), np.array(outputs_imag)


class FFTDemoApp:

    def __init__(self, root):

        self.root = root
        self.root.title("Nexys A7 64-Point FFT Accelerator")
        self.root.geometry("1180x820")

        # dark mode colors
        self.bg = "#111827"
        self.panel = "#1f2937"
        self.text = "#f3f4f6"
        self.muted = "#9ca3af"
        self.blue = "#60a5fa"
        self.orange = "#fb923c"
        self.green = "#22c55e"
        self.red = "#ef4444"
        self.purple = "#c084fc"
        self.grid = "#374151"

        self.root.configure(bg=self.bg)

        self.samples_real = None
        self.samples_imag = None
        self.expected_fft = None

        self.port_var = tk.StringVar(value="COM4")
        self.amplitude_var = tk.DoubleVar(value=0.10)

        self.status_var = tk.StringVar(value="Ready")
        self.max_real_var = tk.StringVar(value="—")
        self.max_imag_var = tk.StringVar(value="—")
        self.rmse_var = tk.StringVar(value="—")
        self.result_var = tk.StringVar(value="READY")
        self.bytes_var = tk.StringVar(value="0 / 384 bytes")

        self.configure_styles()
        self.build_ui()
        self.refresh_ports()


    def configure_styles(self):

        style = ttk.Style()
        style.theme_use("clam")

        style.configure(
            "TFrame",
            background=self.bg
        )

        style.configure(
            "TLabel",
            background=self.bg,
            foreground=self.text
        )

        style.configure(
            "TLabelframe",
            background=self.panel,
            foreground=self.text
        )

        style.configure(
            "TLabelframe.Label",
            background=self.panel,
            foreground=self.muted
        )

        style.configure(
            "TCombobox",
            fieldbackground=self.panel,
            background=self.panel,
            foreground=self.text
        )

        style.configure(
            "TSpinbox",
            fieldbackground=self.panel,
            foreground=self.text
        )

        style.configure(
            "TButton",
            padding=6
        )


    def build_ui(self):

        top = ttk.Frame(self.root, padding=12)
        top.pack(fill="x")

        ttk.Label(
            top,
            text="COM Port"
        ).grid(row=0, column=0, sticky="w")

        self.port_combo = ttk.Combobox(
            top,
            textvariable=self.port_var,
            width=12,
            state="normal"
        )
        self.port_combo.grid(
            row=0,
            column=1,
            padx=(6, 14)
        )

        ttk.Button(
            top,
            text="Refresh Ports",
            command=self.refresh_ports
        ).grid(
            row=0,
            column=2,
            padx=(0, 22)
        )

        ttk.Label(
            top,
            text="Random input amplitude"
        ).grid(
            row=0,
            column=3,
            sticky="w"
        )

        amplitude_box = ttk.Spinbox(
            top,
            from_=0.01,
            to=0.95,
            increment=0.05,
            textvariable=self.amplitude_var,
            width=8
        )
        amplitude_box.grid(
            row=0,
            column=4,
            padx=(6, 22)
        )

        self.run_button = ttk.Button(
            top,
            text="Send Random FFT",
            command=self.run_random_fft
        )
        self.run_button.grid(
            row=0,
            column=5,
            padx=(0, 12)
        )

        ttk.Button(
            top,
            text="Run Tone Test",
            command=self.run_tone_fft
        ).grid(
            row=0,
            column=6
        )


        status_frame = tk.Frame(
            self.root,
            bg=self.bg
        )
        status_frame.pack(
            fill="x",
            padx=12,
            pady=(0, 10)
        )

        tk.Label(
            status_frame,
            textvariable=self.status_var,
            bg=self.bg,
            fg=self.text
        ).pack(side="left")

        self.pass_label = tk.Label(
            status_frame,
            textvariable=self.result_var,
            bg=self.panel,
            fg=self.muted,
            font=("Segoe UI", 10, "bold"),
            padx=12,
            pady=4
        )
        self.pass_label.pack(side="right")

        self.bytes_label = tk.Label(
            status_frame,
            textvariable=self.bytes_var,
            bg=self.bg,
            fg=self.muted,
            padx=12
        )
        self.bytes_label.pack(side="right")


        metrics = ttk.Frame(
            self.root,
            padding=(12, 0, 12, 10)
        )
        metrics.pack(fill="x")

        self.add_metric(
            metrics,
            "Max real error",
            self.max_real_var,
            0
        )

        self.add_metric(
            metrics,
            "Max imag error",
            self.max_imag_var,
            1
        )

        self.add_metric(
            metrics,
            "Complex RMSE",
            self.rmse_var,
            2
        )


        self.figure = Figure(
            figsize=(11, 7),
            dpi=100,
            facecolor=self.bg
        )

        self.ax_input = self.figure.add_subplot(311)
        self.ax_fft = self.figure.add_subplot(312)
        self.ax_error = self.figure.add_subplot(313)

        self.figure.tight_layout(pad=2.0)

        self.canvas = FigureCanvasTkAgg(
            self.figure,
            master=self.root
        )

        self.canvas.get_tk_widget().configure(
            bg=self.bg,
            highlightthickness=0
        )

        self.canvas.get_tk_widget().pack(
            fill="both",
            expand=True,
            padx=10,
            pady=(0, 10)
        )

        self.draw_empty_plots()


    def add_metric(self, parent, title, variable, column):

        frame = tk.Frame(
            parent,
            bg=self.panel,
            highlightthickness=1,
            highlightbackground=self.grid
        )

        frame.grid(
            row=0,
            column=column,
            padx=(0, 10),
            sticky="ew"
        )

        parent.columnconfigure(
            column,
            weight=1
        )

        tk.Label(
            frame,
            text=title,
            bg=self.panel,
            fg=self.muted,
            anchor="w"
        ).pack(
            fill="x",
            padx=10,
            pady=(8, 2)
        )

        tk.Label(
            frame,
            textvariable=variable,
            bg=self.panel,
            fg=self.text,
            font=("Segoe UI", 15, "bold")
        ).pack(
            padx=10,
            pady=(0, 8)
        )


    def style_axis(self, ax):

        ax.set_facecolor(self.panel)

        ax.tick_params(
            colors=self.muted
        )

        ax.xaxis.label.set_color(self.muted)
        ax.yaxis.label.set_color(self.muted)
        ax.title.set_color(self.text)

        for spine in ax.spines.values():
            spine.set_color(self.grid)

        ax.grid(
            True,
            color=self.grid,
            alpha=0.55
        )


    def draw_empty_plots(self):

        self.ax_input.clear()
        self.ax_fft.clear()
        self.ax_error.clear()

        self.style_axis(self.ax_input)
        self.style_axis(self.ax_fft)
        self.style_axis(self.ax_error)

        self.ax_input.set_title("Input samples")
        self.ax_input.set_xlabel("Sample")
        self.ax_input.set_ylabel("Amplitude")

        self.ax_fft.set_title("FFT magnitude: FPGA vs NumPy")
        self.ax_fft.set_xlabel("FFT bin")
        self.ax_fft.set_ylabel("Magnitude")

        self.ax_error.set_title("Complex output error by bin")
        self.ax_error.set_xlabel("FFT bin")
        self.ax_error.set_ylabel("|FPGA - NumPy| (LSB)")

        self.figure.tight_layout(pad=2.0)
        self.canvas.draw()


    def refresh_ports(self):

        ports = [
            port.device
            for port in list_ports.comports()
        ]

        self.port_combo["values"] = ports

        if "COM4" in ports:
            self.port_var.set("COM4")

        elif ports and self.port_var.get() not in ports:
            self.port_var.set(ports[0])

        if ports:
            self.status_var.set(
                f"Found serial ports: {', '.join(ports)}"
            )
        else:
            self.status_var.set(
                "No serial ports found"
            )


    def generate_random_frame(self):

        amplitude = float(
            self.amplitude_var.get()
        )

        # random complex Q1.15 samples
        real_float = np.random.uniform(
            -amplitude,
            amplitude,
            N
        )

        imag_float = np.random.uniform(
            -amplitude,
            amplitude,
            N
        )

        self.samples_real = np.round(
            real_float * Q15_SCALE
        ).astype(int)

        self.samples_imag = np.round(
            imag_float * Q15_SCALE
        ).astype(int)

        samples_complex = (
            self.samples_real / Q15_SCALE
            + 1j * self.samples_imag / Q15_SCALE
        )

        self.expected_fft = np.fft.fft(
            samples_complex
        )


    def generate_tone_frame(self):

        tone_bin = 5
        amplitude = 0.25

        samples_real = []
        samples_imag = []

        for n in range(N):

            angle = (
                2
                * math.pi
                * tone_bin
                * n
                / N
            )

            value = (
                amplitude
                * math.cos(angle)
            )

            samples_real.append(
                round(
                    value
                    * Q15_SCALE
                )
            )

            samples_imag.append(0)

        self.samples_real = np.array(
            samples_real
        )

        self.samples_imag = np.array(
            samples_imag
        )

        samples_complex = (
            self.samples_real / Q15_SCALE
            + 1j
            * self.samples_imag
            / Q15_SCALE
        )

        self.expected_fft = np.fft.fft(
            samples_complex
        )


    def run_random_fft(self):

        self.generate_random_frame()

        self.execute_hardware_run(
            "Random frame"
        )


    def run_tone_fft(self):

        self.generate_tone_frame()

        self.execute_hardware_run(
            "Bin-5 tone"
        )


    def execute_hardware_run(self, label):

        port = self.port_var.get().strip()

        if not port:

            messagebox.showerror(
                "Serial port",
                "Choose a COM port first."
            )

            return

        self.run_button.config(
            state="disabled"
        )

        self.status_var.set(
            f"{label} prepared"
        )

        self.result_var.set("WAITING")
        self.pass_label.config(
            fg=self.orange
        )

        self.bytes_var.set(
            "0 / 384 bytes"
        )

        self.root.update_idletasks()

        messagebox.showinfo(
            "Start the FPGA",
            "1. Press and release RESET (BTND) if you want a clean run.\n\n"
            "2. Press and release START (BTNC).\n\n"
            "3. Click OK here after pressing START.\n\n"
            "The PC will then send all 64 samples."
        )

        try:

            uart_data = make_uart_input_bytes(
                self.samples_real,
                self.samples_imag
            )

            self.status_var.set(
                f"Opening {port} at {BAUD_RATE} baud..."
            )

            self.root.update_idletasks()

            with serial.Serial(
                port,
                BAUD_RATE,
                timeout=5
            ) as ser:

                ser.reset_input_buffer()
                ser.reset_output_buffer()

                self.status_var.set(
                    "Sending 64 complex samples..."
                )

                self.root.update_idletasks()

                ser.write(uart_data)
                ser.flush()

                self.status_var.set(
                    "Waiting for FFT output..."
                )

                self.root.update_idletasks()

                received = ser.read(
                    OUTPUT_BYTES
                )

            self.bytes_var.set(
                f"{len(received)} / {OUTPUT_BYTES} bytes"
            )

            if len(received) != OUTPUT_BYTES:

                raise RuntimeError(
                    f"Expected {OUTPUT_BYTES} output bytes, "
                    f"but received {len(received)}."
                )

            fpga_real, fpga_imag = decode_fft_outputs(
                received
            )

            expected_real = np.round(
                self.expected_fft.real
                * Q15_SCALE
            ).astype(int)

            expected_imag = np.round(
                self.expected_fft.imag
                * Q15_SCALE
            ).astype(int)

            error_real = (
                fpga_real
                - expected_real
            )

            error_imag = (
                fpga_imag
                - expected_imag
            )

            max_real_error = int(
                np.max(
                    np.abs(error_real)
                )
            )

            max_imag_error = int(
                np.max(
                    np.abs(error_imag)
                )
            )

            complex_error = np.sqrt(
                error_real.astype(float) ** 2
                + error_imag.astype(float) ** 2
            )

            rmse = float(
                np.sqrt(
                    np.mean(
                        complex_error ** 2
                    )
                )
            )

            self.max_real_var.set(
                f"{max_real_error} LSB"
            )

            self.max_imag_var.set(
                f"{max_imag_error} LSB"
            )

            self.rmse_var.set(
                f"{rmse:.2f} LSB"
            )

            self.result_var.set("PASS")
            self.pass_label.config(
                fg=self.green
            )

            self.status_var.set(
                f"Received all {OUTPUT_BYTES} bytes successfully"
            )

            self.update_plots(
                fpga_real,
                fpga_imag,
                expected_real,
                expected_imag,
                complex_error
            )

        except Exception as exc:

            self.result_var.set("ERROR")

            self.pass_label.config(
                fg=self.red
            )

            self.status_var.set(
                str(exc)
            )

            messagebox.showerror(
                "FFT hardware test failed",
                str(exc)
            )

        finally:

            self.run_button.config(
                state="normal"
            )


    def update_plots(
        self,
        fpga_real,
        fpga_imag,
        expected_real,
        expected_imag,
        complex_error
    ):

        bins = np.arange(N)

        input_complex = (
            self.samples_real / Q15_SCALE
            + 1j
            * self.samples_imag
            / Q15_SCALE
        )

        fpga_complex = (
            fpga_real
            + 1j * fpga_imag
        )

        expected_complex = (
            expected_real
            + 1j * expected_imag
        )

        fpga_magnitude = np.abs(
            fpga_complex
        )

        expected_magnitude = np.abs(
            expected_complex
        )


        # input waveform
        self.ax_input.clear()
        self.style_axis(self.ax_input)

        self.ax_input.plot(
            bins,
            input_complex.real,
            label="Real input",
            color=self.blue,
            linewidth=1.6
        )

        self.ax_input.plot(
            bins,
            input_complex.imag,
            label="Imag input",
            color=self.purple,
            linewidth=1.6
        )

        self.ax_input.set_title(
            "Input samples"
        )

        self.ax_input.set_xlabel(
            "Sample"
        )

        self.ax_input.set_ylabel(
            "Amplitude"
        )

        self.ax_input.legend(
            loc="upper right",
            facecolor=self.panel,
            edgecolor=self.grid,
            labelcolor=self.text
        )


        # FPGA vs NumPy FFT magnitude
        self.ax_fft.clear()
        self.style_axis(self.ax_fft)

        self.ax_fft.plot(
            bins,
            expected_magnitude,
            label="NumPy reference",
            color=self.blue,
            linewidth=2.0
        )

        self.ax_fft.plot(
            bins,
            fpga_magnitude,
            label="FPGA",
            color=self.orange,
            linestyle="--",
            linewidth=1.5
        )

        self.ax_fft.set_title(
            "FFT magnitude: FPGA vs NumPy"
        )

        self.ax_fft.set_xlabel(
            "FFT bin"
        )

        self.ax_fft.set_ylabel(
            "Magnitude (Q15-scaled)"
        )

        self.ax_fft.legend(
            loc="upper right",
            facecolor=self.panel,
            edgecolor=self.grid,
            labelcolor=self.text
        )


        # complex error
        self.ax_error.clear()
        self.style_axis(self.ax_error)

        self.ax_error.plot(
            bins,
            complex_error,
            color=self.green,
            linewidth=1.7
        )

        self.ax_error.fill_between(
            bins,
            0,
            complex_error,
            color=self.green,
            alpha=0.12
        )

        self.ax_error.set_title(
            "Complex output error by bin"
        )

        self.ax_error.set_xlabel(
            "FFT bin"
        )

        self.ax_error.set_ylabel(
            "Error magnitude (LSB)"
        )


        self.figure.tight_layout(
            pad=2.0
        )

        self.canvas.draw_idle()


if __name__ == "__main__":

    root = tk.Tk()

    app = FFTDemoApp(root)

    root.mainloop()
