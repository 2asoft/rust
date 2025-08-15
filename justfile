DEFAULT_TCNAME := "clippy_i13521"

build tcname=DEFAULT_TCNAME:
    #!/usr/bin/env bash
    set -ex
    rustup toolchain uninstall {{tcname}} || true
    ./x install rustc cargo std clippy
    rustup toolchain link {{tcname}} ../built_toolchain

test tcname=DEFAULT_TCNAME:
    #!/usr/bin/env bash
    set -ex
    ../repro/test.sh {{tcname}}
