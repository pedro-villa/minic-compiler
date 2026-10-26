# MiniC to MIPS Compiler

[![CI](https://github.com/pedro-villa/minic-compiler/actions/workflows/ci.yml/badge.svg)](https://github.com/pedro-villa/minic-compiler/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

An ahead-of-time optimizing compiler for **MiniC**—a structured imperative subset of C—that generates executable **MIPS R2000/R3000 assembly** simulated via the [MARS MIPS Simulator](https://courses.missouristate.edu/KenVollmar/mars/).

Built using **Flex** (lexical analysis) and **Bison** (LALR(1) syntax and semantic analysis) in ANSI C.

---

## Language Features

- **Types & Data Storage**: 32-bit signed integers (`int`), escaped string literals, and static `.data` segment allocation.
- **Variables & Constants**:
  - Mutable variables: `var int i, j, k;` (implicitly initialized to `0`).
  - Compile-time evaluated constants: `const int MAX = (10 + 5) * 2 / 3;` (folded during compilation).
- **Control Flow Statements**:
  - Conditional branching: `if (condition) ... else ...`
  - Pre-test loops: `while (condition) ...`
  - Post-test loops: `do ... while (condition);`
  - Bounded iteration loops: `for (iterVar, minExpr, maxExpr) ...`
- **Operators**:
  - Arithmetic: `+`, `-`, `*`, `/`, unary `-`.
  - Relational & Equality: `<`, `<=`, `>`, `>=`, `==`, `!=`.
  - Logical: `!` (boolean negation).
  - Conditional: Ternary operator `(cond ? expr1 : expr2)`.
- **I/O Subsystem**:
  - Formatted output: `print("Value: ", x, "\n");` via MIPS system calls `1` (`print_int`) and `4` (`print_string`).
  - Interactive input: `read(a, b);` via MIPS system call `5` (`read_int`).
- **Diagnostics & Recovery**: Comprehensive lexical, syntactic, and semantic error detection with line number attribution and panic-mode statement recovery (`error ;`).

---

## Project Structure

```text
minic-compiler/
├── docs/                        # Formal grammar and compiler architecture docs
│   ├── architecture.md
│   └── language_specification.md
├── examples/                    # Functional test suite and error test cases
│   ├── pruebaErroresExhaustiva.miniC
│   └── pruebaFuncionalidades.miniC
├── src/                         # Compiler frontend & code generation source
│   ├── expresionInfo.h          # Expression IR struct (code list + constant value)
│   ├── listaCodigo.c / .h       # 3-address MIPS quadruple linked list
│   ├── listaSimbolos.c / .h     # Symbol table linked list
│   ├── main.c                   # CLI entry point
│   ├── miniC.l                  # Flex lexical specification
│   └── miniC.y                  # Bison parser & syntax-directed MIPS translation
├── tools/
│   └── Mars4_5.jar              # MARS MIPS Assembler and Runtime Simulator v4.5
├── .gitignore
├── LICENSE                      # MIT License
├── makefile                     # Build and test orchestration
└── README.md
```

---

## Prerequisites

- **GCC** (or Clang)
- **Flex** (>= 2.6)
- **Bison** (>= 3.0)
- **Make**
- **Java JRE** (>= 8, to execute the MARS simulator)

On Ubuntu / Debian:
```bash
sudo apt update && sudo apt install -y build-essential flex bison default-jre
```

---

## Build & Usage

### 1. Build the Compiler
```bash
make
```

### 2. Compile a MiniC Program
```bash
./miniC examples/pruebaFuncionalidades.miniC > output.asm
```

### 3. Simulate with MARS
```bash
# Run in headless CLI mode:
java -jar tools/Mars4_5.jar nc output.asm

# Or open the interactive MARS GUI:
java -jar tools/Mars4_5.jar output.asm
```

### 4. Run the Automated Test Suite
```bash
make test
```

### 5. Clean Generated Files
```bash
make clean
```

---

## Documentation

- [Language Specification & Grammar](docs/language_specification.md)
- [Compiler Architecture & Code Generation](docs/architecture.md)

---

## Acknowledgments

- [MARS (MIPS Assembler and Runtime Simulator)](https://courses.missouristate.edu/KenVollmar/mars/) was developed by Pete Sanderson and Kenneth Vollmar at Missouri State University.

---

## Authors

- **Sergio Lozano** ([@Gert2198](https://github.com/Gert2198))
- **Pedro Villa** ([@pedro-villa](https://github.com/pedro-villa))
