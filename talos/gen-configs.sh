#!/usr/bin/env bash
# Regenerate Talos machine configs from SOPS secrets + patches into talos/_out/ (gitignored, contains secrets).
set -euo pipefail
cd "$(dirname "$0")"
VERSION=v1.14.2
SCHEMATIC=2e3e6a52fd648d18a71f4b42f6997850ed04048d9e71986c08b927808bcfc4eb
out=_out
rm -rf "$out"; mkdir -m 700 "$out"
talosctl gen config homelab https://10.20.8.100:6443 \
  --with-secrets <(sops -d secrets.sops.yaml) \
  --install-image "factory.talos.dev/installer/${SCHEMATIC}:${VERSION}" \
  --config-patch @patches/cluster.yaml \
  --config-patch-control-plane @patches/controlplane-common.yaml \
  -o "$out" --force
# Per-node: hostname + Tailscale extension config (SOPS-encrypted auth key, unique UDP port).
node() { # $1 = base config (controlplane|worker), $2 = node name
  local args=(--patch "@patches/$2.yaml")
  if [[ -f "patches/$2.tailscale.sops.yaml" ]]; then
    sops -d "patches/$2.tailscale.sops.yaml" > "$out/$2.tailscale.yaml"   # _out/ is 0700 + gitignored
    args+=(--patch "@$out/$2.tailscale.yaml")
  fi
  talosctl machineconfig patch "$out/$1.yaml" "${args[@]}" -o "$out/$2.yaml"
  rm -f "$out/$2.tailscale.yaml"
}
node controlplane talos-cp-1
node worker talos-worker-1
for n in talos-cp-1 talos-worker-1; do talosctl validate --mode metal --config "$out/$n.yaml"; done
