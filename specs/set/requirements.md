# Requirements: set

## Introduction

`set` is the cmd.exe built-in that lists, assigns and computes environment
variables. This repository recreates its listing forms and its `/A`
arithmetic in Loup for Linux, with cmd's operators, precedence, 32-bit
integer semantics, messages and ERRORLEVELs. A program cannot change its
parent's environment, so assignments have no lasting effect and `set /a`
prints its result.

## Requirements

### Requirement 1: Listing

**User Story:** As a cmd user, I want to see environment variables.

#### Acceptance Criteria

1. WHEN set is run without arguments, THE program SHALL print every
   variable as `NAME=value`, one per line, sorted by name ignoring case.
2. WHEN set is given a text without `=`, THE program SHALL print the
   variables whose names start with it, ignoring case; WHEN there are none
   it SHALL print `Environment variable TEXT not defined` on standard error
   and exit with status 1.
3. THE program SHALL join its arguments with spaces and read a quoted
   argument from after its first quote to its last one.
4. THE program SHALL hide names that start with `=`.

### Requirement 2: Assignment

**User Story:** As a script author, I want `set NAME=value` to be accepted.

#### Acceptance Criteria

1. WHEN set is given `NAME=value`, THE program SHALL print nothing and exit
   with status 0.
2. WHEN the name is empty, or starts with `/` outside quotes, THE program
   SHALL print `The syntax of the command is incorrect.` and exit with 1.
3. WHEN `/P` is given, THE program SHALL say that it is not supported and
   exit with status 1.

### Requirement 3: Arithmetic

**User Story:** As a cmd user, I want `set /a` to compute integer
expressions exactly as cmd does.

#### Acceptance Criteria

1. WHEN `/A` (or `/a`, `-a`, or glued `/aEXPR`) is given, THE program SHALL
   evaluate the rest of the arguments as an expression and print its value.
2. THE program SHALL compute with 32-bit signed integers that wrap around,
   division truncating toward zero and remainders taking the dividend's
   sign.
3. THE program SHALL read decimal constants up to 2147483647, `0x`
   hexadecimal and `0` octal constants up to 32 bits.
4. THE program SHALL support, from the loosest to the tightest: `,`;
   `= *= /= %= += -= &= ^= |= <<= >>=` (right to left); `|`; `^`; `&`;
   `<< >>`; `+ -`; `* / %`; unary `- + ! ~`; parentheses.
5. WHEN an expression names a variable, THE program SHALL use the value
   assigned earlier in the expression, else the environment's (ignoring
   case), else 0.
6. THE program SHALL ignore quotes in an expression.

### Requirement 4: Arithmetic errors

**User Story:** As a script author, I want cmd's messages and ERRORLEVELs.

#### Acceptance Criteria

1. WHEN parentheses do not balance, THE program SHALL print
   `Unbalanced parenthesis.` and exit with 1073750988.
2. WHEN an operand is missing, THE program SHALL print `Missing operand.`
   and exit with 1073750989.
3. WHEN two operands follow each other, or an unknown operator appears, THE
   program SHALL print `Missing operator.` and exit with 1073750990.
4. WHEN a constant is malformed, THE program SHALL print cmd's
   `Invalid number.` message about the number forms and exit with
   1073750991; WHEN it is too large, the one about 32 bits, with
   1073750992.
5. WHEN a division or remainder has a zero divisor, THE program SHALL print
   `Divide by zero error.` and exit with 1073750993.
6. WHEN `/A` has no expression, THE program SHALL print
   `The syntax of the command is incorrect.` and exit with 1.
