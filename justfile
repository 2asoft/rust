DEFAULT_TCNAME := "clippy_i13521"

check:
    #!/usr/bin/env bash
    set -ex
    # Create temp files
    out=$(mktemp)
    err=$(mktemp)

    # Clean up on exit
    trap "rm -f '$out' '$err'" EXIT

    if ! nice ./x check >"$out" 2>"$err"; then
        _RET=$?
        #cat "$out" | rg -v '^Scraping '
        cat "$err" >&2
        exit $_RET
    fi

build tcname=DEFAULT_TCNAME:
    #!/usr/bin/env bash
    set -ex
    # Create temp files
    out=$(mktemp)
    err=$(mktemp)

    # Clean up on exit
    trap "rm -f '$out' '$err'" EXIT

    rustup toolchain uninstall {{tcname}} || true
    if ! nice ./x install rustc cargo std clippy >"$out" 2>"$err"; then
        _RET=$?
        #cat "$out" | rg -v '^Scraping '
        cat "$err" >&2
        exit $_RET
    fi
    rustup toolchain link {{tcname}} ../built_toolchain 2>&1 >/dev/null

test tcname=DEFAULT_TCNAME:
    #!/usr/bin/env bash
    set -ex
    nice ./repro/test.sh {{tcname}}

repro tcname=DEFAULT_TCNAME:
    #!/usr/bin/env bash
    set -ex
    cd ./repro
    nice cargo build
