import random


# Parameters
NUM_BITS = 1024
NUM_ADJACENT = 3

SELF_TABU_CYCLES = 1024
ADJ_TABU_CYCLES = 512

NUM_CANDIDATES = 32
TOTAL_CYCLES = 5000

RANDOM_SEED = 42


class TabuRing:

    def __init__(self, num_bits, length):
        self.num_bits = num_bits
        self.length = length

        self.buffer = [None] * length
        self.mask = [False] * num_bits
        self.position = [-1] * num_bits

        self.ptr = 0

    def tick(self):
        bit = self.buffer[self.ptr]

        if bit is not None:
            self.mask[bit] = False
            self.position[bit] = -1
            self.buffer[self.ptr] = None

        self.ptr = (self.ptr + 1) % self.length

    def restart(self, bit):
        if self.mask[bit]:
            old_position = self.position[bit]
            self.buffer[old_position] = None

        self.buffer[self.ptr] = bit
        self.mask[bit] = True
        self.position[bit] = self.ptr

    def is_tabu(self, bit):
        return self.mask[bit]


def generate_adjacency(num_bits, num_adjacent):
    adjacency = []

    for bit in range(num_bits):
        candidates = list(range(num_bits))
        candidates.remove(bit)

        adjacency.append(
            random.sample(candidates, num_adjacent)
        )

    return adjacency


def get_available_candidates(candidates, self_tabu, adj_tabu):
    return [
        bit for bit in candidates
        if not self_tabu.is_tabu(bit)
        and not adj_tabu.is_tabu(bit)
    ]


def main():

    random.seed(RANDOM_SEED)

    adjacency = generate_adjacency(
        NUM_BITS,
        NUM_ADJACENT
    )

    self_tabu = TabuRing(
        NUM_BITS,
        SELF_TABU_CYCLES
    )

    adj_tabu = TabuRing(
        NUM_BITS,
        ADJ_TABU_CYCLES
    )

    selected_history = []

    for cycle in range(TOTAL_CYCLES):

        self_tabu.tick()
        adj_tabu.tick()

        candidates = random.sample(
            range(NUM_BITS),
            min(NUM_CANDIDATES, NUM_BITS)
        )

        available = get_available_candidates(
            candidates,
            self_tabu,
            adj_tabu
        )

        if not available:
            continue

        selected = random.choice(available)

        selected_history.append(selected)

        self_tabu.restart(selected)

        for adjacent_bit in adjacency[selected]:
            adj_tabu.restart(adjacent_bit)

        if cycle < 20 or cycle % 500 == 0:
            print(
                f"Cycle {cycle:5d} | "
                f"Selected: {selected:4d} | "
                f"Adjacent: {adjacency[selected]}"
            )


if __name__ == "__main__":
    main()