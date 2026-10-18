import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/providers/show_watch_counts_provider.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/theme/mono_theme.dart';
import 'package:plezy/widgets/media_progress_bar.dart';
import 'package:plezy/widgets/unwatched_count_badge.dart';
import 'package:plezy/widgets/watched_indicator.dart';
import 'package:provider/provider.dart';

import '../test_helpers/media_items.dart';
import '../test_helpers/prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();
  });

  Future<void> pump(WidgetTester tester, WatchedIndicator indicator) => tester.pumpWidget(
    MaterialApp(
      theme: monoTheme(dark: true),
      home: SizedBox(width: 200, height: 300, child: indicator),
    ),
  );

  final watchedMovie = testMediaItem(id: 'movie', kind: MediaKind.movie, viewCount: 1);

  testWidgets('shows the watched checkmark by default', (tester) async {
    await pump(tester, WatchedIndicator(item: watchedMovie));

    expect(find.byIcon(Symbols.check_rounded), findsOneWidget);
  });

  testWidgets('hides only the checkmark when watched indicators are off (#1998)', (tester) async {
    await SettingsService.instance.write(SettingsService.showWatchedIndicators, false);
    final partiallyWatchedShow = testMediaItem(id: 'show', kind: MediaKind.show, leafCount: 10, viewedLeafCount: 4);
    final inProgressMovie = testMediaItem(
      id: 'movie-2',
      kind: MediaKind.movie,
      durationMs: 100000,
      viewOffsetMs: 50000,
    );

    await pump(tester, WatchedIndicator(item: watchedMovie));
    expect(find.byIcon(Symbols.check_rounded), findsNothing);

    await pump(tester, WatchedIndicator(item: partiallyWatchedShow));
    expect(find.byType(UnwatchedCountBadge), findsOneWidget, reason: 'unwatched counts are a separate pref');

    await pump(tester, WatchedIndicator(item: inProgressMovie));
    expect(find.byType(MediaProgressBar), findsOneWidget, reason: 'progress bars are not indicators');
  });

  group('watched/total count', () {
    final partiallyWatchedShow = testMediaItem(id: 'show', kind: MediaKind.show, leafCount: 10, viewedLeafCount: 4);
    final episode = testMediaItem(id: 'ep', kind: MediaKind.episode, serverId: 'srv', grandparentId: 'show-1');

    Future<void> pumpWithCounts(WidgetTester tester, WatchedIndicator indicator) async {
      final counts = ShowWatchCountsProvider(
        fetchShow: (_, _) async =>
            testMediaItem(id: 'show-1', kind: MediaKind.show, serverId: 'srv', leafCount: 10, viewedLeafCount: 3),
      );
      addTearDown(counts.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<ShowWatchCountsProvider>.value(
          value: counts,
          child: MaterialApp(
            theme: monoTheme(dark: true),
            home: SizedBox(width: 200, height: 300, child: indicator),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('replaces the unwatched count on shows by default', (tester) async {
      await pump(tester, WatchedIndicator(item: partiallyWatchedShow));

      expect(find.text('4/10'), findsOneWidget);
      expect(find.text('6'), findsNothing);
    });

    testWidgets('falls back to the unwatched count when turned off', (tester) async {
      await SettingsService.instance.write(SettingsService.showWatchedTotalCount, false);
      await pump(tester, WatchedIndicator(item: partiallyWatchedShow));

      expect(find.text('6'), findsOneWidget);
      expect(find.text('4/10'), findsNothing);
    });

    testWidgets('hides with the unwatched count setting', (tester) async {
      await SettingsService.instance.write(SettingsService.showUnwatchedCount, false);
      await pump(tester, WatchedIndicator(item: partiallyWatchedShow));

      expect(find.byType(UnwatchedCountBadge), findsNothing);
    });

    testWidgets('a finished show keeps its checkmark', (tester) async {
      final finishedShow = testMediaItem(id: 'show', kind: MediaKind.show, leafCount: 10, viewedLeafCount: 10);
      await pump(tester, WatchedIndicator(item: finishedShow));

      expect(find.byIcon(Symbols.check_rounded), findsOneWidget);
      expect(find.byType(UnwatchedCountBadge), findsNothing);
    });

    testWidgets('episode cards show their series count when asked', (tester) async {
      await pumpWithCounts(tester, WatchedIndicator(item: episode, showSeriesCount: true));

      expect(find.text('3/10'), findsOneWidget);
    });

    testWidgets('episode lists without showSeriesCount stay bare', (tester) async {
      await pumpWithCounts(tester, WatchedIndicator(item: episode));

      expect(find.byType(UnwatchedCountBadge), findsNothing);
    });
  });
}
