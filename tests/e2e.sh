#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), and where given its standard error, and exit status with
# the expected ones. The cases run inside a fixture tree built under $TMP.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
# With CLEAN_ENV=1 the binary gets only the variables in the ENVIRONMENT
# array (NAME=value words).
# If $WANT_ERR is set, standard error must equal it too.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    if [ "${CLEAN_ENV:-0}" = 1 ]; then
        env -i "${ENVIRONMENT[@]}" "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    else
        "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    fi
    local status=$?
    local err_ok=1
    if [ -n "${WANT_ERR+set}" ]; then
        printf '%s' "$WANT_ERR" > "$TMP/want_err"
        cmp -s "$TMP/want_err" "$TMP/err" || err_ok=0
    fi
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out" && [ "$err_ok" -eq 1 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        if [ "$err_ok" -eq 0 ]; then
            diff <(od -c "$TMP/want_err") <(od -c "$TMP/err") | sed 's/^/    stderr /' | head -20
        fi
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_both NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
check_both() {
    local name=$1 want_status=$2 want_out=$3
    local WANT_ERR=$4
    shift 4
    check "$name" "$want_status" "$want_out" "$@"
}


nl=$'\n'
syntax="The syntax of the command is incorrect.$nl"
bad_number="Invalid number.  Numeric constants are either decimal (17), hexadecimal (0x11), or octal (021).$nl"

usage_text=$(build_usage() {
    printf '%s\n' \
        'SET [prefix]' \
        'SET name=value' \
        'SET /A expression' \
        '' \
        'Lists environment variables, or evaluates an integer expression.' \
        '' \
        '  (nothing)      List every variable as name=value, sorted by name.' \
        '  prefix         List the variables whose names start with prefix' \
        '                 (ignoring case); ERRORLEVEL 1 if there are none.' \
        '  name=value     Accepted, but a program cannot change its caller'"'"'s' \
        '                 environment, so it has no lasting effect.' \
        '  /A expression  Evaluate with 32-bit integers and print the result.' \
        '                 Numbers: 17, 0x11 (hexadecimal), 021 (octal). Names' \
        '                 read environment variables (0 if undefined).' \
        '                 Operators, loosest first: ,  then = *= /= %= += -=' \
        '                 &= ^= |= <<= >>=  then |  ^  &  << >>  + -  * / %' \
        '                 then unary - + ! ~ and ( ).'
    printf '.'
}; build_usage)
usage_text=${usage_text%.}

# Help and version.
check_both "/? help"               0 "$usage_text" ''       '/?'
check      "-? after /a"           0 "$usage_text"          /a 1 '-?'
check      "--help"                0 "$usage_text"          --help
check      "--version"             0 $'set (loup-cmd-set) 0.1.0\n' --version

# Listing, in a known environment.
CLEAN_ENV=1
ENVIRONMENT=(zeta=1 Alpha=2 PATH=/usr/bin ALPHABET=3 _under=4 b=five 'SPACED=a b  c' 'EQ=x=y' EMPTY=)
check_both "list sorted by name"   0 $'Alpha=2\nALPHABET=3\nb=five\nEMPTY=\nEQ=x=y\nPATH=/usr/bin\nSPACED=a b  c\nzeta=1\n_under=4\n' '' 
check      "prefix ignores case"   0 $'Alpha=2\nALPHABET=3\n'           al
check      "exact name is a prefix" 0 $'PATH=/usr/bin\n'               PATH
check      "quoted prefix"         0 $'zeta=1\n'                        '"ZE"'
check_both "no match"              1 '' $'Environment variable nope not defined\n' nope
check_both "words joined"          1 '' $'Environment variable a b not defined\n'  a b
ENVIRONMENT=()
check_both "empty environment"     0 '' ''
CLEAN_ENV=0

# Assignments have no lasting effect and print nothing.
check_both "assignment"            0 '' ''                      X=1
check_both "quoted assignment"     0 '' ''                      '"X=a b"'
check_both "deletion"              0 '' ''                      X=
check_both "no name"               1 '' "$syntax"               =1
check_both "name starting with /"  1 '' "$syntax"               /x=1
check_both "/P not supported"      1 '' $'set /P (prompt for a value) is not supported by this version.\n' /P 'x=Name? '

# set /a: the result is printed. cmd's ERRORLEVELs for errors are
# 1073750988-1073750993; Linux keeps the low 8 bits, 204-209.
check_both "addition"              0 $'3\n' ''                   /a 1+2
check      "words joined"          0 $'14\n'                     /A 2 + 3 '*' 4
check      "glued /a"              0 $'20\n'                     '/a(2+3)*4'
check      "-a"                    0 $'-3\n'                     -a -7/2
check      "remainder sign"        0 $'-1\n'                     /a -7%2
check      "hexadecimal, octal"    0 $'48\n'                     /a 0x1F+021
check      "0xFFFFFFFF is -1"      0 $'-1\n'                     /a 0xFFFFFFFF
check      "wrap-around"           0 $'-2147483648\n'            /a 2147483647+1
check      "shifts"                0 $'-4\n'                     /a '-8>>1'
check      "shift count mod 32"    0 $'2\n'                      /a '1<<33'
check      "bitwise"               0 $'11\n'                     /a '6&3|8^1'
check      "unary"                 0 $'1\n'                      /a '!0*~-1+!!7'
check      "assignments, comma"    0 $'11\n'                     /a 'x=5, y=x*2, y+1'
check      "compound assignment"   0 $'17\n'                     /a 'x=1, x<<=4, x|=1'
check      "chained assignment"    0 $'6\n'                      /a 'a=b=3, a+b'
check      "quotes are ignored"    0 $'7\n'                      /a '"1+2*3"'
check      "undefined variable"    0 $'1\n'                      /a 'no_such_variable_x+1'
N=41 check "variable, any case"    0 $'42\n'                     /a n+1
HEXV=0x10 check "hexadecimal variable" 0 $'16\n'                 /a hexv
REFV=valv VALV=7 check "variable naming a variable" 0 $'14\n'    /a 'refv*2'
TEXTV='a b' check "text variable is 0" 0 $'1\n'                  /a textv+1
OCTV=08 check_both "invalid variable value" 207 '' "$bad_number" /a octv

# set /a errors.
check_both "divide by zero"        209 '' $'Divide by zero error.\n'   /a 1/0
check_both "remainder by zero"     209 '' $'Divide by zero error.\n'   /a 5%0
check_both "unbalanced ("          204 '' $'Unbalanced parenthesis.\n' /a '(1+2'
check_both "unbalanced )"          204 '' $'Unbalanced parenthesis.\n' /a '1+2)'
check_both "missing operand"       205 '' $'Missing operand.\n'        /a 1+
check_both "assign to a number"    205 '' $'Missing operand.\n'        /a 3=4
check_both "missing operator"      206 '' $'Missing operator.\n'       /a 1 2
check_both "invalid octal"         207 '' "$bad_number"                /a 08
check_both "too big"               208 '' $'Invalid number.  Numbers are limited to 32-bits of precision.\n' /a 2147483648
check_both "empty expression"      1   '' "$syntax"                    /a

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
