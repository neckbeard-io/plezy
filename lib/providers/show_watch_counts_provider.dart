import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../media/ids.dart';
import '../media/leaf_watch_count.dart';
import '../media/media_item.dart';
import '../mixins/disposable_change_notifier_mixin.dart';
import '../utils/app_logger.dart';
import '../utils/global_key_utils.dart';
import '../utils/watch_state_notifier.dart';

typedef ShowItemFetcher = Future<MediaItem?> Function(ServerId serverId, String showId);

class _Entry {
  const _Entry(this.serverId, this.showId, this.count, this.fetchedAt);

  final ServerId serverId;
  final String showId;
  final LeafWatchCount? count;
  final DateTime fetchedAt;
}

/// Series-level watched/total counts for episode cards.
///
/// Episode rows (Continue Watching, hubs) don't carry their show's leaf
/// counts, so the show is fetched on first use and cached. A watch event
/// under a cached show refetches it once the server has settled, and an entry
/// older than [maxAge] refreshes on its next read. The previous count stays
/// on screen until the new one lands.
class ShowWatchCountsProvider extends ChangeNotifier with DisposableChangeNotifierMixin {
  ShowWatchCountsProvider({required this.fetchShow}) {
    _subscription = WatchStateNotifier().stream.listen(_onWatchStateEvent);
  }

  final ShowItemFetcher fetchShow;
  StreamSubscription<WatchStateEvent>? _subscription;
  final Map<String, _Entry> _entries = {};
  final Set<String> _inFlight = {};
  final Set<String> _pendingRefresh = {};
  Timer? _refreshTimer;

  /// How long to wait after a watch event before re-reading the show, so the
  /// server has applied the scrobble. Shortened in tests.
  @visibleForTesting
  static Duration settleDelay = Platform.environment.containsKey('FLUTTER_TEST')
      ? Duration.zero
      : const Duration(seconds: 2);

  /// Picks up watches made on other devices.
  static const maxAge = Duration(minutes: 15);

  /// The series count for [episode], or null until it has loaded. Safe to
  /// call during build: a fetch it starts notifies asynchronously.
  LeafWatchCount? countFor(MediaItem episode) {
    final serverId = episode.serverId;
    final showId = episode.grandparentId;
    if (serverId == null || showId == null) return null;
    final key = buildGlobalKey(ServerId(serverId), showId);
    final entry = _entries[key];
    if (entry == null || DateTime.now().difference(entry.fetchedAt) > maxAge) {
      _fetch(key, ServerId(serverId), showId);
    }
    return entry?.count;
  }

  void _fetch(String key, ServerId serverId, String showId) {
    if (!_inFlight.add(key)) return;
    unawaited(_load(key, serverId, showId));
  }

  Future<void> _load(String key, ServerId serverId, String showId) async {
    LeafWatchCount? count;
    var failed = false;
    try {
      count = (await fetchShow(serverId, showId))?.leafWatchCount;
    } catch (e) {
      appLogger.d('Show watch count fetch failed for $key', error: e);
      failed = true;
    } finally {
      _inFlight.remove(key);
    }
    if (isDisposed) return;
    final previous = _entries[key]?.count;
    // A failed refresh keeps the last good count rather than blanking the badge.
    final next = failed ? previous : count;
    _entries[key] = _Entry(serverId, showId, next, DateTime.now());
    if (next != previous) safeNotifyListeners();
  }

  void _onWatchStateEvent(WatchStateEvent event) {
    // Progress ticks don't change how many episodes are watched.
    if (event.changeType != WatchStateChangeType.watched && event.changeType != WatchStateChangeType.unwatched) {
      return;
    }
    final keys = [event.globalKey, for (final id in event.parentChain) buildGlobalKey(event.serverId, id)];
    final cached = keys.where(_entries.containsKey).toList();
    if (cached.isEmpty) return;
    _pendingRefresh.addAll(cached);
    _refreshTimer?.cancel();
    _refreshTimer = Timer(settleDelay, _refreshPending);
  }

  void _refreshPending() {
    _refreshTimer = null;
    if (isDisposed) return;
    final keys = _pendingRefresh.toList();
    _pendingRefresh.clear();
    for (final key in keys) {
      final entry = _entries[key];
      if (entry != null) _fetch(key, entry.serverId, entry.showId);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
