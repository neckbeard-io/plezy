import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/ids.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/providers/show_watch_counts_provider.dart';
import 'package:plezy/utils/watch_state_notifier.dart';

import '../test_helpers/media_items.dart';

void main() {
  late Map<String, MediaItem> shows;
  late List<String> fetches;
  late ShowWatchCountsProvider provider;
  Object? fetchError;

  final episode = testMediaItem(
    id: 'ep-1',
    kind: MediaKind.episode,
    serverId: 'srv',
    parentId: 'season-1',
    grandparentId: 'show-1',
  );

  MediaItem show(int viewed, int total) =>
      testMediaItem(id: 'show-1', kind: MediaKind.show, serverId: 'srv', leafCount: total, viewedLeafCount: viewed);

  setUp(() {
    shows = {'show-1': show(3, 10)};
    fetches = [];
    fetchError = null;
    provider = ShowWatchCountsProvider(
      fetchShow: (serverId, showId) async {
        fetches.add('${serverId.value}:$showId');
        if (fetchError != null) throw fetchError!;
        return shows[showId];
      },
    );
  });

  tearDown(() => provider.dispose());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  void emit(WatchStateChangeType type) => WatchStateNotifier().notify(
    WatchStateEvent(
      itemId: 'ep-2',
      serverId: ServerId('srv'),
      changeType: type,
      parentChain: const ['season-1', 'show-1'],
    ),
  );

  test('fetches the show once and notifies with its watched/total count', () async {
    var notified = 0;
    provider.addListener(() => notified++);

    expect(provider.countFor(episode), isNull);
    expect(provider.countFor(episode), isNull, reason: 'a second read while loading must not refetch');
    await settle();

    expect(provider.countFor(episode), (viewed: 3, total: 10));
    expect(fetches, ['srv:show-1']);
    expect(notified, 1);
  });

  test('a watch event under a cached show refetches it', () async {
    provider.countFor(episode);
    await settle();

    shows['show-1'] = show(4, 10);
    emit(WatchStateChangeType.watched);
    await settle();
    await settle();

    expect(provider.countFor(episode), (viewed: 4, total: 10));
    expect(fetches, hasLength(2));
  });

  test('progress updates do not refetch', () async {
    provider.countFor(episode);
    await settle();

    emit(WatchStateChangeType.progressUpdate);
    await settle();
    await settle();

    expect(fetches, hasLength(1));
  });

  test('a failed refresh keeps the last good count', () async {
    provider.countFor(episode);
    await settle();

    fetchError = Exception('offline');
    emit(WatchStateChangeType.watched);
    await settle();
    await settle();

    expect(provider.countFor(episode), (viewed: 3, total: 10));
    expect(fetches, hasLength(2));
  });

  test('episodes without a show id or server have no count', () {
    expect(provider.countFor(testMediaItem(id: 'ep-x', kind: MediaKind.episode, serverId: 'srv')), isNull);
    expect(provider.countFor(testMediaItem(id: 'ep-y', kind: MediaKind.episode, grandparentId: 'show-1')), isNull);
    expect(fetches, isEmpty);
  });
}
