# Changelog — testing-release (Fork)

All notable changes from our fork, merged into `testing-release`.

---

## Video Player & OSD

- **Timeline-first focus** — OSD now opens with the seek bar focused instead of the play/pause row, matching Plex client behavior.
- **Plex-style OK button setting** — New playback setting: when enabled, OK/Select shows OSD with seek bar focused (no play/pause toggle). OK on the seekbar toggles play/pause.
- **LEFT/RIGHT d-pad seek fix** — D-pad left/right now correctly seek when controls are visible but focus hasn't been explicitly set.
- **Play/pause key focuses timeline** — Pressing play/pause focuses the timeline instead of the play/pause button.
- **Scrub hold release fix** — Keyboard seeking now properly releases the scrub hold to unstick OSD controls.
- **UP in Plex control mode focuses skip button** — When Plex control mode is enabled, pressing UP from the hidden seekbar position focuses the skip intro/credits button instead of opening the full OSD.
- **Suppress transient play/pause during ExoPlayer seeks** — Fixes Android-specific issue where seeking triggered false pause/play state changes, causing spurious Plex webhooks (e.g. home-automation lights toggling).

## Skip Intro / Credits

- **Back button on skip button** — Back now cancels an active auto-skip countdown on first press, then deactivates the skip button on second press (moving focus to the timeline).
- **Suppress skip marker reappearance** — After skipping, the marker no longer briefly reappears when the post-seek position lands on the marker boundary. DOWN navigation from skip button also fixed.
- **Skip button opacity** — Now focus-driven: 80% when unfocused in keyboard mode, full opacity on touch/focus.

## Episode Navigation

- **Cancel on play-next dialog exits player** — Pressing cancel on the "Play Next" dialog now properly exits the video player instead of leaving a black screen.
- **Respect Plex-style OK setting after episode swap** — Focus target after an in-player episode swap now respects the Plex-style OSD setting.

## Continue Watching

- **Next unwatched episode after playback** — After finishing an episode, the Continue Watching row now immediately removes the watched episode and refreshes with a short delay so the server has time to update its hub cache. Fixes the issue (primarily on Android TV) where the old watched episode was still shown instead of the next unwatched one.

## Context Menus

- **Go to Season long-press option** — Re-adds "Go to Season" to the episode context menu, navigating to the season detail screen with the episode pre-selected.
- **Go to Show / Go to Season in Continue Watching** — "Go to Show" and "Go to Season" options now appear when long-pressing episodes in the Continue Watching section (previously hidden).
- **Playlist item context menu** — Long-press context menu added for playlist items via d-pad/keyboard.

## Per-Episode Cast (TV Layout)

- **Per-episode cast on TV detail screen** — When browsing a show on the TV layout, focusing an episode lazily fetches and caches that episode's cast. The cast hub title dynamically shows the episode name. Falls back to show-level cast when episode-specific cast isn't available.

## Library & Sidebar Navigation

- **Per-server visibility** — Ability to hide entire media servers from the UI.
- **Library visibility UX** — Single press to hide a library, long press to reorder. Full controller/d-pad support.
- **Library reorder focus tracking** — Focused/highlighted row stays visible during reorder (auto-scrolls into view). Consistent highlight brightness across focus states.
- **Sidebar focus restoration** — Returning to the side navigation rail now scrolls the restored item into view (previously could be focused but off-screen).
- **Focus after hiding library** — Re-focuses the next item to prevent ghost-item effect.
- **Context menu for library options** — Replaces popup menu button with a context menu.

## Playlists

- **Resume playback & watch state indicators** — Default play action finds and resumes from the first unwatched/partially-watched item. "Play from Beginning" button added. Playlist item cards show watched checkmarks and progress bars.
- **Back button fix** — Back on playlist detail screen now pops directly from list items.

## Media Detail

- **Genre display** — Genres now shown in detail screen metadata.

## Other

- **Select key handling fix** — Timer-based tap vs long-press detection for controller D-pad.
- **WatchStateStore migration** — Updated playlist resume code to use `WatchStateStore` (replacing deleted `WatchStateOverlayProvider`).
