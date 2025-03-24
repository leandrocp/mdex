default:
    @just --list

dev-server:
    #!/usr/bin/env bash
    set -euo pipefail
    python -m http.server
