# Plezy Custom Feature Portfolio Catalog

Reference catalog for auditing and carrying local customizations forward when pulling new upstream releases.

Every feature lives as one or more plain commits on `testing-release-<version>`; there are no per-feature branches. Commit references below are the feature's commit on the most recent release branch. Update them after every sync, and keep the key files in step with `FEATURES` in `scripts/audit_features.py`.

---

## 1. `android-seeking-fix`
* **Purpose**: Suppresses transient play/pause events during ExoPlayer seeks on Android TV / Shield devices, preventing audio/video glitching and stutter during seeking.
* **Key Files**:
  - `android/app/src/main/kotlin/com/edde746/plezy/exoplayer/ExoPlayerCore.kt`
* **Audit Check against Upstream**:
  - Check if upstream changed ExoPlayer seek dispatch or added transient event suppression.
* **Commit History Reference**:
  - `8a515cf0` on `testing-release-2.26.0`

---

## 2. `view-all-breaks-media`
* **Purpose**: Makes artwork and poster cache keys endpoint-independent so navigating into and out of "View All" library screens does not drop active media or display black thumbnails.
* **Key Files**:
  - `lib/utils/media_image_helper.dart`
* **Audit Check against Upstream**:
  - Check if upstream altered image caching URI construction or made image keys server-agnostic.
* **Commit History Reference**:
  - `7060f577` on `testing-release-2.26.0`

---

## 3. `per-episode-cast`
* **Purpose**: Displays per-episode guest stars and crew on episode detail screens (especially on TV UI) instead of falling back solely to series-level actors.
* **Key Files**:
  - `lib/screens/media_detail_screen.dart`
* **Audit Check against Upstream**:
  - Check if upstream added episode guest star / crew display to the detail screen.
  - Since 2.24.0 upstream caches `_tvDetailActorItems` by metadata identity; ours keys that cache on the role list too, so the cast follows the focused episode.
* **Commit History Reference**:
  - `c7613382` on `testing-release-2.26.0`

---

## 4. `watched-refresh`
* **Purpose**: Fixes "Continue Watching" / On Deck refresh after finishing playback by integrating an 800ms debounce settle delay alongside upstream's parent-aware item eviction.
* **Key Files**:
  - `lib/providers/discover_provider.dart`
  - `lib/screens/discover_screen.dart`
* **Audit Check against Upstream**:
  - Check upstream commits touching `discover_provider.dart` for watch state invalidation or local watch patch settling.
* **Commit History Reference**:
  - `c69d8994` on `testing-release-2.26.0`

---

## 5. `next-up-fixes`
* **Purpose**: Prevents a black screen when canceling the "Play Next" dialog at the end of an episode, properly exiting back to the media details screen.
* **Key Files**:
  - `lib/screens/video_player/parts/playback_prompts.dart`
* **Audit Check against Upstream**:
  - Check upstream changes to "Play Next" / auto-advance dialog cancellation and player exit handling.
* **Commit History Reference**:
  - `b48ab443` on `testing-release-2.26.0`

---

## 6. `season-show-long-press`
* **Purpose**: Adds context menu actions on D-pad / keyboard long-press for season and show cards (e.g., "Go to Season", "Go to Series" in Continue Watching and Hub screens).
* **Key Files**:
  - `lib/widgets/media_context_menu.dart`
* **Audit Check against Upstream**:
  - Check if upstream implemented "Go to Season" / "Go to Series" menu actions.
* **Commit History Reference**:
  - `7734ee91` on `testing-release-2.26.0`

---

## 7. `osd-focus-changes`
* **Purpose**: Implements Plex-style OSD (`selectShowsOsdTimeline` preference) where OK/Select or Play/Pause raises the controls with timeline/seek bar focused first instead of toggling playback in place. Also adds focus-lost directional self-healing key listeners.
* **Key Files**:
  - `lib/widgets/video_controls/player_chrome_controller.dart`
  - `lib/widgets/video_controls/desktop_video_controls.dart`
  - `lib/widgets/video_controls/parts/visibility.dart`
  - `lib/widgets/video_controls/parts/key_events.dart`
  - `lib/screens/video_player/parts/episode_navigation.dart`
  - `lib/services/settings_service.dart`
* **Audit Check against Upstream**:
  - Check upstream commits touching `key_events.dart`, `visibility.dart`, and `player_chrome_controller.dart` (e.g. key event classification refactors).
* **Commit History Reference**:
  - `ac786bd4` on `testing-release-2.26.0`

---

## 8. `skip-credit-changes`
* **Purpose**: Adds "Suppress Skip Reappearance" setting (`suppressSkipReappearance`) to ensure intro/credit buttons appear at most once per video session (and suppresses repeated false-positive credits markers in long broadcasts/UFC events). Also routes DOWN navigation off the skip button directly to the timeline seek bar. Suppressed markers stay reachable via the OSD or ArrowUp. Upstream #2049 handles dismissing skip markers on Back natively.
* **Key Files**:
  - `lib/widgets/video_controls/parts/markers.dart`
  - `lib/screens/settings/playback_settings_screen.dart`
  - `lib/services/settings_service.dart`
* **Audit Check against Upstream**:
  - Check upstream skip marker behavior (e.g. per-marker skip modes, dismiss on Back). Ensure `suppressSkipReappearance` and D-pad navigation down to the timeline are preserved.
* **Commit History Reference**:
  - `9b899c61` on `testing-release-2.26.0`

---

## 9. `playlist-enhancements`
* **Purpose**: Adds playlist resume support (Play resumes at the first partially-watched, else first unwatched, item; a "Play from Beginning" app-bar action keeps the old behaviour) and makes Back leave the playlist in a single press. D-pad long-press context menus on playlist rows were upstreamed in `7cc2f4c6` and are no longer carried.
* **Key Files**:
  - `lib/screens/playlist/playlist_detail_screen.dart`
* **Audit Check against Upstream**:
  - Check if upstream added playlist resume or changed playlist Back handling.
* **Commit History Reference**:
  - `4505f3e8` on `testing-release-2.26.0`, restored after being dropped in the 2.22.0 sync

---

## 10. `per-server-visibility`
* **Purpose**: Adds hidden media servers setting (`HiddenServersProvider` and `Settings > Media Servers`) to hide selected servers and their libraries/hubs across the app without disconnecting or unlinking accounts.
* **Key Files**:
  - `lib/providers/hidden_servers_provider.dart`
  - `lib/screens/settings/media_servers_screen.dart`
  - `lib/providers/libraries_provider.dart`
* **Audit Check against Upstream**:
  - Check upstream settings and library providers for any server visibility/hiding features.
* **Commit History Reference**:
  - `58c2deee` on `testing-release-2.26.0`

---

## 11. `osd-air-date`
* **Purpose**: Shows the air date for episodes and the release year for movies in the OSD's top-left header, just left of the runtime, which stays the rightmost value. A line below names the active player (ExoPlayer or MPV) and switches to MPV when ExoPlayer falls back to mpv mid-session. The single-line (macOS) layout appends both after the title.
* **Key Files**:
  - `lib/widgets/video_controls/widgets/video_controls_header.dart`
  - `lib/mpv/player/active_player_type.dart`
  - `lib/widgets/video_controls/desktop_video_controls.dart`, `lib/widgets/video_controls/mobile_video_controls.dart` (pass `player:`)
  - `test/widgets/video_controls_header_test.dart`
* **Audit Check against Upstream**:
  - Check if upstream added a date, year or player name to the player header, restructured `_buildMultiLineTitle` / `_buildSingleLineTitle`, or changed how `PlayerAndroid` reports its mpv fallback (`usingMpvFallback`, `backendSwitched`).
* **Commit History Reference**:
  - `f713ffd8` on `testing-release-2.26.0`

---

## 12. `watched-total-count`
* **Purpose**: Adds a "Show Watched / Total" setting (`showWatchedTotalCount`, on by default) that replaces the unwatched-count pill on show and season posters with watched/total. It only applies while "Show Unwatched Count" is on, and finished shows keep their checkmark. Episode cards on hubs such as Continue Watching also get their series' watched/total, fetched per show by `ShowWatchCountsProvider` (profile-scoped, refetched after a settle delay on watch events, refreshed after 15 minutes).
* **Key Files**:
  - `lib/providers/show_watch_counts_provider.dart`
  - `lib/media/leaf_watch_count.dart`
  - `lib/widgets/watched_indicator.dart`
  - `lib/widgets/unwatched_count_badge.dart`
  - `lib/widgets/media_card.dart` (passes `showSeriesCount: true`)
  - `lib/navigation/profile_session_screen.dart` (registers the provider)
  - `lib/services/settings_service.dart`, `lib/screens/settings/appearance_settings_screen.dart`
* **Audit Check against Upstream**:
  - Check if upstream added a watched/total format or series counts on episode cards, or reworked `WatchedIndicator` / `UnwatchedCountBadge`.
* **Commit History Reference**:
  - `aec5ab6b` on `testing-release-2.26.0`

---

## 13. `fresh-audio-track`
* **Purpose**: Sets `gapless-audio=no` on the Android mpv video core so every file (including the next episode loaded in place) opens its own AudioTrack. With mpv's default `weak`, the next episode inherited the finished one's paused, flushed passthrough track, leaving A/V sync far off and video stuttering until the player was exited; seeking only reset the track. The audio-only (music) core keeps `gapless-audio=weak`.
* **Key Files**:
  - `android/app/src/main/kotlin/com/edde746/plezy/mpv/MpvPlayerCore.kt` (`setOption("gapless-audio", "no")` in the video-core branch of `MpvPlayer.create`)
* **Audit Check against Upstream**:
  - Check if upstream sets `gapless-audio` for the video core, or if mpv-build's `ao_audiotrack` now reopens or resets the track across an in-place `loadfile`. Re-test pause/resume and episode transitions with Dolby passthrough on a Shield: logcat `[MPV:ao/audiotrack] getLatency: written=... playhead=0` followed by a large locked `delay` is the desync signature.
* **Commit History Reference**:
  - `72bee8bb` on `testing-release-2.26.0`

---

## 14. `ipv6-endpoint-escape`
* **Purpose**: Moves a Plex session off a direct IPv6 endpoint once its direct IPv4 sibling (same network class) answers again. A failover after a device sleep, or a missed IPv4 probe at bind, otherwise left the session on the AAAA-only `plex.direct` host for the life of the process; ExoPlayer's data source and Android downloads cannot resolve it on a LAN with only a ULA prefix (no global IPv6 route), so every ExoPlayer start failed with `UnknownHostException` and fell back to mpv. The relay-escape prober and the resume re-optimization now treat that endpoint as escapable.
* **Key Files**:
  - `lib/services/multi_server_manager.dart` (`_isOnEscapableEndpoint`, `_isOnIPv6WithIPv4Sibling`, `reoptimizeDemotedServers`)
  - `lib/services/plex_auth_service.dart` (`PlexServer.isIPv6WithIPv4Sibling`)
  - `test/services/multi_server_manager_test.dart`
* **Audit Check against Upstream**:
  - Check if upstream changed `reoptimizeDemotedServers`, `_syncRelayEscape` / `_runRelayEscape`, or how failover orders IPv6 within a class bucket.
* **Commit History Reference**:
  - `c3900a2c` on `testing-release-2.26.0`

---

## 15. `download-queue`
* **Purpose**: Makes an Android download queue survive screen sleep and reads as one job. Downloads run as user-initiated data transfer jobs on Android 14+ (task priority 0 + `RUN_USER_INITIATED_JOBS`) and as foreground jobs below that (`Config.runInForeground`). The whole queue shares one group notification: "done of total downloaded · speed" title, "Show · S4 E3 · Title · NN% · time left" body, an overall progress bar and one Cancel, with no per-episode "complete" notifications. The Downloads screen shows a run summary card (done of total, current item, bytes of the run's estimated size, speed, time left; unstarted items are estimated from the run's bitrate and their runtime).
* **Plugin fork**: `pubspec.yaml` pins `background_downloader` to `neckbeard-io/background_downloader`, branch `plezy-download-queue` (upstream Plezy's pin `afa3fe6` + `e323479`: the group notification follows the active task's progress with new `{taskProgress}` token, `{progress}`/bar cover the whole group, updates throttled to 1/s; a Wi-Fi lock is held while a transfer runs). On every sync, if upstream repins `background_downloader`, rebase that branch onto the new ref, push it, and update the pin and its comment.
* **Key Files**:
  - `lib/services/download_manager_service.dart` (`configureNotificationForGroup` with `groupNotificationId`, `androidConfig` `runInForeground`, `_nativeTaskPriority`, `downloadQueueLabel` display name)
  - `lib/media/download_queue_summary.dart`, `lib/providers/download_queue_tracker.dart`, `lib/widgets/download_queue_summary_card.dart`
  - `lib/screens/downloads/downloads_screen.dart` (card under the background-work banner), `lib/main.dart` (`DownloadQueueTracker.attach`)
  - `android/app/src/main/AndroidManifest.xml`, `pubspec.yaml`, `lib/i18n/en.i18n.json` (`notificationQueue*`, `queueSummary*`)
* **Audit Check against Upstream**:
  - Check if upstream changed the notification config, task construction (`priority`, `displayName`), the Downloads screen header, or repinned `background_downloader`.
  - Re-test on an Android tablet: queue a season, turn the screen off, and confirm progress continues (`adb logcat | grep -iE "UIDT|JobScheduler|foreground"`; "falling back to WorkManager" when a later task is scheduled with the screen off means it ran without the user-initiated job).
* **Commit History Reference**:
  - `d693120a` on `testing-release-2.26.0`
