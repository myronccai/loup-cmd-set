# loup-cmd-set

The cmd.exe `set` command recreated in [Loup](https://code-craft.ai/references/loup):
list environment variables and evaluate `set /a` integer arithmetic with
cmd's operators, precedence, 32-bit semantics, messages and ERRORLEVELs,
on Linux.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary. Its centre is a
Pratt parser and evaluator for cmd's expression language
([`source/commands/arith.loup`](source/commands/arith.loup)). It carries the
shared Windows code in [`source/win/`](source/win/), copied from
[loup-cmd-type](https://github.com/myronccai/loup-cmd-type).

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. The full release is at
<https://code-craft.ai/loup/download>, and commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                     # native binary: build/set
make ci                        # check, unit tests, build, end-to-end tests
make run ARGS="/a 6*7"         # run from source with loup run
```

Quote expressions that contain `*`, `<`, `>`, `|`, `&`, `(` or spaces so
that the Linux shell passes them through.

```text
$ env -i HOME=/home/ana LANG=C.UTF-8 PATH=/usr/bin:/bin Path2=x build/set
HOME=/home/ana
LANG=C.UTF-8
PATH=/usr/bin:/bin
Path2=x
$ env -i HOME=/home/ana LANG=C.UTF-8 PATH=/usr/bin:/bin Path2=x build/set pa
PATH=/usr/bin:/bin
Path2=x
$ build/set nosuch; echo "ERRORLEVEL $?"
Environment variable nosuch not defined
ERRORLEVEL 1
$ build/set /a '(1+2)*0x10 - 017'
33
$ build/set /a 'x=6, y=x<<2, x*y'
144
$ build/set /a 2147483647+1
-2147483648
$ WIDTH=80 build/set /a 'width/3, width%3'
2
$ build/set /a '-7/2, -7%2'
-1
$ build/set /a 1/0; echo "ERRORLEVEL $?"
Divide by zero error.
ERRORLEVEL 209
$ build/set /a 09; echo "ERRORLEVEL $?"
Invalid number.  Numeric constants are either decimal (17), hexadecimal (0x11), or octal (021).
ERRORLEVEL 207
$ build/set /a '(1+2'; echo "ERRORLEVEL $?"
Unbalanced parenthesis.
ERRORLEVEL 204
$ build/set --version
set (loup-cmd-set) 0.1.0
```

| Command line | Does |
|---|---|
| `set` | list every variable as `NAME=value`, sorted by name ignoring case |
| `set PREFIX` | list the variables whose names start with `PREFIX` (ignoring case); ERRORLEVEL 1 and `Environment variable PREFIX not defined` if none |
| `set NAME=value`, `set "NAME=value"` | accepted, prints nothing (see below) |
| `set /a EXPRESSION` | evaluate and print the result |
| `set /?` | a summary of the syntax |

The arguments are joined with spaces, as cmd sees the rest of its command
line. `set /a` follows cmd's expression language:

- **Integers** are 32-bit signed and wrap around on overflow. Constants are
  decimal (`17`, at most 2147483647), hexadecimal (`0x11`) or octal (`021`);
  hexadecimal and octal may use all 32 bits (`0xFFFFFFFF` is -1).
- **Variables** are names read from the environment, ignoring case; an
  undefined one is 0. A value is read as a number (`0x10`, `-3`), or, if it
  is a single name, as that variable's value; other text is 0.
- **Operators**, from the loosest to the tightest:

  | Operators | |
  |---|---|
  | `,` | evaluate both, keep the right value |
  | `=` `*=` `/=` `%=` `+=` `-=` `&=` `^=` `\|=` `<<=` `>>=` | assignment, right to left |
  | `\|` | bitwise or |
  | `^` | bitwise exclusive or |
  | `&` | bitwise and |
  | `<<` `>>` | shifts (arithmetic right shift; the count uses its low 5 bits) |
  | `+` `-` | addition, subtraction |
  | `*` `/` `%` | multiplication, division (truncates), remainder (sign of the dividend) |
  | `-` `+` `!` `~` | unary minus and plus, logical not, bitwise not |
  | `(` `)` | grouping |

- Quotes in an expression are ignored. The printed value is the value of
  the whole expression (the last one after commas).

Exit status (ERRORLEVEL): `0` on success; `1` when no variable matches a
prefix or for a syntax error; for `set /a` errors cmd's own values:

| Error | ERRORLEVEL | Seen on Linux |
|---|---|---|
| `Unbalanced parenthesis.` | 1073750988 | 204 |
| `Missing operand.` | 1073750989 | 205 |
| `Missing operator.` | 1073750990 | 206 |
| `Invalid number.  Numeric constants are ...` | 1073750991 | 207 |
| `Invalid number.  Numbers are limited to 32-bits of precision.` | 1073750992 | 208 |
| `Divide by zero error.` | 1073750993 | 209 |

## Differences from the original

- A program cannot change its parent's environment, so `set NAME=value`
  has no lasting effect, and assignments inside `set /a` last only for
  that expression. `set /a` prints its result, as cmd does at the prompt
  (followed by a newline here).
- Linux keeps only the low 8 bits of an exit status, so the `set /a` error
  ERRORLEVELs arrive as 204-209 (the program returns cmd's full values).
- `set /P` (prompt for a value) is not implemented: it would read standard
  input and then have no lasting effect.
- Variable names are case-sensitive on Linux: lookups try the exact name,
  then any name that differs only in case.
- The environment is read from `/proc/self/environ` (Loup 1.26.0 cannot
  list it otherwise), so this program needs Linux.
- How cmd reads a variable whose value is not a plain number (another
  name, text, `5+3`) is not documented; here a value starting with a number
  is that number, a single name is followed (up to 16 levels) and anything
  else is 0. Decimal constants beyond 2147483647 are errors, so the most
  negative number is written `-2147483647-1`.
- cmd's dynamic variables (`%CD%`, `%RANDOM%`, `%ERRORLEVEL%`, ...) do not
  exist; the shell expands `$VAR`, not `%VAR%`.
- `/?` prints this project's own short summary, not Microsoft's help text.
  `--help` and `--version` as the only argument are series conventions.

## Layout

```text
source/main.loup               # entry point
source/appinfo.loup            # name, version, exit statuses
source/cli/args.loup           # set's command line: list, prefix, assignment, /A
source/cli/usage.loup          # /? and --version text
source/cli/app.loup            # run(): parse, run, exit status
source/commands/setcmd.loup    # run_set(): the four forms
source/commands/environ.loup   # the environment: parse, look up, sorted listing
source/commands/arith.loup     # set /a: tokenizer, Pratt parser and evaluator, errors
source/win/                    # shared Windows code: switches, wildcards, paths, messages
tests/*_test.loup              # unit tests (make test)
tests/e2e.sh                   # end-to-end tests of build/set (make e2e)
specs/set/                     # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.
