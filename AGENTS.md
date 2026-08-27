# Grabette OS (agent notes)

pi-gen fork building the **two** flashable Raspberry Pi OS images of the Grabette
project. Replaces the manual `make install-rpi` / `make install-systemd` bring-up
documented in `packages/{grabette,gripette}/README.md` of the monorepo.

Keep this file up to date.

| Variant | Device | Image | Services enabled |
|---|---|---|---|
| `config.grabette` | grabette, Pi 4 | `grabetteos` (~1.6 GB) | `grabette`, `grabette-bluetooth` |
| `config.gripette` | gripette, Pi Zero 2W | `gripetteos` (~1.3 GB) | `gripette`, `gripette-bluetooth` (`gripette-web` installed, opt-in) |

## Build & test

No credentials needed — `pollen-robotics/grabette` is public.

```bash
GRABETTE_REF=develop ./build-docker.sh -c config.gripette   # or config.grabette
sudo -E GRABETTE_REF=develop ./build.sh -c config.grabette  # native, needs qemu binfmt
```

`GRABETTE_REF` = monorepo branch/tag to bake (default `develop`). `OS_VERSION` =
stamp in `/home/pollen/VERSION.txt` (default `dev`; CI passes the git tag).
Output in `deploy/`. Budget hours: the pi-gen stages take ~25 min, `export-image`
is the long pole.

Verify a built image without flashing (loop-mounts it, plus qemu-chroot runtime
checks — service module imports, script parsing, `systemd-analyze verify`,
`hand-from-hostname` behavior):

```bash
docker run --rm --privileged -v $PWD:/v pi-gen \
  bash /v/verify-image.sh image_<date>-<variant>os.zip <variant>
```

Both variants passed all checks as of 2026-08-26. **Nothing hardware-dependent is
covered** — camera, motor bus, OAK-D, I2C encoders, BLE provisioning need a real
device (`gripetteos_check` / `grabetteos_check` on the device, then the monorepo's
`make check` / `scripts/check_hardware.py`).

## How the two images share one tree

`config` (shared: user, SSH, WPA country) is sourced first, then the `-c` file
sets `IMG_NAME`, `TARGET_HOSTNAME` and `STAGE_LIST`, which ends in the device
stage. Each device stage owns an `EXPORT_IMAGE`, so **only the selected variant
exports an image** (upstream's `stage2/EXPORT_IMAGE` was deleted).

```
common/common-setup.sh          sourced by both stages: monorepo clone, hardened
                                cmdline, journald, BLE-only, hand script, VERSION.txt
stage-<variant>/00-<variant>/   00-packages, 00-run.sh (host side), 01-run-chroot.sh
                                (uv venv + import check + enable), files/
```

Shared logic belongs in `common/`; anything a variant does alone belongs in its
stage. Set `OS_NAME` **before** sourcing `common-setup.sh`.

## Invariants (breaking these fails silently or on-device, not at build time)

- **User is `pollen`, checkout at `/home/pollen/grabette`, venv at its root.** Baked
  units hardcode these. `DISABLE_FIRST_BOOT_USER_RENAME=1`; the README tells users
  not to change the username in Imager.
- **HAND comes from the hostname** (`<device>-left|right`), derived on first service
  start by `ExecStartPre=+/usr/local/bin/hand-from-hostname <env-file> <VAR>`.
  It is **append-only** to `/etc/<device>/env` and guarded by a `grep`, because
  calibration (`calibrate_zero_local.py`, `calibrate_angles.py`) appends to the
  same file later. Never rewrite that file from a build or boot script.
- **`files/*.service` are copies** of `packages/*/systemd/*.service` with `User=`,
  paths and the `ExecStartPre` hook changed. When the monorepo units change, port
  it here by hand. Same for the Makefile-derived bits (udev rule, polkit rules,
  sudoers, timesyncd) — `config.txt` and `timesyncd-grabette.conf` are currently
  byte-identical copies of the monorepo files; keep them that way.
- A stage script **without the exec bit is silently skipped** by pi-gen. `chmod +x`
  every new `*-run.sh`. `on_chroot` heredocs need `<<-` with real tab indentation.

## Gotchas already paid for

- `STAGE_LIST` uses `${BASE_DIR:-.}` — `build-docker.sh` sources the config before
  `BASE_DIR` exists, and `set -u` kills the build otherwise.
- New env vars consumed by a stage must be added to `build-docker.sh`'s `docker run
  -e` list, or Docker builds silently see them empty.
- In the container: no `unzip` (use `bsdtar`), and `/dev` is a tmpfs so loop
  partition nodes must be `mknod`'d from `/sys/class/block` — `verify-image.sh`
  does both. `systemd-analyze verify` needs a writable `/tmp` (tmpfs over the
  read-only mount).
- Benign build-log noise: `update-alternatives: error: no alternatives for mkvinfo`
  and dbus `system_bus_socket` failures. Both are chroot artifacts, not failures.
- The clone uses `GIT_LFS_SKIP_SMUDGE=1` — device services don't need the meshes.

## Relationship to upstream pi-gen

Fork of [`RPi-Distro/pi-gen`](https://github.com/RPi-Distro/pi-gen), `arm64`
branch (synced to `ca8aeed`, 2026-06-16). Everything outside `common/`,
`stage-grabette/`, `stage-gripette/` and the `config*` files is stock upstream —
including `stage0`, `stage1/00-boot-files/*` and `stage2/01-sys-tweaks/*`, so
the kernel tracks whatever the Raspberry Pi archive ships (there is **no**
kernel pin; one existed for a BLE-advertising regression in 6.18.34 and was
removed once that was fixed upstream).

Three deliberate divergences, all load-bearing — do not "fix" them by syncing:

| File | Divergence | Why |
|---|---|---|
| `depends`, `scripts/dependencies_check` | `qemu-user-static` instead of upstream's `qemu-user-binfmt` | matches what the CI apt step installs; reverting makes `dependencies_check` fail on the missing `qemu-arm` binary |
| `.gitignore` | un-ignores `config`, `SKIP`, `SKIP_IMAGES` | this repo commits `config*` and the `stage3-5/SKIP` markers |
| `stage2/EXPORT_IMAGE`, `.gitlab-ci.yml` | deleted | export moved into the device stages (one image per variant); GitLab CI unused |

To re-sync: clone upstream `arm64`, `diff -rq` against this tree, and reconcile
only files outside the list above.

## Open items

- Repo is **not pushed**. `origin` is preset to `git@github.com:pollen-robotics/grabette-os.git`;
  create it and push `develop`. CI (matrix over both variants, release on `v*` tags)
  then works with no secrets.
- Image sizes are untuned; grabette's venv (depthai, opencv, rerun, gradio) dominates.

## Conventions

Bare repo + worktrees (`grabette-os.git` + `grabette-os_<branch>`), like the rest of
the workspace. Commits carry `Assisted-by: Claude:<model-id>` when AI-assisted, and
no `Co-Authored-By:` (workspace convention).
