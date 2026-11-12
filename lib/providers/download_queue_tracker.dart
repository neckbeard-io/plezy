import 'package:flutter/foundation.dart';

import '../media/download_queue_summary.dart';
import '../media/media_item.dart';
import '../models/download_models.dart';
import '../mixins/disposable_change_notifier_mixin.dart';
import 'download_provider.dart';

/// Follows a [DownloadProvider] and summarizes the current download run:
/// every item queued since the queue last drained, so the summary counts
/// "3 of 12 downloaded" instead of only what is left.
///
/// Attached to the provider for its lifetime ([attach] at creation, [of]
/// anywhere it is in scope), so the run is tracked whether or not the
/// Downloads screen is open.
class DownloadQueueTracker extends ChangeNotifier with DisposableChangeNotifierMixin {
  /// Track the run of [_source], whose [_downloads] and [_metadataFor] it
  /// reads each time it notifies.
  @visibleForTesting
  DownloadQueueTracker.forSource({required this._source, required this._downloads, required this._metadataFor}) {
    _source.addListener(_onProviderChanged);
    _onProviderChanged();
  }

  DownloadQueueTracker._(DownloadProvider provider)
    : this.forSource(source: provider, downloads: () => provider.downloads, metadataFor: provider.getMetadata);

  static final _trackers = Expando<DownloadQueueTracker>('DownloadQueueTracker');

  /// Attach a tracker to [provider] and return the provider.
  static DownloadProvider attach(DownloadProvider provider) {
    of(provider);
    return provider;
  }

  /// The tracker attached to [provider], attaching one if needed.
  static DownloadQueueTracker of(DownloadProvider provider) => _trackers[provider] ??= DownloadQueueTracker._(provider);

  /// Weight of the newest speed sample in the smoothed speed.
  static const _speedSmoothing = 0.3;

  final Listenable _source;
  final Map<String, DownloadProgress> Function() _downloads;
  final MediaItem? Function(String globalKey) _metadataFor;

  /// The run's items in the order they were first seen.
  final Set<String> _runKeys = <String>{};
  double _speed = 0;
  DownloadQueueSummary? _summary;

  /// The current run, or null while nothing is queued or downloading.
  DownloadQueueSummary? get summary => _summary;

  void _onProviderChanged() {
    final downloads = _downloads();
    final pending = [
      for (final entry in downloads.entries)
        if (isPendingDownloadStatus(entry.value.status)) entry.key,
    ];
    if (pending.isEmpty) {
      // The run is over: the next queued item starts a new one.
      final hadSummary = _summary != null;
      _runKeys.clear();
      _speed = 0;
      _summary = null;
      if (hadSummary) safeNotifyListeners();
      return;
    }

    _runKeys
      ..addAll(pending)
      ..removeWhere((key) => !downloads.containsKey(key));

    var sampled = 0.0;
    var transferring = false;
    final entries = <DownloadQueueEntry>[];
    for (final key in _runKeys) {
      final progress = downloads[key]!;
      if (progress.status == DownloadStatus.downloading) {
        transferring = true;
        sampled += progress.speed;
      }
      final metadata = _metadataFor(key);
      entries.add((
        progress: progress,
        durationMs: metadata?.durationMs,
        title: metadata == null ? null : downloadQueueLabel(metadata),
      ));
    }
    if (!transferring) {
      _speed = 0;
    } else if (sampled > 0) {
      _speed = _speed == 0 ? sampled : _speed + (sampled - _speed) * _speedSmoothing;
    }

    _summary = summarizeDownloadQueue(entries, speed: _speed);
    safeNotifyListeners();
  }

  @override
  void dispose() {
    _source.removeListener(_onProviderChanged);
    super.dispose();
  }

  @visibleForTesting
  Set<String> get debugRunKeys => Set.unmodifiable(_runKeys);
}
