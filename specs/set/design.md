# Design: set

## Overview

`main()` passes `runtime.args()` to `cli.app.run`. `cli.args.parse_args`
uses the shared switch parser only for `/?`, `--help`, `--version` and
`--`, then classifies the joined arguments as a listing, a prefix, an
assignment or an `/A` expression. `commands.setcmd.run_set` reads the
environment (`commands.environ`) and either prints a listing or evaluates
the expression (`commands.arith`). The command module is `setcmd`, not
`set`, because `set` is a collection type name in Loup.

## Modules

| Module | Contents |
|---|---|
| `source/appinfo.loup` | name, version, exit statuses 0 and 1 |
| `source/cli/args.loup` | `Options` (mode and text), `parse_args`, `strip_quotes` |
| `source/cli/usage.loup` | `usage()` (the `/?` summary), `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, `run_set`, exceptions to status 1 |
| `source/commands/setcmd.loup` | `run_set`, `msg_not_defined` |
| `source/commands/environ.loup` | `EnvTable`, `parse_environ`, `read_environment`, `find_index`, `listing` |
| `source/commands/arith.loup` | messages and ERRORLEVELs, `tokenize`, `parse_number`, `wrap32`, `apply_binary`, `apply_unary`, `Machine`, `parse_expr`, `evaluate` |
| `source/win/` | the shared Windows code (only the switch parser and messages are used) |

## The environment

Loup 1.26.0 can read one variable (`env(name)`) but not list them, so
`read_environment` reads `/proc/self/environ` with `readText` (natively it
returns the bytes, NULs included) and `parse_environ` splits it at NUL and
at the first `=` after the first character. `find_index` tries the exact
name, then a case-insensitive match. `listing` filters by upper-case
prefix, hides `=` names, and sorts keys `UPPER<NUL>NAME=value` with a plain
comparison (a comparator that upper-cases costs about 5 KB per comparison
natively).

## The expression language

`tokenize` produces numbers (a digit, then letters and digits), operators
(longest match: `<<=`, `>>=`, `<<`, `>>`, `op=`, single characters) and
names (any other run without blanks or operator characters); blanks and
quotes separate tokens.

`parse_expr(m, min_power)` is a Pratt parser that evaluates as it parses:

1. Prefix position: a number (`parse_number`), a name (its value; the name
   is kept in `m.lvalue`), `(` expression `)`, or a unary operator applied
   to `parse_expr(m, 9)`. Anything else is `Missing operand.`
2. Infix loop: stop at the end or `)`; a token that is not an infix
   operator is `Missing operator.`; stop when the operator's power is below
   `min_power`. Powers: `,` 1, assignments 2, `|` 3, `^` 4, `&` 5, shifts 6,
   `+ -` 7, `* / %` 8. Left-associative operators parse their right side
   with power + 1; assignments with the same power (right to left) and
   only after a bare name (`m.lvalue`), else `Missing operand.`
3. A `)` left at the top level, or a `(` without one, is
   `Unbalanced parenthesis.`

Values are kept as 32-bit signed integers in Loup's 64-bit `int`:
`wrap32` masks to 32 bits and sign-extends after `+ - * / % << ~` and
unary minus; `& | ^ >>` keep sign-extended operands in range. Shift
counts use their low 5 bits, like x86. Errors are thrown as
`ValueError(message)` and caught in `evaluate`, which returns an `Outcome`
(value, error, assigned variables); `error_level` maps a message to cmd's
ERRORLEVEL.

`variable_value` looks in the expression's own assignments first, then the
environment: a value that starts with a number (optionally signed) is that
number, a single name is followed (up to 16 levels), anything else is 0.

## Differences from the original

- Assignments have no lasting effect (a child process cannot change its
  parent's environment); `set /a` prints its result with a newline.
- The `set /a` ERRORLEVELs are cmd's, but Linux shows their low 8 bits
  (204-209).
- `set /P` is not implemented.
- Variable lookups try the exact name, then any case.
- The environment comes from `/proc/self/environ` (Linux only).
- Variable values that are not numbers: see the README.
- `/?` prints this project's own summary, not Microsoft's help text.

## Error handling

Usage errors (`/P`, an empty name, an empty `/A`) print a message and give
status 1. `set /a` errors print cmd's message and return cmd's
ERRORLEVEL. An unexpected exception is printed and gives status 1.

## Testing

- `tests/args_test.loup`: the four forms, quotes, glued `/a`, `/P`, help.
- `tests/environ_test.loup`: parsing a NUL-separated block, lookups,
  sorted and filtered listings, the real environment.
- `tests/arith_test.loup`: tokens, constants, wrap-around, every operator,
  precedence and associativity, assignments, environment values, every
  error and its ERRORLEVEL.
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/e2e.sh`: the native binary with controlled environments
  (`env -i`), listing, assignments, `set /a` results and errors.
