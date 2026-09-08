# Plezy Custom Feature Portfolio Catalog

Reference catalog for auditing and re-integrating local customizations when pulling new upstream releases.

---

## 1. `android-seeking-fix`
* **Purpose**: Suppresses transient play/pause events during ExoPlayer seeks on Android TV / Shield devices, preventing audio/video glitching and stutter during seeking.
* **Key Files**:
  - `lib/widgets/video_controls/parts/seeking.dart`
  - `lib/mpv/player/player_platform.dart`
* **Audit Check against Upstream**:
  - Check if upstream modified seek dispatch or added transient event suppression in `seeking.dart` or ExoPlayer controllers.
* **Commit History Reference**:
  - `015b5c59` (`android-seeking-fix-2026-08-26`)

---

## 2. `view-all-breaks-media`
* **Purpose**: Makes artwork and poster cache keys endpoint-independent so navigating into and out of "View All" library screens does not drop active media or display black thumbnails.
* **Key Files**:
  - `lib/utils/media_image_helper.dart`
* **Audit Check against Upstream**:
  - Check if upstream altered image caching URI construction or made image keys server-agnostic.
* **Commit History Reference**:
  - `15319119` (`view-all-breaks-media-2026-08-26`)

---

## 3. `per-episode-cast`
* **Purpose**: Displays per-episode guest stars and crew on episode detail screens (especially on TV UI) instead of falling back solely to series-level actors.
* **Key Files**:
  - `lib/screens/tv/tv_episode_details_screen.dart`
  - `lib/widgets/tv_person_card.dart`
  - `lib/media/media_item.dart`
* **Audit Check against Upstream**:
  - Check if upstream added episode guest star / crew parsing to `MediaItem` or the TV episode details screen.
* **Commit History Reference**:
  - `5d386d0c` (`per-episode-cast-2026-08-26`)

---

## 4. `watched-refresh`
* **Purpose**: Fixes "Continue Watching" / On Deck refresh after finishing playback by integrating an 800ms debounce settle delay alongside upstream's parent-aware item eviction.
* **Key Files**:
  - `lib/providers/discover_provider.dart`
* **Audit Check against Upstream**:
  - Check upstream commits touching `discover_provider.dart` for watch state invalidation or local watch patch settling.
* **Commit History Reference**:
  - `9108b1dc` (`watched-refresh-2026-08-26`)

---

## 5. `next-up-fixes`
* **Purpose**: Prevents a black screen when canceling the "Play Next" dialog at the end of an episode, properly exiting back to the media details screen.
* **Key Files**:
  - `lib/widgets/video_controls/parts/markers.dart`
  - `lib/screens/video_player/video_player_screen.dart`
* **Audit Check against Upstream**:
  - Check upstream changes to "Play Next" / auto-advance dialog cancellation and player exit handling.
* **Commit History Reference**:
  - `e5ca7a65` (`next-up-fixes-2026-08-26`)

---

## 6. `season-show-long-press`
* **Purpose**: Adds context menu actions on D-pad / keyboard long-press for season and show cards (e.g., "Go to Season", "Go to Series" in Continue Watching and Hub screens).
* **Key Files**:
  - `lib/widgets/cards/media_card.dart`
  - `lib/widgets/cards/episode_card.dart`
  - `lib/widgets/cards/season_card.dart`
* **Audit Check against Upstream**:
  - Check if upstream implemented context menus for seasons/shows or D-pad long-press actions on cards.
* **Commit History Reference**:
  - `b21c2d11` (`season-show-long-press-2026-08-26`)

---

## 7. `osd-focus-changes`
* **Purpose**: Implements Plex-style OSD (`selectShowsOsdTimeline` preference) where OK/Select or Play/Pause raises the controls with timeline/seek bar focused first instead of toggling playback in place. Also adds focus-lost directional self-healing key listeners.
* **Key Files**:
  - `lib/services/settings_service.dart`
  - `lib/widgets/video_controls/player_chrome_controller.dart`
  - `lib/widgets/video_controls/desktop_video_controls.dart`
  - `lib/widgets/video_controls/parts/visibility.dart`
  - `lib/widgets/video_controls/parts/key_events.dart`
* **Audit Check against Upstream**:
  - Check upstream commits touching `key_events.dart`, `visibility.dart`, and `player_chrome_controller.dart` (e.g. key event classification refactors).
* **Commit History Reference**:
  - `b8661f49` (`osd-focus-changes-2026-08-26`)

---

## 8. `skip-credit-changes`
* **Purpose**: Adds "Suppress Skip Reappearance" setting (`suppressSkipReappearance`) to ensure intro/credit buttons appear at most once per video session (and suppresses repeated false-positive credits markers in long broadcasts/UFC events). Also routes DOWN navigation off the skip button directly to the timeline seek bar.
* **Key Files**:
  - `lib/services/settings_service.dart`
  - `lib/widgets/video_controls/parts/markers.dart`
  - `lib/widgets/video_controls/parts/key_events.dart`
  - `lib/screens/settings/playback_settings_screen.dart`
* **Audit Check against Upstream**:
  - Check upstream skip marker behavior (e.g. per-marker skip modes, dismiss on Back). Ensure `suppressSkipReappearance` and D-pad navigation down to the timeline are preserved.
* **Commit History Reference**:
  - `651c39a5` (`skip-credit-changes-2026-08-26`)

---

## 9. `playlist-enhancements`
* **Purpose**: Adds playlist resume support (resumes at the first unwatched or partially-watched item instead of always playing from index 0) and adds D-pad long-press context menus on playlist cards and playlist item rows.
* **Key Files**:
  - `lib/screens/playlist_detail_screen.dart`
  - `lib/widgets/cards/playlist_item_card.dart`
  - `lib/media/media_playlist.dart`
* **Audit Check against Upstream**:
  - Check if upstream added playlist resume or playlist item context menus.
* **Commit History Reference**:
  - `95420eee` (`playlist-enhancements-2026-08-26`)

---

## 10. `per-server-visibility`
* **Purpose**: Adds hidden media servers setting (`HiddenServersProvider` and `Settings > Media Servers`) to hide selected servers and their libraries/hubs across the app without disconnecting or unlinking accounts.
* **Key Files**:
  - `lib/providers/hidden_servers_provider.dart`
  - `lib/screens/settings/media_servers_screen.dart`
  - `lib/screens/settings/settings_screen.dart`
  - `lib/providers/libraries_provider.dart`
* **Audit Check against Upstream**:
  - Check upstream settings and library providers for any server visibility/hiding features.
* **Commit History Reference**:
  - `0fbea093` (`per-server-visibility-2026-08-26`)
