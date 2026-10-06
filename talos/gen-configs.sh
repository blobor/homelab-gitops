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
  --config-patch-control-plane @patches/controlplane.yaml \
  -o "$out" --force
talosctl machineconfig patch "$out/controlplane.yaml" --patch @patches/talos-cp-1.yaml -o "$out/talos-cp-1.yaml"
talosctl machineconfig patch "$out/worker.yaml" --patch @patches/talos-worker-1.yaml -o "$out/talos-worker-1.yaml"
for n in talos-cp-1 talos-worker-1; do talosctl validate --mode metal --config "$out/$n.yaml"; done
