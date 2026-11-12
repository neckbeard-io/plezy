import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/download_queue_summary.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/models/download_models.dart';

import '../test_helpers/media_items.dart';

DownloadQueueEntry _entry(
  String key,
  DownloadStatus status, {
  int progress = 0,
  int downloadedBytes = 0,
  int totalBytes = 0,
  int? durationMs,
  String? title,
}) => (
  progress: DownloadProgress(
    globalKey: key,
    status: status,
    progress: progress,
    downloadedBytes: downloadedBytes,
    totalBytes: totalBytes,
  ),
  durationMs: durationMs,
  title: title,
);

void main() {
  group('summarizeDownloadQueue', () {
    test('counts the run and estimates queued items from its bitrate', () {
      // 2 GB per hour of runtime: the finished episode sets the rate the
      // queued ones (no size yet) are estimated at.
      const hour = 3600000;
      final summary = summarizeDownloadQueue([
        _entry('a', DownloadStatus.completed, progress: 100, totalBytes: 2000, downloadedBytes: 2000, durationMs: hour),
        _entry(
          'b',
          DownloadStatus.downloading,
          progress: 25,
          totalBytes: 1000,
          downloadedBytes: 250,
          durationMs: hour ~/ 2,
          title: 'Show · S1 E2 · Two',
        ),
        _entry('c', DownloadStatus.queued, durationMs: hour),
        _entry('d', DownloadStatus.queued, durationMs: hour ~/ 2),
      ], speed: 10);

      expect(summary.total, 4);
      expect(summary.completed, 1);
      expect(summary.remaining, 3);
      expect(summary.currentTitle, 'Show · S1 E2 · Two');
      expect(summary.currentProgress, 0.25);
      // 2000 + 1000 + 2000 + 1000 estimated, 2250 of it on disk.
      expect(summary.estimatedTotalBytes, 6000);
      expect(summary.downloadedBytes, 2250);
      expect(summary.fraction, closeTo(2250 / 6000, 1e-9));
      // 3750 bytes left at 10 B/s.
      expect(summary.timeLeft, const Duration(milliseconds: 375000));
    });

    test('leaves the size and time unknown until some item reports a size', () {
      final summary = summarizeDownloadQueue([
        _entry('a', DownloadStatus.downloading, durationMs: 1000, title: 'Movie'),
        _entry('b', DownloadStatus.queued, durationMs: 1000),
      ], speed: 100);

      expect(summary.estimatedTotalBytes, isNull);
      expect(summary.timeLeft, isNull);
      expect(summary.fraction, 0);
    });

    test('falls back to the average size for items without a runtime', () {
      final summary = summarizeDownloadQueue([
        _entry('a', DownloadStatus.downloading, totalBytes: 400, downloadedBytes: 100),
        _entry('b', DownloadStatus.queued),
      ], speed: 0);

      expect(summary.estimatedTotalBytes, 800);
      expect(summary.timeLeft, isNull, reason: 'no speed yet');
    });

    test('counts failed items as finished without bytes and skips cancelled ones', () {
      final summary = summarizeDownloadQueue([
        _entry('a', DownloadStatus.failed, totalBytes: 999),
        _entry('b', DownloadStatus.cancelled, totalBytes: 999),
        _entry('c', DownloadStatus.downloading, totalBytes: 100, downloadedBytes: 50),
      ], speed: 50);

      expect(summary.total, 2);
      expect(summary.failed, 1);
      expect(summary.remaining, 1);
      expect(summary.estimatedTotalBytes, 100);
      expect(summary.timeLeft, const Duration(seconds: 1));
    });
  });

  group('downloadQueueLabel', () {
    test('names an episode by show, season and episode, and title', () {
      final episode = testMediaItem(
        kind: MediaKind.episode,
        title: 'Hello Goodbye',
        grandparentTitle: 'Slow Horses',
        parentIndex: 4,
        index: 3,
      );
      expect(downloadQueueLabel(episode), 'Slow Horses · S4 E3 · Hello Goodbye');
    });

    test('names a movie by its title', () {
      expect(downloadQueueLabel(testMediaItem(title: 'Heat')), 'Heat');
    });
  });
}
