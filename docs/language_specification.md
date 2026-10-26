# MiniC Language Specification

**MiniC** is a statically-typed, block-structured imperative programming language designed as a concise subset of C with Pascal/Modula-style variable and constant blocks.

---

## 1. Lexical Structure

### 1.1. Comments
- **Single-line comments**: Begin with `//` and extend to the end of the line.
- **Multi-line comments**: Enclosed within `/* ... */`. Unclosed block comments are reported as lexical errors with line attribution.

### 1.2. Keywords
All keywords are reserved and case-sensitive:
`var`, `const`, `int`, `if`, `else`, `while`, `do`, `for`, `print`, `read`.

### 1.3. Identifiers
- Pattern: `[a-zA-Z_][a-zA-Z0-9_]*`
- Maximum length: **32 characters**. Identifiers exceeding 32 characters trigger a lexical error.

### 1.4. Integer Literals
- Pattern: `[0-9]+`
- Range: 32-bit signed integer (`0` to `2,147,483,647` for positive literals; unary `-` handles negative values). Literals exceeding `2147483647` trigger a lexical overflow error.

### 1.5. String Literals
- Enclosed in double quotes: `"([^"\n\\]|\\.)*"`
- Supports escape sequences (such as `\n`, `\t`, `\"`). Unterminated strings before newline or EOF trigger a lexical error.

---

## 2. Context-Free Grammar (BNF)

```bnf
<program>          ::= ID "(" ")" "{" <declarations> <statement_list> "}"

<declarations>     ::= <declarations> "var" <tipo> <var_list> ";"
                     | <declarations> "const" <tipo> <const_list> ";"
                     | ε

<tipo>             ::= "int"

<var_list>         ::= ID
                     | <var_list> "," ID

<const_list>       ::= ID "=" <expression>
                     | <const_list> "," ID "=" <expression>

<statement_list>   ::= <statement_list> <statement>
                     | ε

<statement>        ::= ID "=" <expression> ";"
                     | "{" <statement_list> "}"
                     | "if" "(" <expression> ")" <statement> "else" <statement>
                     | "if" "(" <expression> ")" <statement>
                     | "while" "(" <expression> ")" <statement>
                     | "do" <statement> "while" "(" <expression> ")" ";"
                     | "for" "(" ID "," <expression> "," <expression> ")" <statement>
                     | "print" "(" <print_list> ")" ";"
                     | "read" "(" <read_list> ")" ";"

<print_list>       ::= <print_item>
                     | <print_list> "," <print_item>

<print_item>       ::= <expression>
                     | STRING

<read_list>        ::= ID
                     | <read_list> "," ID

<expression>       ::= <arithExpression>
                     | <logicExpression>

<arithExpression>  ::= <arithExpression> "+" <arithExpression>
                     | <arithExpression> "-" <arithExpression>
                     | <arithExpression> "*" <arithExpression>
                     | <arithExpression> "/" <arithExpression>
                     | "(" <logicExpression> "?" <arithExpression> ":" <arithExpression> ")"
                     | "-" <arithExpression>
                     | "(" <arithExpression> ")"
                     | ID
                     | NUM

<logicExpression>  ::= <arithExpression> "<"  <arithExpression>
                     | <arithExpression> "<=" <arithExpression>
                     | <arithExpression> ">"  <arithExpression>
                     | <arithExpression> ">=" <arithExpression>
                     | <arithExpression> "==" <arithExpression>
                     | <arithExpression> "!=" <arithExpression>
                     | "!" <arithExpression>
```

### Operator Precedence & Associativity
From lowest to highest precedence:
1. Binary `+`, `-` (left-associative)
2. Binary `*`, `/` (left-associative)
3. Unary `-` (`UMINUS`, non-associative)

Note: The dangling-`else` shift/reduce conflict in `if`/`if-else` is resolved via Bison's default shift preference (`%expect 1`), binding `else` to the innermost `if`.

---

## 3. Semantic Rules

1. **Unique Declarations**: Every variable (`VARIABLE`) and constant (`CONSTANTE`) must be declared uniquely within the program's declaration block. Redeclaring an existing identifier emits a semantic error.
2. **Declaration Before Use**: Any identifier referenced in an expression, assignment, `read`, or `for` loop iterator must be previously declared.
3. **Constant Immutability**: Identifiers declared with `const` cannot be modified via assignment (`=`), `read(...)`, or as the iterator variable of a `for` loop.
4. **Compile-Time Constant Evaluation**: Expressions assigned to `const int` declarations are folded at compile time and emitted directly as static `.word` initializers in the `.data` segment. Division by zero in constant expressions is caught at compile time.
