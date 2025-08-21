#!/bin/bash
TCNAME="${1}"

_D=$(dirname $(realpath ${0} ) )

# Create temp files
out=$(mktemp)
err=$(mktemp)

# Clean up on exit
trap "rm -f '$out' '$err'" EXIT

cd "${_D}"
cargo clean
if ! cargo ${TCNAME:+"+${TCNAME}"} clippy >"$out" 2>"$err"; then
	_RET=$?
	cat "$out"
	cat "$err" >&2
	exit $_RET
fi

cat "$out"
cat "$err" >&2
if grep -q "use of a disallowed macro \`macrolib::attrib_macro\`" "$out" "$err"; then
	exit 125
else
	exit 0
fi
