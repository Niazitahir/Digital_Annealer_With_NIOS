#!/usr/bin/env python3
"""
Decodes Intel HEX files (state_ram.hex and param.hex) into human-readable text.
"""

import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SOFTWARE_DIR = SCRIPT_DIR if os.path.basename(SCRIPT_DIR) == "software" else os.path.join(SCRIPT_DIR, "software")

STATE_HEX_PATH = os.path.join(SOFTWARE_DIR, "state_ram.hex")
STATE_OUT_PATH = os.path.join(SOFTWARE_DIR, "decoded_state_ram.txt")

PARAM_HEX_PATH = os.path.join(SOFTWARE_DIR, "param.hex")
PARAM_OUT_PATH = os.path.join(SOFTWARE_DIR, "decoded_param.txt")

# Named hyperparameter fields for hello.cpp / BitSieve_256
HP_NAMES = {
    0: "Reserved / Config Word 0",
    1: "Reserved / Config Word 1",
    2: "max_iter (Maximum Annealing Iterations)",
    3: "penalty / tabu_depth (Tabu History Depth [10:0])",
    4: "init_ising_energy (Initial Ising Energy)",
    5: "random_seed (PRNG Seed)",
    6: "e_off_delta (Energy Offset Step Size [17:0])",
    7: "qubo_constant_raw (QUBO Objective Constant Offset)",
    8: "global_min_raw (Target Optimum Ground State Energy)",
    9: "active_variable_count (Active Variable Count [11:0])",
    10: "weight_scale_raw_q25_2 (Q25.2 Integer Weight Scale Factor)",
}


def parse_intel_hex(file_path):
    """Parse an Intel HEX file into a dictionary mapping word_index to 32-bit uint."""
    words = {}
    with open(file_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line.startswith(":"):
                continue
            byte_count = int(line[1:3], 16)
            address = int(line[3:7], 16)
            record_type = int(line[7:9], 16)
            
            if record_type == 0:  # Data record
                data_hex = line[9:9 + byte_count * 2]
                val = int(data_hex, 16)
                word_idx = address // 4
                words[word_idx] = val
    return words


def decode_state_ram():
    """Decode state_ram.hex into 2048-bit hex vectors."""
    if not os.path.exists(STATE_HEX_PATH):
        print(f"[-] {STATE_HEX_PATH} not found, skipping state RAM decoding.")
        return

    print(f"[*] Reading {STATE_HEX_PATH}...")
    words = parse_intel_hex(STATE_HEX_PATH)
    max_word = max(words.keys()) if words else 0
    total_slots = (max_word // 64) + 1
    
    with open(STATE_OUT_PATH, "w", encoding="utf-8") as out:
        out.write(f"Decoded State RAM from {os.path.basename(STATE_HEX_PATH)}\n")
        out.write("=" * 80 + "\n\n")
        
        for slot in range(total_slots):
            slot_words = [words.get(slot * 64 + i, 0) for i in range(64)]
            val = 0
            for i, w in enumerate(slot_words):
                val |= (w << (32 * i))
            
            hex_2048 = format(val, "0512x")
            out.write(f"Slot {slot:02d} (2048-bit hex):\n")
            out.write(f"0x{hex_2048}\n\n")
            out.write(f"Slot {slot:02d} (64 x 32-bit words, Word 0 to Word 63):\n")
            for line_start in range(0, 64, 8):
                chunk = slot_words[line_start:line_start + 8]
                chunk_str = " ".join(f"{w:08X}" for w in chunk)
                out.write(f"  Word[{line_start:02d}..{line_start+7:02d}]: {chunk_str}\n")
            out.write("-" * 80 + "\n\n")
            
    print(f"[+] Successfully decoded {total_slots} state slot(s) into {STATE_OUT_PATH}")


def decode_params():
    """Decode param.hex into annotated hyperparameters."""
    if not os.path.exists(PARAM_HEX_PATH):
        print(f"[-] {PARAM_HEX_PATH} not found, skipping hyperparameter decoding.")
        return

    print(f"[*] Reading {PARAM_HEX_PATH}...")
    words = parse_intel_hex(PARAM_HEX_PATH)
    max_idx = max(words.keys()) if words else 31
    count = max(32, max_idx + 1)

    with open(PARAM_OUT_PATH, "w", encoding="utf-8") as out:
        out.write(f"Decoded Hyperparameters from {os.path.basename(PARAM_HEX_PATH)}\n")
        out.write("=" * 80 + "\n\n")
        out.write(f"{'Idx':<5} {'Hex Value':<12} {'Dec Value (Signed)':<20} {'Field Description'}\n")
        out.write("-" * 80 + "\n")

        for i in range(count):
            val = words.get(i, 0)
            signed_val = val if val < 0x80000000 else val - 0x100000000
            desc = HP_NAMES.get(i, f"Unused Hyperparameter Slot {i}")
            out.write(f"[{i:02d}] 0x{val:08X}    {signed_val:<20d} {desc}\n")
            
    print(f"[+] Successfully decoded {count} hyperparameter entries into {PARAM_OUT_PATH}")


def main():
    decode_state_ram()
    decode_params()


if __name__ == "__main__":
    main()
