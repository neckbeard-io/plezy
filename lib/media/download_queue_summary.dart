import '../models/download_models.dart';
import '../utils/formatters.dart';
import 'media_item.dart';
import 'media_item_types.dart';

/// One item of a download run, as [summarizeDownloadQueue] reads it.
///
/// [durationMs] is the item's runtime from its metadata. Items that have not
/// started report no size, so the run's observed bytes per millisecond of
/// runtime stands in for theirs.
typedef DownloadQueueEntry = ({DownloadProgress progress, int? durationMs, String? title});

/// Overall state of a download run: everything queued since the queue last
/// drained.
class DownloadQueueSummary {
  const DownloadQueueSummary({
    required this.total,
    required this.completed,
    required this.failed,
    required this.downloadedBytes,
    required this.estimatedTotalBytes,
    required this.speed,
    required this.timeLeft,
    required this.currentTitle,
    required this.currentProgress,
  });

  /// Items in the run, cancelled ones excluded.
  final int total;
  final int completed;
  final int failed;

  /// Bytes on disk for the run so far.
  final int downloadedBytes;

  /// The run's size: exact for items that know theirs, estimated from the
  /// run's bitrate for the rest. Null when nothing gives an estimate yet.
  final int? estimatedTotalBytes;

  /// Current transfer speed in bytes per second, 0 when nothing transfers.
  final double speed;

  /// Time until the whole run is done at [speed]. Null while it cannot be
  /// estimated.
  final Duration? timeLeft;

  /// The item transferring now, and its own progress (0..1).
  final String? currentTitle;
  final double? currentProgress;

  /// Items still to download (queued, downloading or paused).
  int get remaining => total - completed - failed;

  /// Whole-run progress, 0..1: by bytes when the size is known, else by count.
  double get fraction {
    final totalBytes = estimatedTotalBytes;
    if (totalBytes != null && totalBytes > 0) return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
    if (total == 0) return 0;
    return ((completed + failed + (currentProgress ?? 0)) / total).clamp(0.0, 1.0);
  }
}

/// How a download is named in its notification and the queue summary: an
/// episode as "Show · S4 E3 · Title", anything else by its title.
///
/// An episode's [MediaItem.displayTitle] is its show's title, so the
/// episode's own title comes from [MediaItem.title].
String downloadQueueLabel(MediaItem item) {
  if (!item.isEpisode) return item.displayTitle;
  final episodeTitle = item.title;
  return toBulletedString([
    ?item.grandparentTitle,
    ?formatSeasonEpisodeLabel(item.parentIndex, item.index),
    if (episodeTitle != null && episodeTitle.isNotEmpty) episodeTitle,
  ]);
}

bool isPendingDownloadStatus(DownloadStatus status) =>
    status == DownloadStatus.queued || status == DownloadStatus.downloading || status == DownloadStatus.paused;

/// Summarize a download run from its [entries], transferring at [speed]
/// bytes per second.
DownloadQueueSummary summarizeDownloadQueue(List<DownloadQueueEntry> entries, {required double speed}) {
  var completed = 0;
  var failed = 0;
  var total = 0;

  // The run's bitrate: bytes per millisecond of runtime over the items whose
  // size is known, and their average size for items without a runtime.
  var sizedBytes = 0;
  var sizedDurationMs = 0;
  var sizedCount = 0;
  var sizedCountBytes = 0;
  for (final entry in entries) {
    final progress = entry.progress;
    if (progress.status == DownloadStatus.cancelled || progress.totalBytes <= 0) continue;
    sizedCount++;
    sizedCountBytes += progress.totalBytes;
    final durationMs = entry.durationMs;
    if (durationMs != null && durationMs > 0) {
      sizedBytes += progress.totalBytes;
      sizedDurationMs += durationMs;
    }
  }
  final bytesPerMs = sizedDurationMs > 0 ? sizedBytes / sizedDurationMs : null;
  final averageBytes = sizedCount > 0 ? sizedCountBytes / sizedCount : null;

  int? estimateSize(DownloadQueueEntry entry) {
    if (entry.progress.totalBytes > 0) return entry.progress.totalBytes;
    final durationMs = entry.durationMs;
    if (bytesPerMs != null && durationMs != null && durationMs > 0) return (bytesPerMs * durationMs).round();
    return averageBytes?.round();
  }

  var downloadedBytes = 0;
  var estimatedTotal = 0;
  var estimateComplete = true;
  String? currentTitle;
  double? currentProgress;
  for (final entry in entries) {
    final progress = entry.progress;
    switch (progress.status) {
      case DownloadStatus.cancelled:
        continue;
      case DownloadStatus.failed:
        // Will not be fetched: counts as finished and adds no bytes.
        total++;
        failed++;
        continue;
      case DownloadStatus.completed:
        total++;
        completed++;
      case DownloadStatus.downloading:
        total++;
        if (currentTitle == null) {
          currentTitle = entry.title;
          currentProgress = progress.progressPercent.clamp(0.0, 1.0);
        }
      default:
        total++;
    }
    final size = estimateSize(entry);
    if (size == null) {
      estimateComplete = false;
      downloadedBytes += progress.downloadedBytes;
      continue;
    }
    estimatedTotal += size;
    downloadedBytes += progress.status == DownloadStatus.completed ? size : progress.downloadedBytes.clamp(0, size);
  }

  final estimatedTotalBytes = estimateComplete && estimatedTotal > 0 ? estimatedTotal : null;
  Duration? timeLeft;
  if (estimatedTotalBytes != null && speed > 0) {
    final remainingBytes = (estimatedTotalBytes - downloadedBytes).clamp(0, estimatedTotalBytes);
    timeLeft = Duration(milliseconds: (remainingBytes / speed * 1000).round());
  }

  return DownloadQueueSummary(
    total: total,
    completed: completed,
    failed: failed,
    downloadedBytes: downloadedBytes,
    estimatedTotalBytes: estimatedTotalBytes,
    speed: speed,
    timeLeft: timeLeft,
    currentTitle: currentTitle,
    currentProgress: currentProgress,
  );
}
