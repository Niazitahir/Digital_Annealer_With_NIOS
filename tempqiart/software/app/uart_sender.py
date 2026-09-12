#!/usr/bin/env python3
"""
JUART Host Script for Nios V BitSieve Digital Annealer.
Uses Intel JTAG UART Python library for direct device communication.

Loads memory configurations from .mif files (or synthetic test patterns) and streams them:
  1. init_h (256 words)        -> INITIAL_H_RAM
  2. hyper_params (32 words)   -> HYPERPARAM_RAM
  3. state_ram (64 words)      -> STATE_RAM Slot 0
  4. qubo (1024 banks x 2 halves x 512 words) -> SYM_MATRIX_BANKS

Requires: pip install intel-jtag-uart
"""

import intel_jtag_uart
import ctypes
import subprocess
import time
import sys
import os
import re
import argparse

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MEM_FILES_DIR = os.path.join(SCRIPT_DIR, "memory_files")

DEFAULT_HP = [0] * 32
DEFAULT_HP[2:11] = [1000, 8, 0, 0x12345678, 2, 0, 0, 256, 1]


class JuartConnection:
    """Wrapper around intel_jtag_uart for FPGA communication."""

    def __init__(self):
        try:
            self.ju = intel_jtag_uart.intel_jtag_uart()
            print("[+] Connected to JTAG UART device via intel_jtag_uart library.")
        except Exception as e:
            print(f"[-] Failed to connect to JTAG UART: {e}")
            raise

    def write(self, data: bytes):
        """Write bytes to JTAG UART."""
        try:
            self.ju.write(data)
        except Exception as e:
            print(f"[-] Write error: {e}")

    def _raw_read(self) -> bytes:
        """Read available bytes, bypassing the library's read() which passes
        an immutable bytes object to ctypes.c_char_p() so writes never land
        back in Python. Uses a real mutable buffer instead."""
        buf_len = self.ju.bytes_available()
        if buf_len <= 0:
            return b""
        buf = ctypes.create_string_buffer(buf_len)
        read_fn = intel_jtag_uart.intel_jtag_uart.function_table['jtagatlantic_read']['ptr']
        bytes_read = read_fn(self.ju.handle, buf, ctypes.c_uint(buf_len))
        if bytes_read == -1:
            raise Exception("Connection broken")
        return buf.raw[:bytes_read] if bytes_read > 0 else b""

    def readline(self, timeout=1.0) -> bytes:
        """Read a line (up to newline) from JTAG UART with timeout."""
        start_time = time.time()
        line_buffer = bytearray()

        while time.time() - start_time < timeout:
            try:
                chunk = self._raw_read()
                if not chunk:
                    time.sleep(0.001)
                    continue

                for byte in chunk:
                    if byte in (ord('\n'), ord('\r')):
                        if line_buffer:
                            return bytes(line_buffer)
                        line_buffer.clear()
                    else:
                        line_buffer.append(byte)
            except Exception as e:
                time.sleep(0.001)
                continue

        if line_buffer:
            return bytes(line_buffer)
        return b""

    def close(self):
        """Close JTAG UART connection."""
        try:
            if hasattr(self, 'ju'):
                del self.ju
        except Exception:
            pass


def parse_mif(file_path):
    """Parse an Altera/Intel Memory Initialization File (.mif)."""
    with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
        text = f.read()

    # Strip comments (--, //, %...%)
    text = re.sub(r'%.*?%', '', text, flags=re.DOTALL)
    text = re.sub(r'--.*', '', text)
    text = re.sub(r'//.*', '', text)

    width_m = re.search(r'WIDTH\s*=\s*(\d+)', text, re.IGNORECASE)
    depth_m = re.search(r'DEPTH\s*=\s*(\d+)', text, re.IGNORECASE)
    width = int(width_m.group(1)) if width_m else 32
    depth = int(depth_m.group(1)) if depth_m else 0

    radix_m = re.search(r'DATA_RADIX\s*=\s*([A-Za-z]+)', text, re.IGNORECASE)
    radix_str = radix_m.group(1).upper() if radix_m else 'HEX'
    base = 16 if radix_str == 'HEX' else (10 if radix_str in ('DEC', 'UNS') else (2 if radix_str == 'BIN' else 16))

    addr_radix_m = re.search(r'ADDRESS_RADIX\s*=\s*([A-Za-z]+)', text, re.IGNORECASE)
    addr_radix_str = addr_radix_m.group(1).upper() if addr_radix_m else 'HEX'
    addr_base = 16 if addr_radix_str == 'HEX' else (10 if addr_radix_str in ('DEC', 'UNS') else 16)

    content_m = re.search(r'CONTENT\s+BEGIN(.*?)END\s*;', text, re.IGNORECASE | re.DOTALL)
    if not content_m:
        return width, depth, {}

    content = content_m.group(1)
    mem = {}
    for stmt in content.split(';'):
        stmt = stmt.strip()
        if not stmt or ':' not in stmt:
            continue
        left, right = stmt.split(':', 1)
        left = left.strip()
        right = right.strip()
        val = int(right, base)
        if left.startswith('[') and left.endswith(']'):
            range_str = left[1:-1]
            start_str, end_str = range_str.split('..')
            start_addr = int(start_str.strip(), addr_base)
            end_addr = int(end_str.strip(), addr_base)
            for addr in range(start_addr, end_addr + 1):
                mem[addr] = val
        else:
            addr = int(left, addr_base)
            mem[addr] = val

    return width, depth, mem


def load_h_init_file(path, count=256):
    """Load initial_h values from .mif or plain text/mem file."""
    if not path or not os.path.exists(path):
        print(f"[-] h_init file not found: {path}, using zeros.")
        return [0] * count
    if path.lower().endswith('.mif'):
        _, _, mem = parse_mif(path)
        data = [mem.get(i, 0) & 0x0FFFFFFF for i in range(count)]
    else:
        data = load_raw_nums(path, count)
    print(f"[+] Loaded {len(data)} initial_h words from {os.path.basename(path)}")
    return data


def load_hyper_params_file(path, count=32):
    """Load hyperparameters from .mif or plain text/mem file."""
    if not path or not os.path.exists(path):
        print(f"[-] hyper_params file not found: {path}, using default profile.")
        return list(DEFAULT_HP)
    if path.lower().endswith('.mif'):
        _, _, mem = parse_mif(path)
        data = [mem.get(i, 0) & 0xFFFFFFFF for i in range(count)]
    else:
        data = load_raw_nums(path, count)
    print(f"[+] Loaded {len(data)} hyperparameter words from {os.path.basename(path)}")
    return data


def load_state_ram_file(path, count=64):
    """Load State RAM Slot 0 (2048 bits = 64 x 32-bit words) from .mif or plain text/mem file."""
    if not path or not os.path.exists(path):
        print(f"[-] state_ram file not found: {path}, using zeros.")
        return [0] * count
    if path.lower().endswith('.mif'):
        width, _, mem = parse_mif(path)
        slot0_val = mem.get(0, 0)
        data = [(slot0_val >> (32 * i)) & 0xFFFFFFFF for i in range(count)]
    else:
        data = load_raw_nums(path, count)
    print(f"[+] Loaded {len(data)} state_ram slot 0 words from {os.path.basename(path)}")
    return data


def load_sym_matrix_dir(bank_dir, num_banks=1024, words_per_half=512):
    """Load 1024 QUBO banks from directory containing sym_matrix_bank_DDDD.mif files."""
    if not bank_dir or not os.path.isdir(bank_dir):
        print(f"[-] sym_matrix directory not found: {bank_dir}, using zeros.")
        return [([0] * words_per_half, [0] * words_per_half) for _ in range(num_banks)]

    banks_data = []
    t0 = time.time()
    for b in range(num_banks):
        fname = os.path.join(bank_dir, f"sym_matrix_bank_{b:04d}.mif")
        if os.path.exists(fname):
            _, _, mem = parse_mif(fname)
            low = [mem.get(r, 0) & 0x3FF for r in range(words_per_half)]
            high = [mem.get(1024 + r, 0) & 0x3FF for r in range(words_per_half)]
        else:
            low = [0] * words_per_half
            high = [0] * words_per_half
        banks_data.append((low, high))

    print(f"[+] Loaded {len(banks_data)} QUBO banks from {os.path.basename(bank_dir)} in {time.time() - t0:.2f}s")
    return banks_data


def load_raw_nums(path, count):
    """Fallback parser for whitespace/newline separated number files."""
    nums = []
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.split('//')[0].split('#')[0].strip()
            for tok in line.split():
                try:
                    nums.append(int(tok, 16 if any(c in 'abcdefABCDEF' for c in tok) or tok.startswith(('0x', '0X')) else 10))
                except ValueError:
                    continue
    if count and len(nums) < count:
        nums.extend([0] * (count - len(nums)))
    return nums[:count] if count else nums


def generate_test_patterns():
    """Generates synthetic verification test patterns for all pathways."""
    init_h = [(~i) & 0x0FFFFFFF for i in range(256)]
    hp = list(DEFAULT_HP)
    for i in range(11, 32):
        hp[i] = 0xAA000000 | i
    state_ram = [(0xA5A50000 | i) for i in range(64)]

    qubo_banks = []
    for bank in range(1024):
        low = [(bank + row) & 0x3FF for row in range(512)]
        high = [((bank ^ 0x3FF) + row) & 0x3FF for row in range(512)]
        qubo_banks.append((low, high))

    return init_h, hp, state_ram, qubo_banks


def send_block(conn, data, delay=0.0005):
    """Send array of numbers over JTAG UART."""
    for n in data:
        conn.write(f"{n}\n".encode())
        if delay:
            time.sleep(delay)


def wait_for(conn, prefix, timeout=2.0):
    """Wait for message starting with prefix."""
    start_time = time.time()
    while time.time() - start_time < timeout:
        raw = conn.readline(timeout=0.5)
        if not raw:
            continue
        line = raw.decode(errors='replace').strip()
        if line:
            print(f"[Nios] {line}")
            if line.startswith(prefix):
                return line
    print(f"[!] Timeout waiting for '{prefix}'")
    return b""


def main():
    p = argparse.ArgumentParser(description="JTAG UART host script for BitSieve Digital Annealer (Intel JTAG Library)")
    p.add_argument("-t", "--test-pattern", action="store_true", help="Send synthetic test patterns")
    p.add_argument("--init-h", help="Path to initial_h .mif/.mem file")
    p.add_argument("--hyper-params", help="Path to hyperparameter .mif/.mem file")
    p.add_argument("--state-ram", help="Path to state_ram .mif/.mem file")
    p.add_argument("--sym-matrix-dir", help="Directory containing sym_matrix_bank_DDDD.mif files")
    p.add_argument("--skip-download", action="store_true", help="Skip Nios V executable download")
    args = p.parse_args()

    # Download Nios V executable to FPGA (unless --skip-download is set)
    if not args.skip_download:
        print("[*] Downloading Nios V executable to FPGA...")
        try:
            download_cmd = r'niosv-shell -r "niosv-download -g software\app\build\Debug\app.elf"'
            result = subprocess.run(download_cmd, shell=True, capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                print("[+] Nios V executable downloaded successfully.")
            else:
                print(f"[-] Download failed with exit code {result.returncode}")
                print(f"stderr: {result.stderr}")
                sys.exit(1)
        except subprocess.TimeoutExpired:
            print("[-] Download command timed out after 30 seconds.")
            sys.exit(1)
        except Exception as e:
            print(f"[-] Failed to download executable: {e}")
            sys.exit(1)

    # Default file paths inside memory_files
    def_h = os.path.join(MEM_FILES_DIR, "h_init_values_28bit.mif")
    def_hp = os.path.join(MEM_FILES_DIR, "hyper_p_init_values_32bit.mif")
    def_st = os.path.join(MEM_FILES_DIR, "state_ram.mif")
    def_sym_dir = os.path.join(MEM_FILES_DIR, "sym_mtrix_bank")

    if args.test_pattern:
        print("[+] Test pattern mode active: generating synthetic test patterns...")
        init_h_data, hp_data, state_ram_data, qubo_banks = generate_test_patterns()
    else:
        mode = "1"
        if not (args.init_h or args.hyper_params or args.state_ram or args.sym_matrix_dir):
            mode = input("Select mode: [1] Load .mif files, [2] Send synthetic test patterns (default=1): ").strip() or "1"

        if mode == "2":
            print("[+] Test pattern mode active: generating synthetic test patterns...")
            init_h_data, hp_data, state_ram_data, qubo_banks = generate_test_patterns()
        else:
            h_path = args.init_h or (def_h if os.path.exists(def_h) else input("Path to initial_h .mif: ").strip())
            hp_path = args.hyper_params or (def_hp if os.path.exists(def_hp) else input("Path to hyper_params .mif: ").strip())
            st_path = args.state_ram or (def_st if os.path.exists(def_st) else input("Path to state_ram .mif: ").strip())
            sym_dir = args.sym_matrix_dir or (def_sym_dir if os.path.isdir(def_sym_dir) else input("Path to sym_matrix_bank directory: ").strip())

            init_h_data = load_h_init_file(h_path, 256)
            hp_data = load_hyper_params_file(hp_path, 32)
            state_ram_data = load_state_ram_file(st_path, 64)
            qubo_banks = load_sym_matrix_dir(sym_dir, 1024, 512)

    # Connect to JTAG UART
    try:
        conn = JuartConnection()
    except Exception as e:
        print(f"[-] Failed to establish JTAG UART connection: {e}")
        sys.exit(1)

    print("[+] Connected to Nios V. Awaiting commands...\n")

    # Handshake: firmware blocks at startup until it receives this,
    # ensuring its early output isn't lost before we're listening.
    conn.write(b"1\n")

    try:
        while True:
            raw = conn.readline(timeout=1.0)
            if not raw:
                continue
            line = raw.decode(errors='replace').strip()
            if not line:
                continue
            print(f"[Nios] {line}")

            # 1. init_h
            if line == "init_h":
                print(f"--> [JUART] Streaming 256 initial_h words...")
                send_block(conn, init_h_data[:256])
                wait_for(conn, "Done")

            # 2. hyper_params
            elif line == "hyper_params":
                print(f"--> [JUART] Streaming 32 hyperparameter words...")
                send_block(conn, hp_data[:32])
                wait_for(conn, "Done")

            # 3. state_ram
            elif line == "state_ram":
                print(f"--> [JUART] Streaming 64 state_ram Slot 0 words...")
                send_block(conn, state_ram_data[:64])
                wait_for(conn, "Done")

            # 4. qubo
            elif line == "qubo":
                print(f"--> [JUART] Streaming 1024 QUBO banks (512 words/half)...")
                for bank_id, (low_half, high_half) in enumerate(qubo_banks):
                    send_block(conn, low_half)
                    wait_for(conn, "Done:")
                    send_block(conn, high_half)
                    wait_for(conn, "Done:")
                wait_for(conn, "Complete")

            elif "All operations completed" in line or "All tests and configuration complete" in line:
                print("\n[+] All transfers and operations completed successfully!")
                break

    except KeyboardInterrupt:
        print("\n[!] Interrupted by user.")
    finally:
        conn.close()
        print("[+] JTAG UART connection closed.")


if __name__ == "__main__":
    main()