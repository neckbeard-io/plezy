import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/models/download_models.dart';
import 'package:plezy/providers/download_queue_tracker.dart';

import '../test_helpers/media_items.dart';

class _FakeSource extends ChangeNotifier {
  final downloads = <String, DownloadProgress>{};
  final metadata = <String, MediaItem>{};

  void set(String key, DownloadStatus status, {int progress = 0, double speed = 0, int totalBytes = 0}) {
    downloads[key] = DownloadProgress(
      globalKey: key,
      status: status,
      progress: progress,
      speed: speed,
      totalBytes: totalBytes,
      downloadedBytes: totalBytes * progress ~/ 100,
    );
    notifyListeners();
  }
}

void main() {
  late _FakeSource source;
  late DownloadQueueTracker tracker;

  setUp(() {
    source = _FakeSource();
    tracker = DownloadQueueTracker.forSource(
      source: source,
      downloads: () => source.downloads,
      metadataFor: (key) => source.metadata[key],
    );
  });

  tearDown(() => tracker.dispose());

  test('keeps finished items in the run until the queue drains', () {
    source.set('old', DownloadStatus.completed, progress: 100);
    expect(tracker.summary, isNull, reason: 'a finished download before the run is not part of it');

    source.metadata['a'] = testMediaItem(
      id: 'a',
      kind: MediaKind.episode,
      title: 'Pilot',
      grandparentTitle: 'Show',
      parentIndex: 1,
      index: 1,
    );
    source.set('a', DownloadStatus.downloading, progress: 50, speed: 100, totalBytes: 1000);
    source.set('b', DownloadStatus.queued);
    expect(tracker.summary!.total, 2);
    expect(tracker.summary!.currentTitle, 'Show · S1 E1 · Pilot');

    source.set('a', DownloadStatus.completed, progress: 100, totalBytes: 1000);
    source.set('b', DownloadStatus.downloading, progress: 10, speed: 100, totalBytes: 1000);
    expect(tracker.summary!.total, 2);
    expect(tracker.summary!.completed, 1);
    expect(tracker.debugRunKeys, {'a', 'b'});

    source.set('b', DownloadStatus.completed, progress: 100, totalBytes: 1000);
    expect(tracker.summary, isNull);
    expect(tracker.debugRunKeys, isEmpty);

    // The next queued item starts a new run.
    source.set('c', DownloadStatus.queued);
    expect(tracker.summary!.total, 1);
  });

  test('drops a removed item from the run and smooths the speed', () {
    source.set('a', DownloadStatus.downloading, progress: 10, speed: 100, totalBytes: 1000);
    source.set('b', DownloadStatus.queued);
    expect(tracker.summary!.speed, 100);

    source.set('a', DownloadStatus.downloading, progress: 20, speed: 200, totalBytes: 1000);
    expect(tracker.summary!.speed, closeTo(130, 1e-9));

    source.downloads.remove('b');
    source.notifyListeners();
    expect(tracker.summary!.total, 1);
  });
}
