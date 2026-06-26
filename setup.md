# Dev Environment Setup — Progress & Plan

Thin macOS host + isolated Lima dev VMs (one per identity: personal + per-client).
Host stays private; all dev and AI-agent activity runs inside guest VMs.

**Host config:** `mac` · **User:** `tyson` (guest home `/home/tyson.guest`) · **Repo:** `github.com/tysonxor/nix` (public)

---

## START HERE (next session)

1. **Verify clean reproduce (do this first):** `vm destroy crafted` then `vm create crafted`. Confirm rootless Podman, Docker Compose, the socket override, `docker` shim, `TERM`, AWS CLI all come up with NO manual steps. Most of this went in incrementally on a running VM — not yet proven to reproduce cold. This is the "I won't lose my work" proof.
2. After recreate, redo the manual bits (until sops-nix): `~/.aws/config`, the SSH key (paste pubkey to client GitHub + delete orphan), `.env.local`, and the client project build (`npm install` + build workspace packages).
3. Then hardening: **Podman sandbox** + **sops-nix** (see bottom).

---

## Architecture

- **Host (Mac):** thin. Ghostty + Lima + personal git. No dev, no agents.
- **Guests:** zsh + LazyVim + Zellij + rootless Podman. One VM per identity.
- **Isolation:** `mounts: []` + `forwardAgent: false`.
- **Per-client:** each client VM = own SSH key + (often) own GitHub account.
- **Source of truth:** host repo. edit-on-host -> commit -> push -> pull-in-guest.

## Repo layout

```
nix/
  flake.nix          # auto-generates homeConfigurations from vms/*.nix
  system.nix         # nix-darwin system
  home.nix           # host home-manager (ghostty, lima, vm cmd, personal git)
  guests.nix         # shared baseline: zsh, LazyVim toolchain, Zellij, docker-compose,
                     #   docker shim, DOCKER_HOST, TERM=xterm-256color
  bootstrap.sh       # fresh-Mac host bootstrap
  bootstrap-guest.sh # full guest setup
  vm                 # guest mgmt script (writeShellScriptBin, on PATH)
  vms/
    personal.nix
    crafted.nix      # + awscli2, COMPOSE_FILE override, incisive-portal-override.yml
  lima/guest.yaml    # vz, mounts:[], forwardAgent:false, containerd off, rootless-podman provisioning + probe
  SETUP.md
```

## The `vm` command

```
vm create <name>    vm destroy <name>    vm shell <name>    vm list    vm rebuild
```

- Adding a client: write `vms/<client>.nix`, push, `vm create <client>`.
- `vm shell` launches zsh (`limactl shell "$name" zsh`) since Lima won't honor the login shell.
- **Gotcha:** `vm` + any flake-read file are build artifacts/git-tracked. edit -> `git add` -> `vm rebuild`; and **push before `vm create`** (bootstrap fetches GitHub `main`).

---

## STATUS — DONE

### Host + automation
- flake/system/home split, named `mac`.
- Lima template; boot/SSH/no-leak validated; containerd disabled.
- `vm` script on PATH; single-command `vm create` end-to-end; auto-gen homeConfigurations; create guard.
- `vms/` dir, shared `guests.nix` + `bootstrap-guest.sh` at root.
- personal + crafted VMs live, isolated, own keys, separate GitHub accounts.

### Rootless Podman (reproducible, in guest.yaml)
- WORKS. Original hang root cause = partial/inconsistent toolchain, NOT the subuid range (disproven). Fix = install COMPLETE stack + assert newuidmap setuid.
- system stage installs: `podman uidmap crun fuse-overlayfs slirp4netns passt netavark aardvark-dns catatonit podman-compose`; re-pins /etc/sub{u,g}id to `100000:65536`; `chmod u+s` helpers; `loginctl enable-linger tyson` (literal `tyson`, NOT `${LIMA_CIDATA_USER}` — that warns).
- user stage: containers.conf, `podman system migrate`, `systemctl --user enable --now podman.socket`.
- Probe: `timeout 30 podman info` — fast + network-free (hello-world's image pull caused a boot timeout). Fails `vm create` loudly if broken.
- TRAP: `apt install podman` does NOT pull `uidmap`; its absence makes rootless HANG silently. Install whole stack together.

### Docker Compose on rootless Podman
- Real Docker Compose (Go plugin, `pkgs.docker-compose`) driving rootless Podman via its Docker-API socket. Compatibility WITHOUT the daemon; keeps rootless security.
- `DOCKER_HOST = unix:///run/user/501/podman/podman.sock` in guests.nix; socket enabled at boot.
- `podman-compose` (Python) ABANDONED — failed to create containers on this compose file.
- `docker` shim (guests.nix writeShellScriptBin): `docker compose ...` -> `docker-compose`, else -> `podman`. Needed for the client Makefile (non-interactive bash; alias won't work, must be a real binary).
- Client api container mounts `/var/run/docker.sock` (can't edit client repo). Worked around: `incisive-portal-override.yml` (home.file in crafted.nix) mounts the podman socket there; applied everywhere incl. Makefile via `COMPOSE_FILE = "docker-compose.yml:/home/tyson.guest/incisive-portal-override.yml"`. (dcc alias now redundant.)
- Security note: that socket mount gives the api container control of the rootless engine — boundary pierced FOR crafted by client design. Still contained by rootless (user not root) + VM boundary. Do NOT switch to rootful Docker (bigger blast radius, no gain). OrbStack rejected (would replace Lima, break per-client isolation).

### terminfo / zsh
- "Repeating keys" in zsh = `TERM=xterm-ghostty` with no matching guest terminfo. Fix: `TERM=xterm-256color` in guests.nix. Also unblocked `make` (DOCKER_HOST loaded cleanly).
- zsh default via `vm shell` running zsh.

### AWS (SSO)
- `awscli2` in crafted.nix. `~/.aws/config` written MANUALLY (client SSO URL/account-id kept out of public repo). `aws sso login --profile crafted --use-device-code` (browser on Mac, code paste). Verify: `aws sts get-caller-identity --profile crafted`. NOT reproducible — sops-nix candidate.

### Viewing the app
- Lima auto-forwards guest ports to Mac loopback. `http://localhost:5173` (web) / `:3000` (api) on the Mac just works. Loopback-only (not network-exposed) — fine given thin host. No browser needed in the guest (and don't add one).

---

## KNOWN ISSUES / CONTEXT

- **api restart loop = high CPU (200%).** Cause: container mounts local `./packages` over the built ones, but `@incisive/logger` etc. aren't built locally -> `nest build` fails (TS2307) -> restart loop -> pegs CPU. This is a CLIENT PROJECT setup step, not infra. Fix: build workspace packages locally so the mount has compiled output:
  `npm install && npm run build --workspace=packages/shared --workspace=packages/logger --workspace=packages/db`
  (Check client README/`package.json` scripts for a one-command `make install`/`setup` first.)
  NOTE: `npm install` runs in the VM = the supply-chain exposure the Podman sandbox is meant to contain. Contained to crafted (disposable). Optionally `aws sso logout` before installing so a live AWS token isn't present. This is the concrete motivation for the sandbox phase.

### NEEDS VERIFICATION
- Yesterday's Podman/compose/terminfo/shim config went in incrementally via repeated `home-manager switch` on a RUNNING crafted. Declarative now, but NOT proven to reproduce first-try from clean `vm create`. **Verify by recreating crafted from scratch (see START HERE #1).**

### Parked
- **mac-app-util** (Spotlight for host GUI apps): commented out, blocked on common-lisp.net 503s. Re-enable when their server recovers.

---

## TODO

### Phase 6 — Snapshots
- Host cron over `limactl list -q`, day-of-week rotation, `--tty=false`. Test create + restore. Experimental — real durability = reproducible flake + pushed git.

### Phase 7 — Ergonomics
- Zellij default layout (editor + agent + gh panes) in guests.nix.
- Ghostty/Zellij keybinding collision.
- Ghostty `font-family` -> Nerd Font (LazyVim/Zellij icons).

### Hardening — Podman sandbox (THE security priority)
- Run untrusted stuff (`npm install`, dev containers, agents) in a container that has the CODE but NOT the secrets (SSH key, AWS token). Keep secrets + `git push` in the VM layer, outside that container.
- VM boundary protects between clients; this container boundary protects secrets from your own dependencies within a client.
- NOTE: crafted's api already has the engine socket (client requirement) so that specific container is not a clean sandbox — scrutinize.

### Hardening — sops-nix
- Encrypted-in-repo secrets, decrypted at runtime. Makes the manual/ephemeral things reproducible: SSH keys, `~/.aws/config`, `.env.local`. Worth it now — you have 3 such items.

### Cleanup reminders
- After `vm destroy` + recreate: old GitHub SSH key orphaned -> delete + add new. Redo `~/.aws/config`, `.env.local`, project build (until sops-nix + sandbox).
