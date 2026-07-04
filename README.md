# nix — thin macOS host + isolated per-client dev VMs

A reproducible dev environment where the **Mac host stays thin and private**, and all
development (and any AI-agent activity) happens inside **disposable Lima VMs — one per
identity** (personal, and one per client). Each VM has its own SSH key, its own GitHub
account, and its own encrypted secrets, so one client's VM can never touch another's.

Everything is declarative: a fresh `vm create <name>` reproduces a guest from the flake,
and per-VM secrets are **sops-encrypted in this (public) repo** and decrypted inside the
guest at activation — so `vm destroy` + `vm create` loses nothing.

---

## Architecture

```
  macOS host (thin, private)
  ┌──────────────────────────────────────────────────────────────┐
  │  Ghostty · Lima · personal git · the `vm` CLI                 │
  │                                                              │
  │  ~/.config/nix-secrets/<name>.age   ← age PRIVATE keys       │
  │      (one per VM · NEVER committed · this is the root of trust)│
  └───────────────┬──────────────────────────────────────────────┘
                  │  limactl  (create / shell / copy)
      ┌───────────┼─────────────────────┐
      ▼           ▼                     ▼
 ┌──────────┐ ┌──────────┐        ┌──────────────┐
 │ personal │ │ acme     │        │  <client>    │   Lima · Ubuntu 24.04 aarch64
 │          │ │ +aws     │        │              │   home-manager (standalone)
 │ ssh key  │ │ +sops    │        │  ssh/aws/env │   rootless Podman + compose
 │ (sops)   │ │ secrets  │        │  (sops)      │   zsh · LazyVim · Zellij
 └──────────┘ └──────────┘        └──────────────┘
        mounts: []  ·  forwardAgent: false
        (each guest is sealed from the host and from every other guest)
```

- **Host (Mac):** thin. Terminal + Lima + the `vm` script + personal git. No dev, no agents.
- **Guests:** one Lima VM per identity, configured entirely by home-manager *inside* the VM
  (`home-manager switch --flake .#<name>`). The Lima template is generic; identity comes
  from `vm-configs/<name>.nix`.
- **Isolation:** `mounts: []` (no host filesystem leaks in) + `forwardAgent: false` (no host
  SSH agent). The VM boundary separates clients; sops keys separate their secrets.
- **Source of truth:** this repo. Edit on host → commit → push → the guest clones/pulls
  GitHub `main` during bootstrap.

### How secrets flow

```
  PUBLIC repo (github.com/tysonxor/nix)        Mac keystore (NOT in repo)
  vm-configs/acme/secrets.yaml    ─ ENC[…] ─┐  ~/.config/nix-secrets/acme.age
                                            │            │
                    git clone (bootstrap)   │            │  limactl copy (vm create,
                                            ▼            ▼   before home-manager runs)
                        ┌───────────────────────────────────────────┐
                        │ acme VM                                   │
                        │  home-manager activation → sops-nix       │
                        │  decrypts → ~/.ssh/id_ed25519, ~/.aws/... │
                        │  re-decrypts on boot (sops-nix.service)   │
                        └───────────────────────────────────────────┘
```

Ciphertext lives in the public repo; the decryption key lives only on the Mac and is copied
into the guest at create time. A guest holds **only its own** key, so it can decrypt only its
own secrets.

---

## The `vm` command

```
vm new <name>       vm secrets <name>    vm rekey <name>
vm create <name>    vm destroy <name>    vm destroy-secrets <name>
vm shell <name>     vm list              vm rebuild
```

| Command | What it does |
|---|---|
| `vm new <name>` | Scaffold an identity: age keypair (Mac keystore), `.sops.yaml` rule, encrypted `vm-configs/<name>/secrets.yaml`, and a `vm-configs/<name>.nix` template. Host-side; no commit/push. |
| `vm secrets <name>` | Open `sops` to edit/fill this VM's secrets (decrypt-for-edit, re-encrypt on save). |
| `vm rekey <name>` | Rotate the VM's age key and re-encrypt its secrets to the new key. |
| `vm create <name>` | Boot + bootstrap the Lima guest. Injects the age key, then runs home-manager. **Fails loudly before booting** if secrets exist but the key is missing. |
| `vm destroy <name>` | Stop + delete the VM (the identity/secrets stay in the repo). |
| `vm destroy-secrets <name>` | Tear down the identity: remove its `.nix`, `secrets/`, keystore key, and `.sops.yaml` rule (prompts first). |
| `vm shell <name>` | Open a zsh shell in the guest. |
| `vm list` | `limactl list`. |
| `vm rebuild` | Rebuild the Mac host config (`darwin-rebuild switch --flake .#mac`). |

Inside any guest, the alias **`rebuild`** runs `home-manager switch --flake ~/nix#<that-guest>`.

### Add a new client

```bash
vm new acme                       # scaffold identity + keypair + encrypted secrets
$EDITOR vm-configs/acme.nix        # set git identity; keep only the sops.secrets you need
vm secrets acme                    # fill real values (ssh key, aws config, .env.local)
git add -A && git commit && git push
vm create acme                     # boot it — secrets decrypt at activation
```

`vm create` clones GitHub `main`, so **push before create**. The `vm`/`sops`/`age`/`yq`
tools come from the flake, so after pulling changes on the Mac run
`git add home.nix vm && vm rebuild` once.

---

## Secrets model (sops-nix)

- **age**, one keypair **per VM identity**. Public keys live in `.sops.yaml` (committed);
  private keys live only on the Mac at `~/.config/nix-secrets/<name>.age` (never committed).
- **Per-VM isolation:** each `.sops.yaml` rule uses an **anchored** `path_regex`
  (`^vm-configs/<name>/secrets\.yaml$`), so a file encrypts to exactly one recipient. A guest
  holding only its own key cannot decrypt another's secrets.
- **À la carte:** `guests.nix` declares no secrets — only the shared key location. Each
  `vm-configs/<name>.nix` opts into exactly what it needs (none / ssh-only / ssh+aws+env / custom).
- **Landing:** SSH key → `~/.ssh/id_ed25519` (0600); AWS → `~/.aws/config`; `.env.local` → a
  **real file** (rootless Podman can't read a tmpfs-symlink bind-mounted into a container).
- **Reboot-safe:** a `sops-nix.service` user unit re-decrypts into tmpfs at boot (`enable-linger`).

**Public-repo guardrails:** `.gitignore` blocks `*.age`/`keys.txt`/`*.dec`/`.env.local`;
`sops.age.keyFile` is a string literal (a Nix path would copy the key into `/nix/store`);
every committed `secrets.yaml` must contain `ENC[`. Back up `~/.config/nix-secrets/`.

---

## Principles

The rules everything else follows from:

- **Per-client isolation is the point.** One VM per identity, each with its own SSH key,
  GitHub account, and secrets. No client's environment can reach another's — enforced at the
  VM boundary, and for secrets cryptographically (each guest holds only its own key).
- **The host stays thin and private.** No dev, no agents, no client code on the Mac. Untrusted
  work (`npm install`, dev containers, agents) runs only inside guests.
- **Guests are disposable; the repo and the Mac keystore are durable.** `vm destroy` +
  `vm create` must lose nothing. Anything that has to survive is either declarative in the
  flake or an encrypted secret in the repo whose key lives on the Mac.
- **Reproducible and declarative.** A fresh `vm create` rebuilds a guest from the flake with
  minimal manual steps — and those steps are documented, never improvised.
- **The public repo never holds a plaintext secret.** Ciphertext only; keys live off-repo. The
  encryption boundary is the repo, not the guest — the guest is a trusted consumer that must
  hold plaintext to function.
- **Explicit over implicit.** Named commands do setup and generation; `vm create` refuses to
  proceed (loudly) rather than silently papering over a missing prerequisite.
- **Least privilege for untrusted code.** Guests are sealed from the host (`mounts: []`, no
  agent forwarding); the roadmap keeps secrets out of the container layer that runs dependencies.

## For agents (context for future work)

If you're an AI agent or new contributor working in this repo, read this first.

- **Golden rule — this repo is PUBLIC. Never commit a plaintext secret.** Every value under
  `vm-configs/*/secrets.yaml` must be sops ciphertext (`ENC[…]`); age private keys and
  `.env.local` never belong in the repo (`.gitignore` guards them). Verify before every commit:
  `grep -q 'ENC\[' <file>` and scan `git diff --cached`.
- **Where things run.** The `vm` CLI, `sops`, `age`, `yq`, and `darwin-rebuild` run on the
  **Mac host**. Guests are Lima VMs (Ubuntu 24.04 aarch64): user `tyson`, home
  `/home/tyson.guest`, UID `501`, configured by **standalone home-manager inside the VM**
  (`home-manager switch --flake .#<name>`) — not NixOS. `flake.nix` auto-generates
  `homeConfigurations.<name>` for every `vm-configs/*.nix` via `mkGuest` (which passes `vmName`).
- **Git / flake gotchas.** Guests clone/pull GitHub `main` during bootstrap, so **push before
  `vm create`** — local uncommitted edits are invisible to a fresh guest. Nix flakes only see
  **git-tracked** files, so `git add` new files before `nix eval`/`flake check`. `vm` and
  `home.nix` are build artifacts on PATH → after editing them, `git add` + `vm rebuild`.
- **Secrets specifics.** One age keypair per VM: public key in `.sops.yaml` (anchored
  `path_regex`, one recipient), private key on the Mac at `~/.config/nix-secrets/<name>.age`,
  copied into the guest by `vm create` before activation. Editing `.sops.yaml` does **not**
  re-encrypt existing files (the recipient is stored in the file) — use `vm rekey` /
  `sops updatekeys`. `sops.age.keyFile` must be a **string literal**, never a Nix path (a path
  copies the private key into world-readable `/nix/store`).
- **Working safely in a live guest.** Development sometimes happens *inside* the personal VM.
  Don't clobber the real `~/.ssh/id_ed25519`: point demo/test secrets at sandbox paths
  (`~/.config/<name>/…`), and don't `home-manager switch` a live VM to an unrelated config.
- **Verify without a full VM.** Most changes check non-destructively: `nix flake check`,
  `nix eval .#homeConfigurations.<name>.activationPackage.drvPath` (evaluates, no activation),
  and sops isolation via the CLI (`sops -d` succeeds with the right key, fails with a wrong one).
  For lifecycle changes, run the real `vm` flow against a throwaway identity, then `vm destroy`
  + `vm destroy-secrets`.
- **Notable technical choices** (rationale, so you don't re-litigate): **age over GPG**
  (single-file key, no keyring state); **per-VM key on the Mac, not derived from the VM's SSH
  host key** (Lima regenerates that key each create, which would force re-encrypting every
  secret) and **not KMS/Vault** (plaintext lands in the guest regardless — not worth the infra
  for a thin host); **rootless Podman + real Docker Compose** over the Podman socket.

---

## Repo layout

```
flake.nix           # auto-generates homeConfigurations from vm-configs/*.nix; darwin `mac`
system.nix          # nix-darwin host system
home.nix            # host home-manager (lima, vm CLI, personal git, sops/age/yq)
shared.nix          # OS-agnostic zsh/atuin/starship (host + guests)
guests.nix          # shared guest baseline: zsh, LazyVim toolchain, Zellij, podman/compose,
                    #   sops.age.keyFile, per-guest `rebuild` alias
bootstrap.sh        # fresh-Mac host bootstrap
bootstrap-guest.sh  # full guest setup (nix, clone, home-manager switch, ...)
vm                  # the guest-management CLI (installed on PATH via home.nix)
vm-configs/
  personal.nix  <client>.nix  sops-demo.nix  # identities -> homeConfigurations.<name>
  <name>/secrets.yaml                         # sops-encrypted, one recipient (flake ignores subdirs)
.sops.yaml          # creation rules: which age PUBLIC key each secrets file encrypts to
.gitignore          # leak defense: *.age, keys.txt, *.dec, .env.local
lima/guest.yaml     # generic VM template (vz, mounts:[], forwardAgent:false, rootless podman)
```
