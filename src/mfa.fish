#!/user/bin/env fish

# you MUST source this file to get the exports in your shell!
if test "$_" = source && set -q FISH_VERSION
    set SOURCED true
else
    set SOURCED false
end

set REQUIRED python3 aws jq

for program in $REQUIRED
    if not command -v $program &>1
        echo "$program could not be found!"
        if $SOURCED
            exit 0
        end
    end
end

set PYCODE (cat aws_cli_mfa.py | string collect)

set RESPONSE (set COLUMNS 999 /usr/bin/env python3 -c "$PYCODE" $argv)

if string match "usage*" $RESPONSE
    echo -E "$RESPONSE"
    if $SOURCED
        exit 0
    end
end

if ! echo -E $RESPONSE | jq -e . &> /dev/null
    echo "JSON parsing failed:"
    echo -E $RESPONSE
    if $SOURCED
        exit 1
    end
end

set STS_CMD = (echo -E $RESPONSE | jq -r .sts_cmd)
set OUTPUT = (echo -E $RESPONSE | jq -r .output)

if not test -z $STS_CMD
    echo $STS_CMD
end

if not test -z $OUTPUT; and test $OUTPUT != "null"
    echo $OUTPUT
end

if test (echo -E $RESPONSE | jq -r '.envvars') = "null"; and $SOURCED
    exit 0
end

set KEYS (echo -E $RESPONSE | jq -r '.envvars | keys[]')

if test (count $KEYS) -ge 0; and not $SOURCED
    echo "You must source this file to get the exports in your shell"
    exit 1
end

for key in $KEYS
    value = (echo -E $RESPONSE | jq -r ".envvars.$key")
    set -gX $key $value
    echo "Set env var: $key"
end

# [[ ${#KEYS[@]} -ge 0 ]] && [[ $SOURCED -ne 1 ]] &&
#     echo "You must source this file to get the exports in your shell" &&
#     exit 1

# for key in "${KEYS[@]}" ; do
#     value=$(echo -E "$RESPONSE" | jq -r ".envvars.$key")
#     export $key=$value
#     echo "Set env var: $key"
# done