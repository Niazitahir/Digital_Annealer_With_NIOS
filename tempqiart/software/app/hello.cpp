#include <stdio.h>
#include <stdint.h>
#include "system.h"
#include "io.h"

#define QUBO_BANK_WORDS 2048u
#define QUBO_DATA_MASK 0x3FFu
#define QUBO_WORD_BYTES 4u

int main(void)
{
    printf("Hello from Nios V!\n");
    printf("Testing QUBO bank 0 (%u words)...\n", QUBO_BANK_WORDS);

    for (uint32_t word = 0; word < QUBO_BANK_WORDS; ++word) {
        if ((word & 0xFFu) == 0u) {
            printf("Write progress: word %lu\n", (unsigned long)word);
            fflush(stdout);
        }

        IOWR_32DIRECT(MM_BRIDGE_0_BASE,
                      word * QUBO_WORD_BYTES,
                      word & QUBO_DATA_MASK);
    }

    printf("Write phase complete. Starting read phase.\n");
    fflush(stdout);

    for (uint32_t word = 0; word < QUBO_BANK_WORDS; ++word) {
        if ((word & 0xFFu) == 0u) {
            printf("Read progress: word %lu\n", (unsigned long)word);
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

    printf("QUBO bank 0 test passed.\n");
    return 0;
}
