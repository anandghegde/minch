# Minch ↔ torbox-cli Feature Gap Analysis

Reviewed `github.com/SwordfishTrumpet/torbox-cli` (commit pulled 2026-05-26).

**What Minch already does** (verified in `Packages/MinchAPI/.../Endpoint.swift` + `TorBoxClient.swift`):
- `GET /user/me`
- `GET /torrents/mylist`
- `GET /torrents/torrentinfo` (defined, currently unused)
- `POST /torrents/createtorrent` (magnet add)
- `GET /torrents/requestdl` (download + Stream in-app)
- `POST /torrents/controltorrent` (pause / resume / reannounce / delete)

Everything below is in the CLI but **not in Minch**.

---

## 0. Voyager Search API (`search-api.torbox.app`) — not a CLI feature, but the largest Minch gap by user value

Not in the CLI (the CLI's `search.py` was deleted in commit `429b641`), but it's a first-class TorBox-owned search service hosted separately from `api.torbox.app`. FastAPI service, same Bearer-token auth.

Endpoints (from `https://search-api.torbox.app/openapi.json`):
- `GET /meta/search/{query}?type=file|media` — title/ID metadata search
- `GET /meta/{id}?media_type=movies|series` — metadata lookup by ID
- `GET /torrents/search/{query}` — torrent index search (works on free plan)
- `GET /torrents/{id}?season=&episode=` — torrent lookup by media ID
- `GET /usenet/search/{query}` — usenet search (Pro plan)
- `GET /usenet/{id}` + `GET /usenet/download/{id}/{guid}` — usenet lookup + NZB fetch
- `GET /torznab/api`, `GET /newznab/api` — full Sonarr/Radarr-compatible endpoints

Per-query flags (booleans, default false): `check_cache`, `check_owned`, `cached_only`, `search_user_engines`. These light up cache-awareness on every result row — much richer than any generic indexer.

Multi-ID support per the v7.4 changelog: TMDB / TVMaze / TVDB / Kitsu / Anilist / MAL, plus anime via `mediaType: anime` (Nyaa.si + Animetosho).

UX: a Find tab in Minch. Type a query → result list with "Cached" / "Owned" badges → one-tap add via the existing `addMagnet` path.

---

## A. Whole feature surfaces the CLI has, Minch has none of

### 1. Web downloads (`/webdl/...`)
HTTP-link downloads (Mega, Mediafire, etc.). Endpoints: `mylist`, `createwebdownload`, `asynccreatewebdownload`, `controlwebdownload`, `editwebdownload`, `requestdl`, `hosters`, `checkcached`.
Equivalent UX value: Minch could accept any direct/file-host link in the "Add" sheet, not just magnets.

### 2. Usenet (`/usenet/...`)
NZB downloads. Endpoints: `mylist`, `createusenetdownload`, `controlusenetdownload`, `editusenetdownload`, `requestdl`, `nzbtofile`, `checkcached`.
UX: drag-drop an `.nzb`, same library row treatment.

### 3. Queued downloads (`/queued/...`)
Items waiting on slots. Endpoints: `getqueued`, `addqueued`, `controlqueued`.
UX: dedicated "Queued" section in sidebar (separate from active transfers).

### 4. RSS feeds (`/rss/...`)
Subscribe to torrent/usenet feeds, auto-add matches. Endpoints: `getfeeds`, `getfeeditems`, `addrss`, `modifyrss`, `controlrss` (delete).
UX: a Feeds tab — recurring auto-ingest beyond the current local watch folder.

### 5. Stream tokens (`/stream/...`)
The CLI's `stream` group is **richer than Minch's in-app streaming**:
- `POST /stream/createstream` — issues a stream token
- `GET /stream/getstreamdata` — supports `--subtitle-index`, `--audio-index`, `--resolution-index` for **track selection**
- `DELETE /stream/deletestream` — revoke a token

Minch currently just opens the raw `requestdl` URL in AVPlayer with no track switching, no transcode controls. This API would let us add a subtitle/audio picker overlay in `PlayerView` and revoke tokens on close.

### 6. Notifications (`/notifications/...`)
Endpoints: `mynotifications` (list), `rss` (feed URL), `test`, `clear`.
UX: a bell icon → notification inbox sourced from TorBox itself (server-side events the user has on other devices), separate from Minch's local `Notifier`.

### 7. Integrations / cloud upload jobs (`/integration/...`)
TorBox can push completed downloads to S3/GDrive/etc. Endpoints: `GET /integration/jobs/{hash}`, `DELETE /integration/job/{job_id}`.
UX: show pending cloud uploads on a transfer row, cancel button.

### 8. Live monitor (`torbox monitor`)
htop-style dashboard with refresh interval, sort columns (status/name/size/speed/progress), name/status filter, max-per-category, compact mode. Pulls from all surfaces (torrents + webdl + usenet) at once.
UX: Minch's Library is the equivalent for torrents, but lacks combined-surface view and live-speed/ETA columns.

---

## B. Endpoints Minch is missing inside features it already has

### Torrents
- **`PUT /torrents/edittorrent`** (rename, retag, set alternative hashes). Minch has no in-app rename. Currently we only persist tags locally via `StoredTransfer.tagNames`; this would sync them to TorBox.
- **`POST /torrents/checkcached`** — instant-availability check before adding.
- **`POST /torrents/asynccreatetorrent`** — non-blocking add for large magnets.
- **`POST /torrents/magnettofile`** — export a `.torrent` file.
- **Create flags Minch ignores**:
  - `name` (custom name)
  - `seed` option (1=auto, 2=always, 3=never)
  - `as_queued` (add directly to the queue)
  - `allow_zip`
  - `cache_only` (only add if already cached server-side)
- **requestdl flags Minch ignores**: `zip_link`, `redirect`, `user_ip`, append-filename.

### User
- **`GET /user/settings`** — surface server-side preferences in Settings.
- **`GET /user/transactions`** + **`GET /user/transaction/pdf?id=...`** — billing history & PDFs.
- **`GET /user/settings/searchengines`** — search-engine list.
- **`GET /user/getconfirmation`** — confirmation codes.
- **Device auth flow** — `GET /user/auth/device/start`, `GET /user/auth/device/poll`, `POST /user/auth/device/complete`. **This is a code-grant style sign-in** as an alternative to pasting an API key. Onboarding could become: "Click to sign in → user-code shown → poll → done." Friendlier than the API-key paste box, and the existing key flow can stay as fallback.

### General (public, no auth)
- **`GET /stats`** — service-wide stats (active downloads, server health).
- **`GET /changelogs/json`** — TorBox changelog (could surface in About sheet or a "What's new on TorBox" banner; Minch's Sparkle updater is separate).
- **`GET /speedtest`** — built-in speed test (region selectable).

---

## C. CLI-only ergonomics that have app analogues worth borrowing

These are CLI niceties, but a few translate to in-app value:

- **Auto-retry on HTTP 429 with backoff** (`--auto-retry`). `TorBoxClient.mapStatus` already classifies 429 as `.quota`, but we surface it as a banner and stop. Retrying with exponential backoff inside the client (e.g., on `listTransfers` polling) would smooth over rate-limit blips silently.
- **Pagination on lists** (`--offset` / `--limit`). Not user-visible in Minch since SwiftData handles all the data, but `listTransfers` currently fetches everything every poll; adding offset/limit would matter once users grow large libraries.
- **Multi-format add for create** (CLI takes magnet OR `.torrent` file). Minch currently only accepts `magnet:`. Drag-and-drop of a `.torrent` file (and `.nzb` once usenet lands) would close that gap.

---

## D. CLI-only and not app-relevant

Skipped — listed for completeness so we don't reinvent them: `--json` raw output, `--field` dot-path extraction, `--dry-run`, `man`-page generation, profile-based multi-account config, `doctor` config validator, Stremio/Cinemeta search (an unofficial add-on layered on top of TorBox, not a TorBox API).

---

## Suggested next sprints

If we wanted to prioritize, I'd group it like this:

1. **Sprint A — Voyager Search + round out torrents** *(highest user value)*: ship a Find tab against `search-api.torbox.app` (`/meta/search`, `/torrents/search` with `check_cache=true`/`check_owned=true`) → cache/owned-badged result list → one-tap add via the existing `addMagnet` path. Plus: server-side rename + tag sync (`edittorrent`), `checkcached` preflight on Add, support `cache_only` and `name` create options, accept `.torrent` files in the Add sheet, hit `requestdl` with `redirect=true` to avoid the second hop.
2. **Sprint B — Multi-surface library**: add Web Downloads + Usenet as first-class kinds alongside torrents. Reuse `StoredTransfer` with a `kind` discriminator. Most of the row/file UI carries over verbatim.
3. **Sprint C — Queued + RSS**: queued tab + RSS subscriptions. These are the biggest "automate my downloads" gaps.
4. **Sprint D — Player upgrade**: switch from raw `requestdl` streaming to `/stream/createstream` so we get audio/subtitle/resolution track selection; revoke tokens on close.
5. **Sprint E — Polish**: device-auth onboarding path (keeps the paste-key flow as fallback), notifications inbox, integration-jobs surface on transfer rows, transactions screen in Settings, 429 auto-retry inside `TorBoxClient`.
