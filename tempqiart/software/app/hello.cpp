#include <stdio.h>
#include <stdint.h>
#include "system.h"
#include "io.h"

#define QUBO_BANK_WORDS 2048u
#define QUBO_DATA_MASK 0x3FFu
#define QUBO_WORD_BYTES 4u

#define HYPERPARAM_RAM_WORDS 32u
#define HYPERPARAM_RAM_BASE_OFFSET 0x01F0000u
#define HYPERPARAM_RAM_DATA_MASK 0xFFFFFFFFu

#define INITIAL_H_RAM_WORDS 2048u
#define INITIAL_H_RAM_BASE_OFFSET 0x01F0100u
#define INITIAL_H_RAM_DATA_MASK 0x0FFFFFFFu

static bool verify_memory_region(const char* label,
                                uint32_t base_offset,
                                uint32_t word_count,
                                uint32_t mask,
                                bool invert_pattern)
{
    for (uint32_t word = 0; word < word_count; ++word) {
        uint32_t pattern = invert_pattern ? (~word) & mask : (word & mask);

        IOWR_32DIRECT(MM_BRIDGE_0_BASE,
                      base_offset + (word * QUBO_WORD_BYTES),
                      pattern);
    }

    for (uint32_t word = 0; word < word_count; ++word) {
        uint32_t expected = invert_pattern ? (~word) & mask : (word & mask);
        uint32_t actual = IORD_32DIRECT(MM_BRIDGE_0_BASE,
                                        base_offset + (word * QUBO_WORD_BYTES)) & mask;

        if (actual != expected) {
            printf("%s mismatch at word %lu: expected %lu, got %lu\n",
                   label,
                   (unsigned long)word,
                   (unsigned long)expected,
                   (unsigned long)actual);
            return false;
        }
    }

    printf("%s test passed.\n", label);
    return true;
}

int main(void)
{
    printf("[CPU heartbeat] Hello from Nios V!\n");
    fflush(stdout);

    printf("[CPU heartbeat] Starting QUBO bank 0 test (%u words)...\n", QUBO_BANK_WORDS);
    fflush(stdout);

    for (uint32_t word = 0; word < QUBO_BANK_WORDS; ++word) {
        if ((word & 0xFFu) == 0u) {
            printf("[CPU heartbeat] QUBO write progress: word %lu\n", (unsigned long)word);
            fflush(stdout);
        }

        IOWR_32DIRECT(MM_BRIDGE_0_BASE,
                      word * QUBO_WORD_BYTES,
                      word & QUBO_DATA_MASK);
    }

    printf("[CPU heartbeat] QUBO write phase complete. Starting read phase.\n");
    fflush(stdout);

    for (uint32_t word = 0; word < QUBO_BANK_WORDS; ++word) {
        if ((word & 0xFFu) == 0u) {
            printf("[CPU heartbeat] QUBO read progress: word %lu\n", (unsigned long)word);
            fflush(stdout);
        }

        uint32_t expected = word & QUBO_DATA_MASK;
        uint32_t actual = IORD_32DIRECT(MM_BRIDGE_0_BASE,
                                        word * QUBO_WORD_BYTES) & QUBO_DATA_MASK;

        if (actual != expected) {
            printf("Mismatch at word %lu: expected %lu, got %lu\n",
                   (unsigned long)word,
                   (unsigned long)expected,
                   (unsigned long)actual);
            return 1;
        }
    }

    printf("[CPU heartbeat] QUBO bank 0 test passed.\n");
    fflush(stdout);

    printf("[CPU heartbeat] Starting hyperparam RAM test.\n");
    fflush(stdout);
    if (!verify_memory_region("hyperparam RAM",
                              HYPERPARAM_RAM_BASE_OFFSET,
                              HYPERPARAM_RAM_WORDS,
                              HYPERPARAM_RAM_DATA_MASK,
                              false)) {
        return 1;
    }

    printf("[CPU heartbeat] Starting initial_h RAM test.\n");
    fflush(stdout);
    if (!verify_memory_region("initial_h RAM",
                              INITIAL_H_RAM_BASE_OFFSET,
                              INITIAL_H_RAM_WORDS,
                              INITIAL_H_RAM_DATA_MASK,
                              true)) {
        return 1;
    }

    printf("[CPU heartbeat] All RAM tests passed.\n");
    fflush(stdout);
    return 0;
}
