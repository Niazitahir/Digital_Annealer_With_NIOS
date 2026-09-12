# JUART & Memory Configuration

This directory contains the host transmission script for communicating with the Nios V / Digital Annealer processor over Intel JTAG UART via `niosv-shell` and `juart-terminal`.

## Files

- `uart_sender.py`: Python host script that spawns `niosv-shell -r "juart-terminal"` to stream `.mif` memory configurations directly to the FPGA
- `hello.cpp`: Embedded C++ application running on Nios V
- `memory_files/`: Directory containing source `.mif` memory initialization files:
  - `h_init_values_28bit.mif` (256 entries used)
  - `hyper_p_init_values_32bit.mif` (32 entries)
  - `state_ram.mif` (2048-bit wide slot 0)
  - `sym_mtrix_bank/sym_matrix_bank_0000.mif` ... `sym_matrix_bank_1023.mif` (1024 banks)

## Usage

1. **Default JTAG UART execution** (automatically connects via `niosv-shell -r juart-terminal`):
   ```bash
   python uart_sender.py
   ```

2. **Specify JTAG options** (optional cable/device selection):
   ```bash
   python uart_sender.py --cable "USB-BlasterII" --device 1
   ```

3. **Specify custom `.mif` files or directories**:
   ```bash
   python uart_sender.py --init-h memory_files/h_init_values_28bit.mif \
                         --hyper-params memory_files/hyper_p_init_values_32bit.mif \
                         --state-ram memory_files/state_ram.mif \
                         --sym-matrix-dir memory_files/sym_mtrix_bank
   ```

4. **Synthetic Test Pattern mode** (tests all pathways without requiring `.mif` files):
   ```bash
   python uart_sender.py -t
   ```

5. **Serial COM port fallback** (if hardware UART is used instead of JTAG UART):
   ```bash
   python uart_sender.py --serial-port COM3 --baud 115200
   ```

## Communication Protocol

1. **`init_h`**:
   - Nios sends `init_h`
   - Host streams 256 words
   - Nios writes to `INITIAL_H_RAM` and replies `Done`

2. **`hyper_params`**:
   - Nios sends `hyper_params`
   - Host streams 32 words
   - Nios writes to `HYPERPARAM_RAM` and replies `Done`

3. **`state_ram`**:
   - Nios sends `state_ram`
   - Host streams 64 words (2048 bits for Slot 0)
   - Nios writes to `STATE_RAM` and replies `Done`

4. **`qubo`**:
   - Nios sends `qubo`
   - Host streams 512 words for Bank 0 low-half; Nios responds `Done: 1/2`
   - Host streams 512 words for Bank 0 high-half; Nios responds `Done: 1`
   - Loops through all 1024 banks
   - Nios prints `Complete` and outputs readback diagnostics.

## Requirements

- Intel Quartus Prime / Nios V command-line tools in PATH (`niosv-shell`)
- Python 3.x (standard library only; `pyserial` only needed if `--serial-port` fallback is used)