#!/usr/bin/env fish

set BASE_DIR (dirname (status -f))

function test_program
    set TEST_SCRIPT $argv[1]
    set TEST_MODE $argv[2]
    set TEST_ARG $argv[3]
    set TEST_EXPECTED $argv[4]
    # https://github.com/fish-shell/fish-shell/issues/2314#issuecomment-698645423
    #TEST_OUT=$($TEST_SHELL -c "$TEST_SCRIPT" ignored_argv0 $TEST_ARG)

    set tmpfile (mktemp)
    echo "$TEST_SCRIPT" >"$tmpfile"

    # Fish shell's '$_' variable doesn't behave the same when sourcing from a command 
    # substitution, so setting an environment variable is a hacky workaround
    if test "$TEST_MODE" = "source"
        set -x IS_SOURCED true
        set TEST_OUT (fish -c "source $tmpfile $TEST_ARG" | string collect)
        set -e IS_SOURCED
    else if test "$TEST_MODE" = "direct"
        chmod +x "$tmpfile"
        set TEST_OUT (fish -c "$tmpfile $TEST_ARG" | string collect)
    else if test "$TEST_MODE" = "envgrep"
        set -x IS_SOURCED true
        set TEST_OUT (fish -c "source $tmpfile $TEST_ARG; env | grep TEST_AWS_CLI_MFA" | string collect)
        set -e IS_SOURCED
    else
        echo "BAD TEST ARG!"
        return
    end

    rm "$tmpfile"

    if test "$TEST_OUT" = "$TEST_EXPECTED"
        echo "SUCCESS - $TEST_MODE: $TEST_ARG"
    else
        echo "$TEST_EXPECTED"
        echo "FAILURE - $TEST_MODE: $TEST_ARG: $TEST_OUT"
    end
end

set FISH_SCRIPT (sed "s/\"/\\\\\"/g" $BASE_DIR/test_sh.py | sed -e "/#INSERT_PYTHON_CODE_HERE/r /dev/stdin" $BASE_DIR/../src/mfa.fish | string split0)

test_program (string replace "python3" "python1" $FISH_SCRIPT | string split0) source python3 "python1 could not be found!"
test_program (string replace "python3" "python1" $FISH_SCRIPT | string split0) direct python3 "python1 could not be found!"
test_program (string replace "aws" "aws1" $FISH_SCRIPT | string split0) source aws "aws1 could not be found!"
test_program (string replace "aws" "aws1" $FISH_SCRIPT | string split0) direct aws "aws1 could not be found!"
test_program (string replace "jq" "jq1" $FISH_SCRIPT | string split0) source jq "jq1 could not be found!"
test_program (string replace "jq" "jq1" $FISH_SCRIPT | string split0) direct jq "jq1 could not be found!"
test_program $FISH_SCRIPT source usage "usage instructions"
test_program $FISH_SCRIPT direct usage "usage instructions"
test_program $FISH_SCRIPT source notjson "JSON parsing failed:
not json"
test_program $FISH_SCRIPT direct notjson "JSON parsing failed:
not json"
test_program $FISH_SCRIPT source sts "aws sts something something"
test_program $FISH_SCRIPT direct sts "aws sts something something"
test_program $FISH_SCRIPT source output "aws sts something something
output across
multiple lines"
test_program $FISH_SCRIPT direct output "aws sts something something
output across
multiple lines"
test_program $FISH_SCRIPT source envvars "sts
output
Set env var: TEST_AWS_CLI_MFA_1
Set env var: TEST_AWS_CLI_MFA_2"
test_program $FISH_SCRIPT direct envvars "sts
output
You must source this file to get the exports in your shell"
test_program $FISH_SCRIPT envgrep envvars "sts
output
Set env var: TEST_AWS_CLI_MFA_1
Set env var: TEST_AWS_CLI_MFA_2
TEST_AWS_CLI_MFA_1=val1
TEST_AWS_CLI_MFA_2=val2"