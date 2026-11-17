# Ubuntu JTAG UART test

This folder is a portable copy of `uart_test_simple.py` and its runtime input
files. It includes all `.mif` files under `memory_files/` and
`expected_output.txt`; log and hardware-state report files are generated here
when the script runs.

## Run

From this directory, create a virtual environment and install the Python
dependency:

```bash
sudo apt install python3 python3-venv
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python uart_test_simple.py
```

The host also needs a Linux-compatible Intel JTAG UART/Quartus installation,
its JTAG hardware drivers, and a connected, programmed board. Python packages
alone do not provide the Intel hardware runtime. The script sends data to the
connected board; press Ctrl+C to stop it.
