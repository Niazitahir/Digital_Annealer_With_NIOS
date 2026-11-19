# Copilot instructions

## Project and layout

This is an Intel Quartus FPGA design intended for the Terasic Stratix 10
sensor board. It implements a highly parallel binary optimizer: bit-sieve
engines propose bit flips, and the design selects and applies candidates to
search for low-energy binary solutions. It is a heuristic search; do not
assume that every run proves a global optimum.

- `tempqiart/nios_path.qpf` and `.qsf` define the board project (Quartus
  project version 25.1, Stratix 10 device `1ST040EH2F35E2VG`).
  `tempqiart/tempqiart_top.v` connects the board clocks and reset, Platform
  Designer system, and `BitSieve_256` Avalon interface.
- `tempqiart/tempqiart.qsys` is the Platform Designer system. The associated
  `.ip` files and `ip/` and `tempqiart/` generated subdirectories provide
  Nios V, memories, clocking, and other Intel IP.
- `tempqiart/Verilog/synthesis/BitSieve_256.v` is the optimizer's
  hardware-facing wrapper. `tempqiart/Verilog/hdl/` contains the datapath,
  FSM, twin engines, candidate selection, tabu masking, and related logic.
  Despite the filename, `hdl/top.v` defines `bit_sieve_engine_25`, whose
  current default configuration has 2048 logical lanes.
- `tempqiart/Verilog/memoy/` (spelling intentional) contains memory
  initialization data. `tempqiart/Verilog/test/` contains Verilog
  testbenches; `tempqiart/Verilog/simulation/` contains the ModelSim project
  and simulation script. `tempqiart/Verilog/synthesis/BitSieve_256.qpf` is
  a separate synthesis project with a different device and top-level entity.
- `tempqiart/software/app/hello.cpp` is the Nios V application;
  `uart_sender.py` and `uart_test_simple.py` are host communication tools.
  `software/bsp/` contains the BSP used by the app. `Analysis/` contains
  Python analysis and simulation scripts and result artifacts.

## Changes and conventions

- Follow the surrounding Verilog-2001 style in `.v` RTL and SystemVerilog
  style in board-level files. Preserve parameterized widths, explicit signed
  arithmetic and sign extension, clock/reset behavior, and nonblocking
  assignments for sequential state. Check cycle latency, valid/enable
  alignment, and resource/timing impact when changing parallel datapaths.
- Keep the candidate selection, energy/field updates, tabu state, and
  active-variable masking consistent. Coordinate changes to the Avalon
  word-addressed hardware interface with the Nios byte offsets and host
  protocol; see `BitSieve_256.v`, `tempqiart_top.v`, `hello.cpp`, and the
  host scripts.
- Treat Platform Designer output, BSP, IP-generated files, Quartus output,
  simulation work libraries, logs, backups, and reports as generated or
  historical artifacts even when tracked. Prefer editing source RTL and IP
  configuration, and regenerate dependent output using Intel tools when
  appropriate. Do not make unrelated changes to generated files.
- Preserve the `.qsf` source and pin assignments, IP dependencies, relative
  paths, and memory initialization formats. Add new synthesis sources to the
  relevant Quartus project and simulation sources to the relevant simulator
  project as needed. Check for machine-specific or missing paths before
  assuming a project is portable.

## Build, run, and test

- For the board design, open `tempqiart/nios_path.qpf` in a compatible
  Quartus Prime installation with Stratix 10 support and required IP, or run
  `quartus_sh --flow compile nios_path` from `tempqiart/`. Compilation
  produces output under `tempqiart/output_files/`. Review compilation and
  timing reports; program the resulting board-compatible image using Quartus
  Programmer and the connected board/JTAG cable.
- Build the embedded app using the Intel Nios V toolchain and CMake in a
  Nios V shell: from `tempqiart/software/app/`, configure with
  `cmake -S . -B build` and build with `cmake --build build`. The app uses
  `../bsp` and requires the RISC-V cross compiler, `niosv-stack-report`, and
  `elf2hex`. Hardware changes may require regenerating the BSP.
- With the board programmed and the Nios application running, run
  `python uart_sender.py` from `tempqiart/software/app/` for JTAG UART
  communication. See `software/app/README.md` for inputs, options, and
  requirements, and `software/app/ubuntu/README.md` for the Linux hardware
  test. These scripts require Intel JTAG tooling and real hardware.
- The test framework is Verilog testbenches run with ModelSim/Questa, not a
  repository-wide unit-test runner. Open
  `tempqiart/Verilog/simulation/BitSieve25Test.mpf` in ModelSim, then run
  `do run_sim.do` from that simulation directory; the script compiles the
  project and runs `tb_bit_sieve_engine_25`. Other `tb_*.v` files provide
  focused module tests; compile the selected bench and its dependencies and
  inspect its PASS/FAIL output. Some benches use `$finish` on failure, so an
  exit code alone may not indicate success. Simulator libraries, IP, and
  referenced memory files must be available; existing projects or older
  benches may need path or interface updates.
- Use focused simulation for changed RTL and test reset, signed arithmetic,
  boundary widths, and cycle alignment where relevant. Report unavailable
  Quartus, simulator, Nios tools, or hardware rather than claiming those
  builds or tests passed.
