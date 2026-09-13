#!/usr/bin/env python3
"""
Minimal JTAG UART test script for hello.cpp.

Follows the library's own example usage pattern (write, sleep, read) and
drives the full init_h / hyper_params / state_ram / qubo handshake using
data loaded from the .mif files in memory_files/.
"""

import ctypes
import datetime
import os
import re
import struct
import sys
import time

import intel_jtag_uart

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MEM_FILES_DIR = os.path.join(SCRIPT_DIR, "memory_files")
LOG_PATH = os.path.join(SCRIPT_DIR, "uart_test_simple.log")
EXPECTED_OUTPUT_PATH = os.path.join(SCRIPT_DIR, "..", "expected_output.txt")
HARDWARE_STATES_PATH = os.path.join(SCRIPT_DIR, "hardware_states.txt")
_log_file = open(LOG_PATH, "a", encoding="utf-8")


def log(message=""):
    """Print to console and append to the log file."""
    print(message)
    _log_file.write(message + "\n")
    _log_file.flush()

WORD_COUNTS = {
    "init_h": 2048,
    "hyper_params": 32,
    "state_ram": 64,
}
QUBO_HALF_WORDS = 512
QUBO_BANKS = 1024
QUBO_BANKS_PER_ACK = 5


def parse_mif(file_path):
    """Parse an Altera/Intel Memory Initialization File (.mif)."""
    with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
        text = f.read()

    text = re.sub(r'%.*?%', '', text, flags=re.DOTALL)
    text = re.sub(r'--.*', '', text)
    text = re.sub(r'//.*', '', text)

    radix_m = re.search(r'DATA_RADIX\s*=\s*([A-Za-z]+)', text, re.IGNORECASE)
    radix_str = radix_m.group(1).upper() if radix_m else 'HEX'
    base = 16 if radix_str == 'HEX' else (10 if radix_str in ('DEC', 'UNS') else (2 if radix_str == 'BIN' else 16))

    addr_radix_m = re.search(r'ADDRESS_RADIX\s*=\s*([A-Za-z]+)', text, re.IGNORECASE)
    addr_radix_str = addr_radix_m.group(1).upper() if addr_radix_m else 'HEX'
    addr_base = 16 if addr_radix_str == 'HEX' else (10 if addr_radix_str in ('DEC', 'UNS') else 16)

    content_m = re.search(r'CONTENT\s+BEGIN(.*?)END\s*;', text, re.IGNORECASE | re.DOTALL)
    if not content_m:
        return {}

    mem = {}
    for stmt in content_m.group(1).split(';'):
        stmt = stmt.strip()
        if not stmt or ':' not in stmt:
            continue
        left, right = stmt.split(':', 1)
        left = left.strip()
        val = int(right.strip(), base)
        if left.startswith('[') and left.endswith(']'):
            start_str, end_str = left[1:-1].split('..')
            for addr in range(int(start_str.strip(), addr_base), int(end_str.strip(), addr_base) + 1):
                mem[addr] = val
        else:
            mem[int(left, addr_base)] = val

    return mem


def load_words(path, count, mask):
    """Load `count` 32-bit words from a .mif file, or zeros if missing."""
    if not path or not os.path.exists(path):
        log(f"[-] {path} not found, using zeros.")
        return [0] * count
    mem = parse_mif(path)
    return [mem.get(i, 0) & mask for i in range(count)]


def load_state_ram(path, count):
    """Load State RAM Slot 0 (2048 bits = 64 x 32-bit words) from .mif."""
    if not path or not os.path.exists(path):
        log(f"[-] {path} not found, using zeros.")
        return [0] * count
    mem = parse_mif(path)
    slot0_val = mem.get(0, 0)
    return [(slot0_val >> (32 * i)) & 0xFFFFFFFF for i in range(count)]


def load_qubo_bank(bank_dir, bank_id, words_per_half):
    """Load one QUBO bank's low/high halves from sym_matrix_bank_DDDD.mif."""
    fname = os.path.join(bank_dir, f"sym_matrix_bank_{bank_id:04d}.mif")
    if not os.path.exists(fname):
        return [0] * words_per_half, [0] * words_per_half
    mem = parse_mif(fname)
    low = [mem.get(r, 0) & 0x3FF for r in range(words_per_half)]
    high = [mem.get(1024 + r, 0) & 0x3FF for r in range(words_per_half)]
    return low, high


def load_qubo_bank_group(bank_dir, start_bank, end_bank, words_per_half):
    """Load banks [start_bank, end_bank) as one flat word list (low+high per bank)."""
    words = []
    for bank_id in range(start_bank, end_bank):
        low, high = load_qubo_bank(bank_dir, bank_id, words_per_half)
        words.extend(low)
        words.extend(high)
    return words


def parse_expected_output(path=EXPECTED_OUTPUT_PATH):
    """Parse simulation trial states from expected_output.txt."""
    trials = {}
    if not os.path.exists(path):
        return trials
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            m = re.search(r"Trial\s+(\d+)\s+\|\s+X:\s*([0-9a-fA-F]+)", line)
            if m:
                trials[int(m.group(1))] = m.group(2).strip()
    return trials


def compute_similarity(hex1, hex2):
    """Compute bit-level and hex-character-level similarity score between two hex strings."""
    if not hex1 or not hex2 or len(hex1) != len(hex2):
        return None
    hex1_u = hex1.upper()
    hex2_u = hex2.upper()
    char_diffs = sum(1 for a, b in zip(hex1_u, hex2_u) if a != b)
    char_sim = ((len(hex1_u) - char_diffs) / len(hex1_u)) * 100.0

    try:
        val1 = int(hex1_u, 16)
        val2 = int(hex2_u, 16)
        bit_diffs = bin(val1 ^ val2).count("1")
        total_bits = len(hex1_u) * 4
        bit_sim = ((total_bits - bit_diffs) / total_bits) * 100.0
    except ValueError:
        bit_diffs = char_diffs
        total_bits = len(hex1_u) * 4
        bit_sim = char_sim

    return {
        "char_diffs": char_diffs,
        "char_sim": char_sim,
        "bit_diffs": bit_diffs,
        "bit_sim": bit_sim,
        "total_bits": total_bits,
    }


def save_and_compare_states(captured_states, output_path=HARDWARE_STATES_PATH, expected_path=EXPECTED_OUTPUT_PATH):
    """Save captured hardware states to hardware_states.txt and compare with expected_output.txt."""
    if not captured_states:
        log("[-] No hardware states captured for comparison.")
        return

    sim_trials = parse_expected_output(expected_path)

    lines = []
    lines.append("================================================================================")
    lines.append(f" Hardware Readback States & Simulation Comparison - {datetime.datetime.now().isoformat()}")
    lines.append("================================================================================\n")

    lines.append("--- Captured Hardware States ---")
    for slot in sorted(captured_states.keys()):
        lines.append(f"State[{slot}] = 0x{captured_states[slot]}")

    comp_summary = []

    if not sim_trials:
        msg = f"[-] Could not load expected output file at: {expected_path}"
        lines.append(msg)
        comp_summary.append(msg)
    else:
        lines.append("\n--- Direct Slot Comparison (Hardware State N vs Software Trial N+1) ---")
        for slot in sorted(captured_states.keys()):
            hw_hex = captured_states[slot].strip()
            trial_num = slot + 1
            sim_hex = sim_trials.get(trial_num, "").strip()

            if sim_hex:
                res = compute_similarity(hw_hex, sim_hex)
                if res:
                    if res["bit_diffs"] == 0:
                        desc = f"State[{slot:2d}] vs Trial {trial_num:2d}: EXACT MATCH (100.0% similarity)"
                    else:
                        desc = (
                            f"State[{slot:2d}] vs Trial {trial_num:2d}: Score {res['bit_sim']:.2f}% similarity "
                            f"({res['bit_diffs']} bit diffs / {res['char_diffs']} hex diffs out of {res['total_bits']} bits)"
                        )
                else:
                    desc = f"State[{slot:2d}] vs Trial {trial_num:2d}: Length Mismatch (HW={len(hw_hex)}, Sim={len(sim_hex)})"
            else:
                desc = f"State[{slot:2d}] vs Trial {trial_num:2d}: No simulation trial data available"

            lines.append(desc)

        lines.append("\n--- Best Software Match Outline (Which Software Trial matches each Hardware State the most) ---")
        for slot in sorted(captured_states.keys()):
            hw_hex = captured_states[slot].strip()
            best_t_id = None
            best_stats = None
            max_score = -1.0

            for t_id, sim_hex in sim_trials.items():
                sim_res = compute_similarity(hw_hex, sim_hex.strip())
                if sim_res and sim_res["bit_sim"] > max_score:
                    max_score = sim_res["bit_sim"]
                    best_t_id = t_id
                    best_stats = sim_res

            # Calculate expected trial index assuming 16-slot circular buffer
            total_trials = max(sim_trials.keys()) if sim_trials else 0
            if total_trials > 16:
                expected_trial = total_trials - (16 - (slot + 1) % 16) % 16
            else:
                expected_trial = slot + 1

            if best_stats:
                outline_str = (
                    f"Hardware State {slot:2d} (Expected Sim Trial {expected_trial:2d}) matches Software Trial {best_t_id:2d} the most "
                    f"with a similarity score of {best_stats['bit_sim']:.2f}% "
                    f"({best_stats['bit_diffs']} bit diffs / {best_stats['char_diffs']} hex diffs out of {best_stats['total_bits']} bits)"
                )
            else:
                outline_str = f"Hardware State {slot:2d}: Could not determine best software match."

            lines.append(outline_str)
            comp_summary.append(outline_str)

    lines.append("\n================================================================================\n")
    report_text = "\n".join(lines)

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(report_text)

    log(f"\n[+] Saved states and comparison report to: {output_path}")
    for cl in comp_summary:
        log(f"[SCORE] {cl}")


print("[*] Loading memory files...")
log(f"=== Run started {datetime.datetime.now().isoformat()} ===")
init_h_data = load_words(os.path.join(MEM_FILES_DIR, "h_init_values_28bit.mif"), WORD_COUNTS["init_h"], 0x0FFFFFFF)
hp_data = load_words(os.path.join(MEM_FILES_DIR, "hyper_p_init_values_32bit.mif"), WORD_COUNTS["hyper_params"], 0xFFFFFFFF)
state_ram_data = load_state_ram(os.path.join(MEM_FILES_DIR, "state_ram.mif"), WORD_COUNTS["state_ram"])
SYM_MATRIX_DIR = os.path.join(MEM_FILES_DIR, "sym_mtrix_bank")
log(f"[+] Loaded init_h ({len(init_h_data)}), hyper_params ({len(hp_data)}), state_ram ({len(state_ram_data)})")

try:
    ju = intel_jtag_uart.intel_jtag_uart()
except Exception as e:
    print(e)
    sys.exit(0)


def write_all(data: bytes):
    """ju.write() can do a partial write (jtagatlantic_write may accept less
    than the full buffer) and the library never retries, silently dropping
    the remainder. Loop here until every byte is actually sent."""
    write_fn = intel_jtag_uart.intel_jtag_uart.function_table["jtagatlantic_write"]["ptr"]
    flush_fn = intel_jtag_uart.intel_jtag_uart.function_table["jtagatlantic_flush"]["ptr"]
    sent = 0
    total = len(data)
    while sent < total:
        chunk = data[sent:]
        n = write_fn(ju.handle, ctypes.c_char_p(chunk), ctypes.c_uint(len(chunk)))
        if n == -1:
            raise Exception("Connection broken")
        if n > 0:
            sent += n
        else:
            time.sleep(0.001)
    flush_fn(ju.handle)


def send_words(values):
    """Send a list of 32-bit words as raw little-endian binary."""
    payload = struct.pack(f"<{len(values)}I", *values)
    write_all(payload)


def read_lines(timeout=2.0, poll=0.01):
    """Wait for at least one complete line, then return immediately with
    whatever else is buffered (does not idle-wait for the full timeout)."""
    start = time.time()
    data = b""
    while time.time() - start < timeout:
        chunk = ju.read()
        if chunk:
            data += chunk
            if b"\n" in data or b"\r" in data:
                break
        time.sleep(poll)
    return data.decode(errors="replace").splitlines()


print("[*] Sending startup handshake...")
write_all(b"\x01")

# Next bank index still to be sent (0-based); firmware acks every
# QUBO_BANKS_PER_ACK banks (or on the final partial group).
next_bank_index = 0
captured_states = {}
current_state_slot = None
has_compared = False

try:
    while True:
        for line in read_lines():
            line = line.strip()
            if not line:
                continue
            log(f"[Nios] {line}")

            # Reassemble State[slot] lines if multiline or fragmented
            m_state = re.match(r"^State\[(\d+)\]\s*=\s*0x([0-9a-fA-F]*)", line)
            if m_state:
                current_state_slot = int(m_state.group(1))
                captured_states[current_state_slot] = m_state.group(2)
            elif current_state_slot is not None and re.match(r"^[0-9a-fA-F]+$", line):
                captured_states[current_state_slot] += line
            elif not line.startswith("0x") and not re.match(r"^[0-9a-fA-F]+$", line):
                current_state_slot = None

            if line == "init_h":
                send_words(init_h_data)
            elif line == "hyper_params":
                send_words(hp_data)
            elif line == "state_ram":
                send_words(state_ram_data)
            elif line == "qubo":
                end = min(QUBO_BANKS_PER_ACK, QUBO_BANKS)
                send_words(load_qubo_bank_group(SYM_MATRIX_DIR, 0, end, QUBO_HALF_WORDS))
                next_bank_index = end
            elif line.startswith("Done:"):
                if next_bank_index < QUBO_BANKS:
                    end = min(next_bank_index + QUBO_BANKS_PER_ACK, QUBO_BANKS)
                    send_words(load_qubo_bank_group(SYM_MATRIX_DIR, next_bank_index, end, QUBO_HALF_WORDS))
                    next_bank_index = end
            elif line == "--- Readback Complete ---":
                if not has_compared:
                    save_and_compare_states(captured_states)
                    has_compared = True
            elif line == "Complete" or "All operations completed" in line:
                log("[+] Firmware reported completion. Continuing to poll for readback output (Ctrl+C to stop)...")
except KeyboardInterrupt:
    log("\n[!] Stopping.")
finally:
    if not has_compared and captured_states:
        save_and_compare_states(captured_states)
    ju.close()
    log("[+] Connection closed.")
    _log_file.close()

