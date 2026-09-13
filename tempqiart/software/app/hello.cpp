#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include "system.h"
#include "io.h"

// Avalon MM Bridge & Section Constants (Word address << 2 = Byte offset)
#define WORD_BYTES              4u
#define BANK_COUNT              1024u
#define BANK_HALF_WORDS         1024u
#define BANK_STRIDE_WORDS       (2u * BANK_HALF_WORDS)
#define QUBO_BATCH_WORDS        512u
#define QUBO_BANK_WORDS         (2u * QUBO_BATCH_WORDS)
#define QUBO_BANKS_PER_ACK      5u
#define QUBO_DATA_MASK          0x3FFu

#define HP_RAM_WORDS            32u
#define HP_RAM_BASE             0x00800000u
#define HP_RAM_DATA_MASK        0xFFFFFFFFu

#define STATE_RAM_BASE          0x01000000u
#define STATE_RAM_SLOT_WORDS    64u
#define STATE_RAM_SLOTS         16u
// Byte-address stride between state RAM slots. The Avalon bridge divides
// byte addresses by 4 before the custom logic decodes address[20:17] as the
// slot select, so a slot increment of 1 there requires (1 << 17) << 2 here.
#define STATE_RAM_SLOT_STRIDE   0x00080000u

#define INIT_H_WORDS            2048u
#define INIT_H_RAM_BASE         0x01800000u
#define INIT_H_DATA_MASK        0x0FFFFFFFu

#define PROG_START_BASE         0x02000000u
#define PROG_TRIGGER_OFFSET     (PROG_START_BASE + 0u * WORD_BYTES)
#define START_TRIGGER_OFFSET    (PROG_START_BASE + 1u * WORD_BYTES)

// Generic MM Read / Write helpers
static inline void mm_write(uint32_t base, uint32_t idx, uint32_t val, uint32_t mask)
{
    IOWR_32DIRECT(MM_BRIDGE_0_BASE, base + (idx * WORD_BYTES), val & mask);
}

static inline uint32_t mm_read(uint32_t base, uint32_t idx, uint32_t mask)
{
    return IORD_32DIRECT(MM_BRIDGE_0_BASE, base + (idx * WORD_BYTES)) & mask;
}

static void mm_read_block(uint32_t base, uint32_t* dest, uint32_t count, uint32_t mask)
{
    for (uint32_t i = 0; i < count; ++i) {
        dest[i] = mm_read(base, i, mask);
    }
}

// Read `count` raw 32-bit words from stdin, avoiding scanf's slow
// character-by-character parsing overhead.
static void read_words_binary(uint32_t* dest, uint32_t count)
{
    uint8_t* buf = (uint8_t*)dest;
    uint32_t total = count * (uint32_t)sizeof(uint32_t);
    uint32_t received = 0;
    while (received < total) {
        int n = read(0, buf + received, total - received);
        if (n > 0) {
            received += (uint32_t)n;
        }
    }
}

// Write-only self-clearing trigger pulse. Go is only sampled by the FSM in
// S_READY, reached ~2049 cycles after program; wait 0.5s (huge margin) between
// the two so Go isn't silently dropped while still in S_PROGRAM.
static void pulse_triggers(void)
{
    IOWR_32DIRECT(MM_BRIDGE_0_BASE, PROG_TRIGGER_OFFSET, 0u);
    printf("[CPU] Program trigger pulsed. Waiting for programming to complete...\n");
    fflush(stdout);
    usleep(500000);

    IOWR_32DIRECT(MM_BRIDGE_0_BASE, START_TRIGGER_OFFSET, 0u);
    printf("[CPU] Start trigger pulsed.\n");
    fflush(stdout);
}

// Memory verification helper
static bool verify_region(const char* label, uint32_t base, uint32_t count, uint32_t mask, bool invert)
{
    for (uint32_t i = 0; i < count; ++i) {
        mm_write(base, i, invert ? ~i : i, mask);
    }
    for (uint32_t i = 0; i < count; ++i) {
        uint32_t expected = (invert ? ~i : i) & mask;
        uint32_t actual = mm_read(base, i, mask);
        if (actual != expected) {
            printf("[FAIL] %s mismatch at %lu: exp 0x%lX, got 0x%lX\n",
                   label, (unsigned long)i, (unsigned long)expected, (unsigned long)actual);
            return false;
        }
    }
    printf("[PASS] %s verified (%lu words).\n", label, (unsigned long)count);
    fflush(stdout);
    return true;
}

// =========================================================================
// UART Streaming Ingestion Functions
// =========================================================================

// 1. Initial h (256 words)
static void uart_init_h(void)
{
    printf("init_h\n");
    fflush(stdout);

    uint32_t h_values[INIT_H_WORDS];
    read_words_binary(h_values, INIT_H_WORDS);
    for (uint32_t i = 0; i < INIT_H_WORDS; ++i) {
        mm_write(INIT_H_RAM_BASE, i, h_values[i], INIT_H_DATA_MASK);
    }
    printf("Done\n");
    fflush(stdout);
}

// 2. Hyperparameters (32 words)
static void uart_hyper_params(void)
{
    printf("hyper_params\n");
    fflush(stdout);

    uint32_t hp[HP_RAM_WORDS];
    read_words_binary(hp, HP_RAM_WORDS);
    for (uint32_t i = 0; i < HP_RAM_WORDS; ++i) {
        mm_write(HP_RAM_BASE, i, hp[i], HP_RAM_DATA_MASK);
    }
    printf("Done\n");
    fflush(stdout);
}

// 3. State RAM Slot 0 (64 words = 2048-bit state vector)
static void uart_state_ram(void)
{
    printf("state_ram\n");
    fflush(stdout);

    uint32_t state[STATE_RAM_SLOT_WORDS];
    read_words_binary(state, STATE_RAM_SLOT_WORDS);
    for (uint32_t i = 0; i < STATE_RAM_SLOT_WORDS; ++i) {
        mm_write(STATE_RAM_BASE, i, state[i], 0xFFFFFFFFu);
    }
    printf("Done\n");
    fflush(stdout);
}

// 4. QUBO Symmetric Banks (1024 banks x 2 halves x 512 words)
static void uart_qubo(void)
{
    printf("qubo\n");
    fflush(stdout);

    static uint32_t batch[QUBO_BANK_WORDS];  // low half + high half of one bank

    for (uint32_t bank_id = 0; bank_id < BANK_COUNT; ++bank_id) {
        uint32_t bank_offset = (bank_id * BANK_STRIDE_WORDS) * WORD_BYTES;
        uint32_t half_offset = BANK_HALF_WORDS * WORD_BYTES;

        read_words_binary(batch, QUBO_BANK_WORDS);
        for (uint32_t i = 0; i < QUBO_BATCH_WORDS; ++i) mm_write(bank_offset, i, batch[i], QUBO_DATA_MASK);
        for (uint32_t i = 0; i < QUBO_BATCH_WORDS; ++i) mm_write(bank_offset + half_offset, i, batch[QUBO_BATCH_WORDS + i], QUBO_DATA_MASK);

        bool is_last_bank = (bank_id == BANK_COUNT - 1);
        if (((bank_id + 1) % QUBO_BANKS_PER_ACK) == 0 || is_last_bank) {
            printf("Done: %lu\n", (unsigned long)(bank_id + 1));
            fflush(stdout);
        }
    }
    printf("Complete\n");
    fflush(stdout);
}

// =========================================================================
// Memory Readback Summary
// =========================================================================

// Dump every row of the first `num_banks` QUBO banks (both halves) for testing.
static void print_qubo_banks(uint32_t num_banks)
{
    printf("[DEBUG] Dumping %lu full QUBO banks (%lu rows each)...\n",
           (unsigned long)num_banks, (unsigned long)QUBO_BATCH_WORDS);
    fflush(stdout);

    for (uint32_t bank_id = 0; bank_id < num_banks; ++bank_id) {
        uint32_t bank_offset = (bank_id * BANK_STRIDE_WORDS) * WORD_BYTES;
        uint32_t half_offset = BANK_HALF_WORDS * WORD_BYTES;
        printf("[QUBO Bank %lu]\n", (unsigned long)bank_id);
        for (uint32_t i = 0; i < QUBO_BATCH_WORDS; ++i) {
            uint32_t lo = mm_read(bank_offset, i, QUBO_DATA_MASK);
            uint32_t hi = mm_read(bank_offset + half_offset, i, QUBO_DATA_MASK);
            printf("  Bank[%lu] Row[%lu]: Low=%u, High=%u\n",
                   (unsigned long)bank_id, (unsigned long)i, lo, hi);
        }
        fflush(stdout);
    }
    printf("[DEBUG] QUBO bank dump complete.\n\n");
    fflush(stdout);
}

static void readback_all_memory_regions(void)
{
    printf("\n--- Memory Readback Summary ---\n");

    // Hyperparameters
    uint32_t hp[HP_RAM_WORDS];
    mm_read_block(HP_RAM_BASE, hp, HP_RAM_WORDS, HP_RAM_DATA_MASK);
    printf("[HP RAM]\n");
    for (uint32_t i = 0; i < 11; ++i) {
        printf("  HP[%02lu] = 0x%08lX (%ld)\n", (unsigned long)i, (unsigned long)hp[i], (long)hp[i]);
    }

    // Initial h (first 8)
    uint32_t h[8];
    mm_read_block(INIT_H_RAM_BASE, h, 8, INIT_H_DATA_MASK);
    printf("[Initial h RAM (first 8)]\n");
    for (uint32_t i = 0; i < 8; ++i) {
        printf("  h[%02lu] = 0x%07lX (%ld)\n", (unsigned long)i, (unsigned long)h[i], (long)h[i]);
    }

    // QUBO Bank 0 (first 4 words of each half)
    printf("[QUBO Bank 0 Sample]\n");
    for (uint32_t i = 0; i < 4; ++i) {
        uint32_t lo = mm_read(0, i, QUBO_DATA_MASK);
        uint32_t hi = mm_read(BANK_HALF_WORDS * WORD_BYTES, i, QUBO_DATA_MASK);
        printf("  Row[%lu]: Low=%u, High=%u\n", (unsigned long)i, lo, hi);
    }

    // State RAM - all 16 physical slots, each printed as one 2048-bit hex value
    // (word 63 = most significant 32 bits ... word 0 = least significant).
    uint32_t state[STATE_RAM_SLOT_WORDS];
    for (uint32_t slot = 0; slot < STATE_RAM_SLOTS; ++slot) {
        mm_read_block(STATE_RAM_BASE + slot * STATE_RAM_SLOT_STRIDE, state, STATE_RAM_SLOT_WORDS, 0xFFFFFFFFu);
        printf("State[%lu] = 0x", (unsigned long)slot);
        for (int32_t i = (int32_t)STATE_RAM_SLOT_WORDS - 1; i >= 0; --i) {
            printf("%08lX", (unsigned long)state[i]);
        }
        printf("\n");
    }
    printf("--- Readback Complete ---\n\n");
    fflush(stdout);
}

int main(void)
{
    // Block here until host connects and sends handshake, so early prints
    // aren't lost in the JTAG UART FIFO before the host script attaches.
    char handshake;
    read(0, &handshake, 1);

    printf("[CPU] Nios V Digital Annealer Controller online.\n");
    fflush(stdout);

    // Quick self-tests (debug: add markers to identify which test hangs)
    printf("[DEBUG] Starting self-tests...\n");
    fflush(stdout);
    
    printf("[DEBUG] Testing QUBO Bank 0...\n");
    fflush(stdout);
    verify_region("QUBO Bank 0", 0u, 512u, QUBO_DATA_MASK, false);
    
    printf("[DEBUG] Testing Hyperparam RAM...\n");
    fflush(stdout);
    verify_region("Hyperparam RAM", HP_RAM_BASE, HP_RAM_WORDS, HP_RAM_DATA_MASK, false);
    
    printf("[DEBUG] Testing Initial-h RAM...\n");
    fflush(stdout);
    verify_region("Initial-h RAM", INIT_H_RAM_BASE, INIT_H_WORDS, INIT_H_DATA_MASK, true);
    
    printf("[DEBUG] Testing State RAM Slot 0...\n");
    fflush(stdout);
    verify_region("State RAM Slot 0", STATE_RAM_BASE, STATE_RAM_SLOT_WORDS, 0xFFFFFFFFu, false);

    printf("[DEBUG] Self-tests complete. Starting UART streaming...\n");
    fflush(stdout);

    // UART Configuration Streaming
    uart_init_h();
    uart_hyper_params();
    uart_state_ram();
    uart_qubo();

    // Assert program/start only after all real data has been loaded, then
    // give the annealer time to run before reading back the outcome.
    printf("[DEBUG] Data loaded. Asserting program/start triggers...\n");
    fflush(stdout);
    pulse_triggers();

    // Check debug flags via Avalon section 0100 readback
    uint32_t debug_val = mm_read(PROG_START_BASE, 0, 0xFFFFFFFFu);
    bool go_live = debug_val & 1;
    bool go_fired = (debug_val >> 1) & 1;
    bool win_fired = (debug_val >> 2) & 1;
    uint32_t last_win = (debug_val >> 3) & 0x7FF;
    printf("[DEBUG DEBUG] Go_Live=%d | Go_Fired=%d | Winner_Fired=%d | LastWinnerIdx=%lu\n",
           go_live, go_fired, win_fired, (unsigned long)last_win);
    fflush(stdout);

    printf("[DEBUG] Waiting 3 seconds for annealing to complete...\n");
    fflush(stdout);
    usleep(3000000);

    // Read debug flags again after annealing wait
    debug_val = mm_read(PROG_START_BASE, 0, 0xFFFFFFFFu);
    go_live = debug_val & 1;
    go_fired = (debug_val >> 1) & 1;
    win_fired = (debug_val >> 2) & 1;
    last_win = (debug_val >> 3) & 0x7FF;
    printf("[DEBUG AFTER 3S] Go_Live=%d | Go_Fired=%d | Winner_Fired=%d | LastWinnerIdx=%lu\n",
           go_live, go_fired, win_fired, (unsigned long)last_win);
    fflush(stdout);

    // Dump 5 full QUBO banks for testing before the state summary.
    print_qubo_banks(5);

    // Readback verification
    readback_all_memory_regions();

    printf("[CPU] All operations completed.\n");
    return 0;
}
