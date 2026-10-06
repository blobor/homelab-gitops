# homelab-gitops

GitOps configuration for a single-node homelab: Talos Linux on Proxmox, ArgoCD (app-of-apps), Cilium, Traefik.

- `talos/` — Talos machine secrets and config patches (secrets SOPS-encrypted)
- `bootstrap/` — the only things applied by hand: ArgoCD Helm values and the root Application
- `clusters/homelab/` — one ArgoCD Application per component
- `platform/`, `apps/` — manifests and Helm values

## Secrets

This repository is **public**. Every secret is encrypted with [SOPS](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age) (rules in `.sops.yaml`); files holding secrets are named `*.sops.yaml`.
A pre-commit hook runs gitleaks and refuses unencrypted `*.sops.yaml` files:

```sh
pre-commit install
```

Generated Talos configs (`controlplane.yaml`, `worker.yaml`, `talosconfig`) and kubeconfigs are never committed — they are regenerated from `talos/secrets.sops.yaml` and the patches.
