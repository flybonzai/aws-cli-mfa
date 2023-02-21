#!/usr/bin/env fish

# you MUST source this file to get the exports in your shell!
if test "$_" = source || test -n "$IS_SOURCED"
    set SOURCED 1
else
    set SOURCED 0
end

set -l REQUIREMENTS python3 aws jq

for requirement in $REQUIREMENTS
    if not command -v $requirement > /dev/null 2>&1
        echo "$requirement could not be found!"
        exit 0
    end
end

set -l PYCODE "
#INSERT_PYTHON_CODE_HERE
"

set -l RESPONSE (/usr/bin/env python3 -c "$PYCODE" $argv)

if string match -r "^usage" "$RESPONSE" > /dev/null 2>&1
    echo -E "$RESPONSE"
    exit 0
end

if not echo -E "$RESPONSE" | jq -e . > /dev/null 2>&1
    echo "JSON parsing failed:"
    echo -E "$RESPONSE"
    exit 1
end

set -l STS_CMD (echo -E "$RESPONSE" | jq -r ".sts_cmd // null") 
set -l OUTPUT (echo -E "$RESPONSE" | jq -r ".output // null" | string collect)

if not test "null" = "$STS_CMD"
    echo "$STS_CMD"
end

if not test "null" = "$OUTPUT"
    echo "$OUTPUT"
end

set -l ENVVARS (echo -E "$RESPONSE" | jq -r ".envvars // null")

if test "null" = "$ENVVARS"
    exit 0
end

set -l KEYS (echo -E "$RESPONSE" | jq -r ".envvars | keys[]")
if test (count $KEYS) -ge 0 -a $SOURCED -ne 1
    echo "You must source this file to get the exports in your shell"
    exit 1
end

for key in $KEYS
    set value (echo -E "$RESPONSE" | jq -r ".envvars.$key")
    set -x $key $value
    echo "Set env var: $key"
end