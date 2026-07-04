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
  flake.nix          # auto-generates homeConfigurations from vm-configs/*.nix
  system.nix         # nix-darwin system
  home.nix           # host home-manager (ghostty, lima, vm cmd, personal git)
  guests.nix         # shared baseline: zsh, LazyVim toolchain, Zellij, docker-compose,
                     #   docker shim, DOCKER_HOST, TERM=xterm-256color
  bootstrap.sh       # fresh-Mac host bootstrap
  bootstrap-guest.sh # full guest setup
  vm                 # guest mgmt script (writeShellScriptBin, on PATH)
  vm-configs/
    personal.nix
    crafted.nix      # + awscli2, COMPOSE_FILE override, incisive-portal-override.yml
    sops-demo.nix    # sops-nix demo identity (sandboxed secret paths)
    sops-demo/secrets.yaml   # sops-ENCRYPTED dummy secrets (subdir: flake generator ignores it)
  .sops.yaml         # sops creation rules: which age PUBLIC key each secrets file encrypts to
  .gitignore         # blocks *.age / keys.txt / *.dec / .env.local (leak defense)
  lima/guest.yaml    # vz, mounts:[], forwardAgent:false, containerd off, rootless-podman provisioning + probe
  SETUP.md
```

## The `vm` command

```
vm new <name>       vm secrets <name>    vm rekey <name>
vm create <name>    vm destroy <name>    vm destroy-secrets <name>
vm shell <name>     vm list              vm rebuild
```

- **Adding a client (easy path):** `vm new <client>` scaffolds everything — age keypair (Mac keystore), `.sops.yaml` rule, encrypted `vm-configs/<client>/secrets.yaml`, and `vm-configs/<client>.nix`. Then: edit git identity in `vm-configs/<client>.nix` → `vm secrets <client>` (fill real secrets) → `git add -A && commit && push` → `vm create <client>`.
- `vm secrets <name>` — edit/rotate a VM's sops secrets in place (opens `sops`; decrypts for edit, re-encrypts on save).
- `vm rekey <name>` — rotate the VM's age key + re-encrypt its secrets to the new key. Then commit/push and **recreate** the VM so the guest gets the new key.
- `vm destroy-secrets <name>` — tear down an identity: removes `vm-configs/<name>.nix`, `vm-configs/<name>/`, the keystore `~/.config/nix-secrets/<name>.age`, and the `.sops.yaml` rule (prompts first). Run after `vm destroy <name>`; then commit/push.
- `vm create` is explicit: it **fails loudly before booting** if `vm-configs/<name>/secrets.yaml` exists but the age key is missing (never auto-generates).
- `vm shell` launches zsh (`limactl shell "$name" zsh`) since Lima won't honor the login shell.
- **Gotcha:** `vm` + any flake-read file are build artifacts/git-tracked. edit -> `git add` -> `vm rebuild`; and **push before `vm create`** (bootstrap fetches GitHub `main`). The new subcommands need `sops`/`age`/`yq` on PATH (in `home.nix`) — so after pulling this, `git add home.nix vm && vm rebuild` once.

---

## STATUS — DONE

### Host + automation
- flake/system/home split, named `mac`.
- Lima template; boot/SSH/no-leak validated; containerd disabled.
- `vm` script on PATH; single-command `vm create` end-to-end; auto-gen homeConfigurations; create guard.
- `vm-configs/` dir, shared `guests.nix` + `bootstrap-guest.sh` at root.
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

### Hardening — sops-nix  (MACHINERY DONE, migrate real secrets per-VM)
Encrypted-in-repo secrets, decrypted at home-manager activation inside each guest. Machinery is implemented + proven against dummy secrets (`sops-demo`). Real-secret migration is per-VM (below).

**Model**
- **age**, one keypair **per VM identity**. PUBLIC keys → `.sops.yaml` (committed). PRIVATE keys → Mac at `~/.config/nix-secrets/<name>.age` (**never committed**, chmod 600).
- **Isolation:** each `.sops.yaml` `creation_rule` uses an **anchored** `path_regex` (`^vm-configs/<name>/secrets\.yaml$`) so a file encrypts to exactly ONE key. crafted's VM (holding only crafted's key) cannot decrypt personal's secrets. Proven: `sops -d` with the wrong key exits non-zero, no plaintext.
- **Key delivery:** `mounts:[]` seals the guest, so `vm create` copies `~/.config/nix-secrets/<name>.age` into the guest at `~/.config/sops/age/keys.txt` via `limactl copy`, BEFORE `home-manager switch` runs (sops decrypts during activation).
- **Landing:** SSH key → `~/.ssh/id_ed25519` (mode 0600, tmpfs symlink — ssh follows it). AWS → `~/.aws/config`. `.env.local` → a **real file** at a safe home path (rootless Podman can't read a tmpfs-symlink volume-mounted into a container; use compose `env_file:`, not a volume mount).
- **Reboot:** sops-nix installs a `sops-nix.service` user unit; `enable-linger tyson` re-decrypts into tmpfs at boot. Age key persists on disk.
- **Snowflake:** `guests.nix` declares NO secrets (only `sops.age.keyFile`). Each `vm-configs/<name>.nix` opts in to exactly the secrets it needs — none / ssh-only / ssh+aws+env / custom. AWS & `.env.local` are NOT baseline.

**The one manual per-VM step (irreducible — placing the root-of-trust key):**
`vm new <name>` now does the keypair + `.sops.yaml` rule + encrypted `secrets.yaml` + `vm-configs/<name>.nix` in one shot (see "The `vm` command"). The equivalent by hand:
```bash
# on the Mac, once per client:
mkdir -p ~/.config/nix-secrets && chmod 700 ~/.config/nix-secrets
age-keygen -o ~/.config/nix-secrets/<name>.age   # prints the PUBLIC key; chmod 600 the file
# add that public key + an anchored creation_rule to .sops.yaml, then:
sops vm-configs/<name>/secrets.yaml                       # $EDITOR opens; save = encrypted
grep -q 'ENC\[' vm-configs/<name>/secrets.yaml && sops -d vm-configs/<name>/secrets.yaml >/dev/null && echo OK
# git add/commit/push (ciphertext only), then: vm create <name>
```

**Migration checklist (move REAL secrets, per VM):**
1. `vm new <name>` — scaffolds the age key, `.sops.yaml` rule, encrypted `secrets.yaml`, and `vm-configs/<name>.nix`. (By hand: `age-keygen -o ~/.config/nix-secrets/<name>.age` + add an anchored rule to `.sops.yaml`.)
2. Edit git identity in `vm-configs/<name>.nix`; add/remove `sops.secrets` blocks for what this guest needs (real paths: `ssh_key` → `~/.ssh/id_ed25519`, `aws_config` → `~/.aws/config`, `env_local` → real file via compose `env_file:`).
3. `vm secrets <name>` — paste REAL values:
   - `ssh_key`: generate on the Mac (`ssh-keygen -t ed25519 -f /tmp/k -N ""`), paste `/tmp/k`, then `shred -u /tmp/k`. Add the **public** key to that client's GitHub; delete the old orphaned key.
   - `aws_config`: the real SSO `~/.aws/config`. `env_local`: the real `.env.local`.
4. **Verify no plaintext staged:** `git diff --cached` shows only `ENC[...]`; `grep -R 'PRIVATE KEY' vm-configs/*/secrets.yaml` finds nothing plaintext. Commit + push.
5. `vm destroy <name>` → `vm create <name>`. Confirm secrets land, GitHub SSH + AWS profile work.
6. Drop the now-redundant manual bits from "START HERE". To rotate a key later: `vm rekey <name>` → commit/push → recreate.

**Guardrails (PUBLIC repo — never commit plaintext):**
- `sops.age.keyFile` is a **string literal**, never a Nix path (a path literal copies the private key into world-readable `/nix/store`).
- `.gitignore` blocks `*.age` / `keys.txt` / `*.dec` / `.env.local`.
- Every committed `secrets.yaml` must contain `ENC[` — verify before every commit.
- Age private keys live only in `~/.config/nix-secrets/` on the Mac — **back them up** (password manager). Losing one = re-encrypt that client's secrets to a fresh key.

### Cleanup reminders
- After `vm destroy` + recreate: old GitHub SSH key orphaned -> delete + add new. Redo `~/.aws/config`, `.env.local`, project build. **Once a VM is migrated to sops-nix (see Hardening — sops-nix), the SSH key / `~/.aws/config` / `.env.local` come back automatically on recreate; only the project build remains.**
