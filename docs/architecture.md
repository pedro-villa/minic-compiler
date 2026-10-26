# Compiler Architecture & Code Generation

The MiniC compiler is a single-pass, syntax-directed translator written in C using **Flex** and **Bison**. Rather than materializing an explicit Abstract Syntax Tree (AST), it synthesizes intermediate MIPS quadruples bottom-up during LALR(1) parsing.

---

## 1. Compilation Pipeline

```text
Source (.miniC)
   │
   ▼
[Flex Lexer: src/miniC.l]
   │  Token stream + yylval (lexeme strings)
   ▼
[Bison Parser: src/miniC.y] ◄───► [Symbol Table: src/listaSimbolos.c]
   │  Syntax-directed translation
   ▼
[Intermediate Code Lists: src/listaCodigo.c]
   │  Concatenated quadruple lists (ExpresionInfo)
   ▼
[MIPS Emitter: imprimirLS() & imprimirLC()]
   │
   ▼
Target Assembly (.asm)
```

---

## 2. Core Data Structures

### 2.1. Symbol Table (`listaSimbolos.h` / `listaSimbolos.c`)
Implemented as a singly-linked list with a sentinel header node (`cabecera`). Each symbol entry (`Simbolo`) stores:
- `nombre`: Identifier name (or string literal content).
- `tipo`: Enum distinguishing `VARIABLE` (`1`), `CONSTANTE` (`2`), and `CADENA` (`3`).
- `valor`:
  - For `VARIABLE`: `0` (default static word initialization).
  - For `CONSTANTE`: The compile-time folded integer value.
  - For `CADENA`: The unique sequential string index (`_str0`, `_str1`, ...).

To avoid collisions with MIPS reserved instruction mnemonics (such as `b`, `div`, `sub`), all user identifiers are prefixed with an underscore (`_id`) in the generated `.data` and `.text` segments.

### 2.2. Intermediate Code List (`listaCodigo.h` / `listaCodigo.c`)
Each MIPS instruction or label is represented as a 4-tuple (`Operacion`):
```c
typedef struct {
    char *op;   // Opcode ("add", "lw", "beqz", or pseudo-op "etiq")
    char *res;  // Destination register or label target
    char *arg1; // First source operand
    char *arg2; // Second source operand
} Operacion;
```
Each grammar non-terminal representing an expression or statement synthesizes an `ExpresionInfo` object:
```c
typedef struct ExpresionInfoRep {
    ListaC codigo; // Linked list of MIPS operations
    int valor;     // Compile-time evaluated value (used when enDeclaraciones == true)
} * ExpresionInfo;
```
Code fragments from child subtrees are combined in $O(n)$ time via `concatenaLC(codigo1, codigo2)`.

---

## 3. Register Allocation

Temporary values are allocated from the pool of 10 caller-saved MIPS temporary registers (`$t0` through `$t9`):
- `char registros[10]` tracks occupancy (`0` = free, `1` = allocated).
- `obtenerReg()` scans for the lowest-indexed free register, marks it occupied, and returns a static pointer to its canonical name (`"$t0"`–`"$t9"`).
- `liberaReg(char *reg)` reclaims the register as soon as its value has been consumed by a parent instruction or stored to memory.

---

## 4. Code Generation Patterns

### 4.1. Arithmetic & Relational Operations
Binary operations evaluate both operands, emit the corresponding MIPS instruction (`add`, `sub`, `mul`, `div`, `slt`, `sle`, `sgt`, `sge`, `seq`, `sne`), reuse the left operand's register (`res1`) for the result, and immediately free the right operand's register (`res2`).

### 4.2. Control Flow Translation
Unique labels (`l0`, `l1`, ...) are generated monotonically via `siguienteEtiqueta()`.

- **`if-else` statement**:
  ```mips
      # <condition code -> reg_cond>
      beqz reg_cond, l_else
      # <then-branch code>
      b l_end
  l_else:
      # <else-branch code>
  l_end:
  ```

- **`do-while` loop**:
  ```mips
  l_start:
      # <body code>
      # <condition code -> reg_cond>
      beqz reg_cond, l_exit
      b l_start
  l_exit:
  ```

- **`for (id, minExpr, maxExpr)` loop**:
  Evaluates `minExpr` and initializes `_id`, evaluates `maxExpr` into a persistent register `resMax` for the duration of the loop, tests `bgt $t_iter, resMax, l_exit` on each iteration, executes the loop body, increments `_id` by `1` (`addi`), and jumps back to the loop header before freeing `resMax` at exit.

### 4.3. System Calls (MARS ABI)
- **Print Integer**: `li $v0, 1`, `move $a0, $tX`, `syscall`
- **Print String**: `li $v0, 4`, `la $a0, _strN`, `syscall`
- **Read Integer**: `li $v0, 5`, `syscall`, `sw $v0, _id`
- **Program Exit**: `li $v0, 10`, `syscall`
