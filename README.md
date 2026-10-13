# Home Photo Server

A self-hosted, Google Photos-style photo library running on a repurposed PC at home. The home server is the **source of truth**, backed up with the **3-2-1 rule**, reachable from anywhere without opening ports, and cheap to run.

## Goals

- Feel like a modern Google Photos / iCloud Photos experience on iPhone, MacBook and the web
- Home server is the single source of truth
- Follow 3-2-1 backups: 3 copies, 2 media types, 1 offsite
- Keep monthly cost as close to zero as possible
- Remote access without port forwarding

## Architecture

```
 iPhone (Immich app) ──┐
 MacBook (browser) ────┼── Tailscale (WireGuard mesh) ──► Ubuntu Server (home LAN)
 Web (anywhere) ───────┘                                   │
                                                           │  Docker Compose
                                                           │  ├─ immich-server
                                                           │  ├─ immich-machine-learning
                                                           │  ├─ postgres
                                                           │  └─ redis
                                                           │
                                                      Copy 1: server SSD
                                                           │
                                     ┌─────────────────────┴─────────────────────┐
                                     ▼                                           ▼
                        Copy 2: restic repo                          Copy 3: Seagate portable
                        (OneDrive via rclone)                        (LUKS2 + ext4, via rsync)
                        encrypted, deduped, versioned                offsite in Utah (Dec 2026)
```

## Tech stack

| Piece | Why |
|---|---|
| **Ubuntu Server** | Stable, lightweight, well documented. Runs fine on an old PC. |
| **Immich (v3.2.2)** | Open-source Google Photos alternative: mobile auto-backup, face/object search, timeline, albums. |
| **Docker Compose** | One file defines the whole stack; easy to upgrade and rebuild. |
| **PostgreSQL / Redis** | Immich's database and job queue. |
| **Tailscale** | Private remote access with no port forwarding or public exposure. |
| **restic + rclone** | Encrypted, deduplicated, versioned backups to any cloud (here, OneDrive). |
| **LUKS2 + rsync** | Encrypted offline drive, fast incremental copies. |
| **immich-go** | Imports Google Takeout correctly (see below). |

## Hardware

- Old PC (from a friend), 1 TB SSD (~928 GB usable)
- DHCP-reserved LAN address
- SSH key authentication only
- Sleep/suspend modes masked so it stays up
- Long-running jobs run inside `tmux`

## Importing the library

**Sources:** Google Takeouts (Oct 2024, Nov 2025), an old Seagate HDD, MacBook Photos (exported as unmodified originals + XMP sidecars), OneDrive folders, and an iPhone folder.

**Why immich-go:** Google Takeout strips dates and locations out of the photos and puts them in separate JSON files. immich-go merges the metadata back in and de-duplicates across takeouts.

**Result after dedup and trimming:** 7,894 photos + 1,471 videos, **67 GiB** of originals.

## Backup strategy (3-2-1)

| Copy | Location | Media | Notes |
|---|---|---|---|
| 1 | Server SSD | Internal SSD | Primary / source of truth |
| 2 | OneDrive (restic repo via rclone) | Cloud | Encrypted, deduplicated, versioned. Offsite. |
| 3 | Seagate portable drive | External HDD | LUKS2 + ext4, filled with rsync. Moves offsite in Dec 2026 (in progress). |

**Schedule**

- 02:00 UTC: Immich's own database dump
- 03:00 UTC: nightly restic backup (cron), an hour after the dump so it captures the latest one
- Weekly prune keeps **7 daily, 4 weekly, 6 monthly, 3 yearly** snapshots
- Thumbnails and transcoded video are excluded, since Immich regenerates them
- First full backup took ~7 hours

**Seagate copy:** rsync of ~98 GB took 17 minutes. Drive is LUKS2-encrypted; the LUKS header backup is kept in an encrypted disk image on the Mac and on a USB stick (never in a cloud-synced folder).

## Verification

Backups only count if they restore.

- `restic check` on a 5% data sample: passed
- Restore test of a real folder, compared to the original with `diff`: identical
- rsync checksum pass on the Seagate: clean
- Latest DB dump validated with `gzip -t`
- Nightly and weekly scripts write log files that get checked

## Problems and lessons

- **Interrupted backup left a 0-byte snapshot file** that broke later runs. Found it by file size and deleted only that file. *Lesson: a failed run can poison the repo; know how to inspect it.*
- **OneDrive 409/500 errors on upload.** restic's built-in retries handled them.
- **Pasted passphrases into hidden prompts were unreliable** (clipboard got cleared). Switched to typing them and tested the unlock *before* putting data on the drive.
- **Swap full, `immich_server` at ~6 GiB after big imports.** Restarted the container and reset swap; memory dropped to ~1 GiB.
- **Leaked secrets:** deleted two exposed Immich API keys, and revoked and reconnected a OneDrive token that appeared in a screenshot. *Lesson: treat screenshots and pasted logs as public.*
- **LUKS header backup nearly landed in iCloud-synced Desktop**, which would have put the header next to the encrypted data. Moved to an encrypted image + USB stick.
- **The OneDrive storage belongs to a family Microsoft 365 plan.** That's a dependency outside my control, so it's documented as a risk (below).

## Limitations / known gaps

- No RAID: a single SSD is the only local copy
- No failure alerts yet; logs are checked manually
- Offsite drive refresh is manual
- Until the Seagate goes offsite, OneDrive is the only offsite copy, and it depends on a family plan
- A second cloud copy (e.g. Backblaze B2) would close the gap sooner

## Monthly cost

| Item | Cost |
|---|---|
| Hardware | $0 (donated PC) |
| Immich, Tailscale (personal), restic, rclone | $0 |
| OneDrive storage | $0 incremental (shared family plan) |
| Electricity | _TODO: estimate_ |
| **Total** | _TODO_ |

## Security notes

- No ports forwarded; access only through Tailscale
- SSH keys only, no password login
- Backups encrypted client-side (restic) and at rest (LUKS2)
- Secrets live in a password manager and on paper, not in this repo

## Setup (outline)

1. Install Ubuntu Server, reserve a LAN IP, enable SSH keys only
2. Install Docker and Tailscale
3. Copy `.env.example` to `.env`, fill in values, then `docker compose up -d`
4. Create the Immich admin account and connect the iPhone app over Tailscale
5. Import existing media with immich-go
6. Configure restic + rclone, then add the cron jobs
7. Run a restore test before trusting anything

## Repo hygiene

Never commit: `.env`, `.restic-pass`, `rclone.conf`, LUKS header backups. See `.gitignore` and `.env.example`.
