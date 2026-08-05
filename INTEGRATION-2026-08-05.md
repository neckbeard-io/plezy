# testing-release-2026-08-05 — integration report

New branch `testing-release-2026-08-05`, built on **upstream/main @ 9d51a040 (v2.12.1+127)**.
The old `testing-release` (2ad949f0, based on v2.6.0) is untouched.

The fork was **647 commits / six minor versions** behind upstream. Every file the
feature branches touched had been substantially rewritten upstream, so nothing
cherry-picked cleanly — each change was re-applied against the new code rather
than merged. Each topic branch was rebuilt as `<name>-2026-08-05` off the new
base and merged with `--no-ff`, mirroring the old structure.

## Result per branch

| Original branch | Outcome |
|---|---|
| `android-seeking-fix` | Carried over |
| `osd-focus-changes` (10 commits) | Carried over, 1 commit obsolete |
| `skip-credit-changes` | Carried over |
| `feature/fix-back-skip-focus` | Carried over (folded into skip-credit) |
| `next-up-fixes` | Carried over |
| `watched-refresh` | Carried over, reworked |
| `per-episode-cast` | Carried over, reworked |
| `season-show-long-press` | Carried over |
| `view-all-breaks-media` | Carried over (was **not** in old testing-release) |
| `feature/playlist-enhancements` (3) | Partly carried, 1 of 3 obsolete |
| `feature/per-server-visibility` (7) | 1 of 7 carried, 6 obsolete |
| `feature/genres` | **Fully obsolete** |
| `feature/fix-sidebar-focus` | **Fully obsolete** |

Net: 36 files changed, ~+1300/−70 against upstream/main.

---

## Already fixed or implemented upstream — dropped

**`feature/genres` — entirely superseded.** Upstream displays genres in both
places the branch patched, and does it better: a dedicated genre line on the TV
detail hero with proper height reservation against the logo
(`media_detail_screen.dart:3479`), genres folded into the accessibility label,
and per-genre chips on the desktop/mobile hero (`:4203`). Nothing to port.

**`feature/fix-sidebar-focus` — entirely superseded.** The branch added a
`_focusAndReveal` that requested focus then `Scrollable.ensureVisible`d, plus a
target → last-focused → Home precedence chain. Upstream has exactly this as
`SideNavigationRailState._requestFocusAndReveal` + `_resolveFocusNode`, with an
extra step (currently-selected tab/library) the branch didn't have.

**Six of seven `feature/per-server-visibility` commits — superseded.** All the
per-server *library* screen work (`bc95eec2`, `5bd7d8de`, `17e8e15d`,
`781f1bbc`, `8dd77530`, `d5d075bb`) is covered by upstream's
`showLibraryManagementSheet` + `DpadReorderMixin`: hide/unhide, D-pad reorder,
tap-vs-hold columns, server subtitles when multiple servers, tile-colour-driven
highlight. Upstream tracks focus by *index* rather than `FocusNode`, so the
three bugs those commits chased — highlight dropping across rebuilds, the
ghost-item effect after hiding, and focus not scrolling into view — cannot occur
in that design. Only server-level hiding was genuinely new; that is ported.

**Playlist watch-state indicators (part of `11f73d50`) — superseded.**
`WatchedIndicator(size: compact)` now sits in the playlist poster stack and
renders both the watched checkmark and the progress bar, and the card resolves
watch state through `WatchStateStore`. The hand-rolled
`_buildPosterWithWatchState` is redundant.

**`b1e4cb60` "release scrub hold after keyboard seeking" — obsolete.** The leak
is gone: upstream replaced the raw throttled seek with `DebouncedSeekAccumulator`
and split the scrub hold onto separate `onScrubStart`/`onScrubEnd` callbacks that
only the slider's drag gestures use. The keyboard path never takes
`PlayerChromeHold.scrub`, so there is nothing left to release.

**`showSharedServers` pref — dropped.** It was declared on the branch and never
read anywhere. Dead code.

---

## Conflict areas — where upstream and your changes disagreed

### 1. Player chrome on Play/Pause and OK (the significant one)

Upstream landed **#1676**, a deliberate redesign: transport keys now keep the
chrome *down* and announce the command with a transient centre disc, and
hidden-chrome LEFT/RIGHT seeks in place with a transient badge instead of
raising the OSD. Your `osd-focus-changes` branch does the opposite — Play/Pause
and OK raise the OSD with the seek bar focused.

**Resolution:** both behaviours coexist, gated on the existing **"Plex-style
OSD"** setting (`selectShowsOsdTimeline`, default off). Off = upstream's #1676
behaviour; on = your Plex-style OSD. This follows where your own commits were
already heading (`5027189c` explicitly tied play/pause focus to that setting).

Three items from the branch stayed **unconditional**, matching your final state:
`_focusPlayPauseIfKeyboardMode` → timeline, the screen's #1797 self-heal →
timeline, and OK-on-seekbar toggling play/pause. If you'd rather have those
follow the setting too, it is a small change.

`_showControlsWithTimelineFocus` no longer existed upstream; it is reintroduced
over the `PlayerChromeFocusTarget` API upstream added.

### 2. Continue Watching refresh timing

Upstream moved this logic out of `DiscoverScreen` into `DiscoverProvider` and
added request coalescing, and it refreshes **immediately** on a watch event.
That is the exact race your fix addressed — the server hasn't rebuilt its
on-deck hub yet, so the finished episode comes straight back.

**Resolution:** the deferral now lives beside `refreshContinueWatching` in the
provider and reuses its coalescing. **Two upstream tests asserted the immediate
refetch and were updated** to wait out the settle delay; the delay is exposed as
`DiscoverProvider.continueWatchingSettleDelay` (`@visibleForTesting`) so tests
don't spend 800 ms each. Added coverage for the drop-now/refetch-later split and
for a burst of watched events collapsing onto one refetch.

### 3. Per-episode cast vs. a deliberate performance optimisation

Upstream converted `_tvDetailFocusedEpisode` to a `ValueNotifier` specifically
so d-pad scrubbing across episodes repaints only the info panel, never the rail.
Your feature needs the cast hub — part of the hub list — to actually rebuild.

**Resolution:** `setState` is taken only when the effective role list changes
identity. Scrubbing across episodes with no per-episode credits keeps upstream's
rail-free repaint; the rebuild is paid only when the visible cast really changes.

### 4. Self-heal focus target test

`player_self_heal_keys_test.dart` asserted Tab lands on Play/Pause. Timeline-first
focus changes that to the seek bar — **test updated**, intentional behaviour change.

### 5. Playlist Back semantics

Upstream routes Back from the item list to the app bar (`handleBackFromContent`).
Your `71b67568` pops the route directly. Kept your behaviour — a two-press exit
from a flat list is surprising — but note this diverges from how other list
detail screens behave upstream.

### 6. Where hidden-server filtering lives

Your branch threaded a `hiddenServerIds` parameter through each aggregation
signature. Upstream's refactor gave `DataAggregationService` a single choke
point, `_clientsFor`, that every fan-out shares — the filter went there instead,
covering hubs, on-deck, libraries and search with one check.

Two deliberate carve-outs: `findByExternalIds` stays **unfiltered** (it is
identity resolution for Trakt/watchlist — "do I own this?" — not a browse
surface, and filtering it would make a hidden server's copy invisible to sync);
and the hidden set never reaches `MultiServerManager`, so downloads and direct
navigation on a hidden server keep working.

---

## Upstream Android playback you gain

This is the largest single win of the rebase. **193 commits** touch
`android/`, the player screen, or the video controls between v2.6.0 and v2.12.1.
Highlights from `exoplayer/` alone:

- Dolby Vision seek crashes fixed; DV bitstream sanitiser rewritten
- ExoPlayer retry after decoder loss; forced codec re-init on TV surface changes
  (recovers video after screensaver); auto-recovery of frozen video after
  pause/resume on stalling decoders
- Finish the item when ExoPlayer never signals end of playback
- Ghost playback after autoplay failures fixed
- Tunnelled decoded-PCM audio restored; passthrough control wired; direct audio
  blocked without passthrough; every AudioTrack release now reported so a failed
  one can recover
- AAC-LATM (LOAS) unwrapping in MKV direct streams; FFmpeg audio decoder kept
  through R8; side-loaded subtitle matching after media3 rewrote track ids
- Plex transcode seeking repaired; HLS live-TV playback stabilised
- Startup/runtime exit diagnostics persisted; cronet init fallback

**One interaction worth knowing:** upstream's `ad3af474` "emit playback-restart
after every seek" also concerns post-seek events, but on the `playback-restart`
event path (Watch Together / frame-rate matching). Your `isSeeking` gate only
suppresses the outward `"pause"` property change. They are orthogonal and both
apply. The re-applied version also deliberately keeps upstream's frame-watchdog
and resume-stall bookkeeping running on both seek edges — only the outward pause
event is withheld.

---

## Verification

- `dart analyze lib/ test/` — clean.
- Full `flutter test` — **5488 passed, 5 skipped, 0 failed**.
- Android `:app:testDebugUnitTest` — **BUILD SUCCESSFUL**, 296 tests across 33
  suites, 0 failures. This compiles the edited `ExoPlayerCore.kt` and runs the
  ExoPlayer suites, including `ExoPlayerFallbackTerminalTest`, which covers the
  post-seek `playback-restart` path the seek fix sits next to.
- 49 pre-existing analyzer errors exist under the vendored, untracked
  `packages/` directory (wakelock_plus / shared_preferences test files). They are
  present identically on untouched `upstream/main` and are unrelated to this work.

### Needs a device pass

Everything below only shows on a TV/remote and was not exercised here: Plex-style
OSD focus, the skip-button Back handling, playlist long-press, per-episode cast,
and hiding a server.
