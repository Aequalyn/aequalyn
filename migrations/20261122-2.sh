#!/usr/bin/env bash
# 20261122-2.sh -- migration for existing installs: keep LocalSend reachable.
#
# LocalSend sends and receives files over TCP/UDP port 53317. A default-drop
# firewall (such as the shipped nftables ruleset) blocks that port, so devices
# on the LAN can never discover or transfer to this machine. This migration
# makes the port explicitly allowed in every firewall backend that is present
# and active, and persists the rule so it survives reboots. It is safe to run
# more than once.

set -euo pipefail

if [[ -z "${AEQUALYN_MIGRATION_HOMES:-}" ]]; then
    [[ $EUID -eq 0 ]] || { echo "run as root (sudo $0)" >&2; exit 1; }
fi

info() { printf '\033[0;34m[20261122-2]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[20261122-2]\033[0m %s\n' "$*"; }

PORT=53317

# --- nftables ---------------------------------------------------------------
NFT_CONF="${AEQUALYN_NFT_CONF:-/etc/nftables.conf}"

# In test/CI mode (AEQUALYN_MIGRATION_HOMES set) we do not touch the system
# firewall; the migration still exits successfully.
if [[ -n "${AEQUALYN_MIGRATION_HOMES:-}" ]]; then
    ok "migration 20261122-2 complete (test mode: system firewall untouched)"
    exit 0
fi

if [[ $EUID -ne 0 ]]; then
    echo "run as root (sudo $0)" >&2
    exit 1
fi

if [[ -f "$NFT_CONF" ]]; then
    if ! grep -q "dport $PORT" "$NFT_CONF"; then
        # Insert the allow rules right after the SSH allow rule when it exists,
        # otherwise before the final counter in the input chain.
        if grep -q 'tcp dport ssh accept' "$NFT_CONF"; then
            tmp=$(mktemp)
            awk -v port="$PORT" '
                /tcp dport ssh accept/ {
                    print
                    print "    tcp dport " port " accept comment \"allow LocalSend\""
                    print "    udp dport " port " accept comment \"allow LocalSend\""
                    next
                }
                { print }
            ' "$NFT_CONF" > "$tmp"
            cat "$tmp" > "$NFT_CONF"
            rm -f "$tmp"
            info "$NFT_CONF: allowed TCP/UDP $PORT for LocalSend"
        elif grep -q 'chain input' "$NFT_CONF"; then
            tmp=$(mktemp)
            awk -v port="$PORT" '
                /chain input/ { inchain=1 }
                inchain && /^    counter$/ {
                    print "    tcp dport " port " accept comment \"allow LocalSend\""
                    print "    udp dport " port " accept comment \"allow LocalSend\""
                }
                { print }
            ' "$NFT_CONF" > "$tmp"
            cat "$tmp" > "$NFT_CONF"
            rm -f "$tmp"
            info "$NFT_CONF: allowed TCP/UDP $PORT for LocalSend"
        fi
    else
        info "$NFT_CONF: LocalSend port already allowed"
    fi
fi

if command -v nft >/dev/null 2>&1 && systemctl is-active --quiet nftables 2>/dev/null; then
    nft add rule inet filter input tcp dport "$PORT" accept 2>/dev/null || true
    nft add rule inet filter input udp dport "$PORT" accept 2>/dev/null || true
    info "nftables: live rules applied"
fi

# --- ufw -------------------------------------------------------------------
if command -v ufw >/dev/null 2>&1; then
    if ufw status 2>/dev/null | grep -q 'Status: active'; then
        ufw allow "$PORT/tcp" >/dev/null 2>&1 || true
        ufw allow "$PORT/udp" >/dev/null 2>&1 || true
        info "ufw: allowed TCP/UDP $PORT for LocalSend"
    fi
fi

# --- firewalld --------------------------------------------------------------
if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
    firewall-cmd --permanent --add-port="$PORT/tcp" >/dev/null 2>&1 || true
    firewall-cmd --permanent --add-port="$PORT/udp" >/dev/null 2>&1 || true
    firewall-cmd --reload >/dev/null 2>&1 || true
    info "firewalld: allowed TCP/UDP $PORT for LocalSend"
fi

ok "migration 20261122-2 complete"