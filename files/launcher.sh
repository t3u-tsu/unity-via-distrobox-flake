#!/usr/bin/env bash
# Unity Hub launcher - auto-provisioning with self-healing and error diagnostics.
# Managed declaratively by Nix. Do not edit manually.

set -euo pipefail

CONTAINER_NAME="unity"
INI_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/distrobox/distrobox.ini"

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -i unityhub "Unity Hub" "$1" 2>/dev/null || true
    fi
}

fail() {
    echo "ERROR: $1" >&2
    notify "$1"
    exit 1
}

# writeShellApplication pins distrobox/podman on PATH; fall back for direct runs.
DISTROBOX="$(command -v distrobox || true)"
PODMAN="$(command -v podman || true)"
if [ -z "$DISTROBOX" ] || [ -z "$PODMAN" ]; then
    fail "distrobox and podman must be installed and available on PATH"
fi

# Match NAME column exactly (trim whitespace, skip header)
container_line=$("$DISTROBOX" list 2>/dev/null | awk -F'|' -v name="$CONTAINER_NAME" 'NR>1 {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); if ($2 == name) print}' || true)

if [ -z "$container_line" ]; then
    echo "Unity container not found. Starting automatic setup..."

elif echo "$container_line" | grep -qE "Exited \([1-9][0-9]*\)"; then
    exit_code=$(echo "$container_line" | sed -n 's/.*Exited (\([0-9]*\)).*/\1/p')
    echo "Unity container exited abnormally (code=$exit_code). Rebuilding..."
    "$DISTROBOX" rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

if ! "$DISTROBOX" list 2>/dev/null | awk -F'|' -v name="$CONTAINER_NAME" 'NR>1 {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); if ($2 == name) {found=1; exit}} END {exit !found}'; then
    notify "Starting automatic Unity container setup (this may take a few minutes)..."
    echo "Provisioning Unity Distrobox container..."
    echo "This will download Ubuntu 22.04 and install Unity Hub."
    echo ""

    log_file=$(mktemp /tmp/unity-assemble-XXXXXX.log)

    if ! "$DISTROBOX" assemble create --file "$INI_FILE" 2>&1 | tee "$log_file"; then
        echo ""
        echo "=================================================="
        echo "  Unity container setup FAILED"
        echo "=================================================="
        echo ""
        echo "─ Container log (tail 40) ─"
        "$PODMAN" logs "$CONTAINER_NAME" --tail 40 2>/dev/null || echo "  (not available)"
        echo ""
        echo "─ Full assemble log: $log_file"
        echo "  (auto-removed on next success; kept for debugging)"
        echo "=================================================="
        fail "Unity container setup failed"
    fi

    rm -f "$log_file"
    notify "Unity container setup complete! Launching Unity Hub."
    echo ""
fi

# distrobox regenerates xdg-open; keep it pointed at distrobox-host-exec so
# browser sign-in redirects escape back to the host session.
"$PODMAN" exec -u root "$CONTAINER_NAME" sh -c "
    if [ -f /usr/bin/xdg-open ] && [ ! -L /usr/bin/xdg-open ]; then
        rm -f /usr/bin/xdg-open
        ln -sf /usr/bin/distrobox-host-exec /usr/bin/xdg-open
    fi
" >/dev/null 2>&1 || true

# Host GIO/SSL env vars point into the Nix store; drop them so the container
# uses its native Ubuntu libraries and certificates.
exec env \
    -u GIO_EXTRA_MODULES \
    -u SSL_CERT_FILE \
    -u NIX_SSL_CERT_FILE \
    -u CURL_CA_BUNDLE \
    -u SSL_CERT_DIR \
    -u NIX_SSL_CERT_DIR \
    "$DISTROBOX" enter -T "$CONTAINER_NAME" -- unityhub "$@"
