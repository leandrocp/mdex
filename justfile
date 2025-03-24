default:
    @just --list

dev-server:
    #!/usr/bin/env bash
    set -euo pipefail
    (cd priv/site && python -m http.server)
