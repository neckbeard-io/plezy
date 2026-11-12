import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.g.dart';
import '../media/download_queue_summary.dart';
import '../providers/download_provider.dart';
import '../providers/download_queue_tracker.dart';
import '../utils/formatters.dart';
import 'app_icon.dart';

/// Overall progress of the current download run at the top of the Downloads
/// screen: items done of the run, what is downloading now, bytes, speed and
/// time left. Collapses to nothing while nothing is queued.
class DownloadQueueSummaryCard extends StatelessWidget {
  const DownloadQueueSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final tracker = DownloadQueueTracker.of(context.read<DownloadProvider>());
    return ListenableBuilder(
      listenable: tracker,
      builder: (context, _) {
        final summary = tracker.summary;
        if (summary == null) return const SizedBox.shrink();
        return DownloadQueueSummaryView(summary: summary);
      },
    );
  }
}

@visibleForTesting
class DownloadQueueSummaryView extends StatelessWidget {
  const DownloadQueueSummaryView({super.key, required this.summary});

  final DownloadQueueSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final current = summary.currentTitle;
    final currentProgress = summary.currentProgress;
    final totalBytes = summary.estimatedTotalBytes;
    final timeLeft = summary.timeLeft;

    final String status;
    if (current == null) {
      status = t.downloads.queueSummaryWaiting;
    } else if (timeLeft != null) {
      status = t.downloads.queueSummaryTimeLeft(time: formatDurationTextual(timeLeft.inMilliseconds));
    } else {
      status = t.downloads.queueSummaryEstimating;
    }

    return Material(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: .stretch,
          mainAxisSize: .min,
          children: [
            Row(
              children: [
                AppIcon(Symbols.download_rounded, fill: 1, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.downloads.queueSummaryCount(done: summary.completed, total: summary.total),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (summary.speed > 0)
                  Text(ByteFormatter.formatSpeed(summary.speed), style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: summary.fraction, minHeight: 6),
            ),
            const SizedBox(height: 8),
            if (current != null)
              Text(
                currentProgress == null ? current : '$current · ${(currentProgress * 100).round()}%',
                maxLines: 1,
                overflow: .ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            Text(
              toBulletedString([
                if (totalBytes != null)
                  t.downloads.queueSummaryBytes(
                    downloaded: ByteFormatter.formatBytes(summary.downloadedBytes),
                    total: ByteFormatter.formatBytes(totalBytes),
                  ),
                status,
              ]),
              style: muted,
            ),
          ],
        ),
      ),
    );
  }
}
