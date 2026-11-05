default:
    @just --list

dev-server:
    #!/usr/bin/env bash
    set -euo pipefail
    (cd priv/site && python -m http.server)

# Regenerate usage-rules.md (read by the usage_rules package) from skills/mdex/SKILL.md
sync-usage-rules:
    awk 'n >= 2 { if (started || NF) { started = 1; print }; next } /^---$/ { n++ }' skills/mdex/SKILL.md > usage-rules.md
