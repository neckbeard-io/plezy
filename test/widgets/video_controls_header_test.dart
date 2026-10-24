import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/media/ids.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/mpv/player/player.dart';
import 'package:plezy/mpv/player/player_stream_controllers.dart';
import 'package:plezy/mpv/player/player_streams.dart';
import 'package:plezy/services/jellyfin_mappers.dart';
import 'package:plezy/utils/formatters.dart';
import 'package:plezy/watch_together/providers/watch_together_provider.dart';
import 'package:plezy/widgets/video_controls/widgets/video_controls_header.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    await initializeDateFormatting('en');
  });

  testWidgets('title-less mapped movie builds with localized fallback in both layouts', (tester) async {
    final item = _mappedItem({'Id': 'movie-without-name', 'Type': 'Movie'});

    for (final style in VideoHeaderStyle.values) {
      await _pumpHeader(tester, metadata: item, style: style);

      expect(find.text(t.common.unknown), findsOneWidget, reason: style.name);
      expect(tester.takeException(), isNull, reason: style.name);
    }
  });

  testWidgets('title-less mapped episode keeps series identity and uses fallback in both layouts', (tester) async {
    final item = _mappedItem({
      'Id': 'episode-without-name',
      'Type': 'Episode',
      'SeriesName': 'Mapped Series',
      'ParentIndexNumber': 2,
      'IndexNumber': 3,
    });

    for (final style in VideoHeaderStyle.values) {
      await _pumpHeader(tester, metadata: item, style: style);

      final expectedEpisodeLine = switch (style) {
        VideoHeaderStyle.singleLine => 'Mapped Series · S2E3 · ${t.common.unknown}',
        VideoHeaderStyle.multiLine => 'S2 · E3 · ${t.common.unknown}',
      };
      expect(find.text(expectedEpisodeLine), findsOneWidget, reason: style.name);
      expect(tester.takeException(), isNull, reason: style.name);
    }
  });

  testWidgets('ordinary mapped episode wording remains unchanged in both layouts', (tester) async {
    final item = _mappedItem({
      'Id': 'titled-episode',
      'Type': 'Episode',
      'Name': 'The Arrival',
      'SeriesName': 'Mapped Series',
      'ParentIndexNumber': 1,
      'IndexNumber': 4,
    });

    for (final style in VideoHeaderStyle.values) {
      await _pumpHeader(tester, metadata: item, style: style);

      final expectedEpisodeLine = switch (style) {
        VideoHeaderStyle.singleLine => 'Mapped Series · S1E4 · The Arrival',
        VideoHeaderStyle.multiLine => 'S1 · E4 · The Arrival',
      };
      expect(find.text(expectedEpisodeLine), findsOneWidget, reason: style.name);
      expect(find.text(t.common.unknown), findsNothing, reason: style.name);
    }
  });

  testWidgets('episode shows its air date just left of the runtime', (tester) async {
    final item = _mappedItem({
      'Id': 'dated-episode',
      'Type': 'Episode',
      'Name': 'The Arrival',
      'SeriesName': 'Mapped Series',
      'ParentIndexNumber': 1,
      'IndexNumber': 4,
      'PremiereDate': '2024-03-05T00:00:00.0000000Z',
      'RunTimeTicks': 27000000000,
    });
    final runtime = formatDurationTextual(item.durationMs!);

    for (final style in VideoHeaderStyle.values) {
      await _pumpHeader(tester, metadata: item, style: style);

      final expectedEpisodeLine = switch (style) {
        VideoHeaderStyle.singleLine => 'Mapped Series · S1E4 · The Arrival · Mar 5, 2024',
        VideoHeaderStyle.multiLine => 'S1 · E4 · The Arrival · Mar 5, 2024 · $runtime',
      };
      expect(find.text(expectedEpisodeLine), findsOneWidget, reason: style.name);
    }
  });

  testWidgets('movie shows its release year just left of the runtime', (tester) async {
    final item = _mappedItem({
      'Id': 'dated-movie',
      'Type': 'Movie',
      'Name': 'Mapped Movie',
      'ProductionYear': 2019,
      'RunTimeTicks': 78000000000,
    });
    final runtime = formatDurationTextual(item.durationMs!);

    for (final style in VideoHeaderStyle.values) {
      await _pumpHeader(tester, metadata: item, style: style);

      final expectedLine = switch (style) {
        VideoHeaderStyle.singleLine => 'Mapped Movie · 2019',
        VideoHeaderStyle.multiLine => '2019 · $runtime',
      };
      expect(find.text(expectedLine), findsOneWidget, reason: style.name);
    }
  });

  testWidgets('names the active player below the date line', (tester) async {
    final item = _mappedItem({
      'Id': 'played-episode',
      'Type': 'Episode',
      'Name': 'The Arrival',
      'SeriesName': 'Mapped Series',
      'ParentIndexNumber': 1,
      'IndexNumber': 4,
    });

    await _pumpHeader(tester, metadata: item, style: VideoHeaderStyle.multiLine, player: _FakePlayer('exoplayer'));
    expect(find.text('ExoPlayer'), findsOneWidget);
    expect(find.text('S1 · E4 · The Arrival'), findsOneWidget, reason: 'the player gets its own line');

    await _pumpHeader(tester, metadata: item, style: VideoHeaderStyle.singleLine, player: _FakePlayer('mpv'));
    expect(find.text('Mapped Series · S1E4 · The Arrival · MPV'), findsOneWidget);
  });

  testWidgets('shows no player line without a player', (tester) async {
    final item = _mappedItem({'Id': 'movie', 'Type': 'Movie', 'Name': 'Mapped Movie'});

    await _pumpHeader(tester, metadata: item, style: VideoHeaderStyle.multiLine);
    expect(find.text('MPV'), findsNothing);
    expect(find.text('ExoPlayer'), findsNothing);
  });
}

MediaItem _mappedItem(Map<String, dynamic> json) {
  return JellyfinMappers.mediaItem(
    json,
    serverId: ServerId('header-test-server'),
    serverName: 'Test Server',
    absolutizer: null,
  )!;
}

class _FakePlayer with PlayerStreamControllersMixin implements Player {
  _FakePlayer(this.playerType);

  @override
  final String playerType;

  @override
  late final PlayerStreams streams = createStreams();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpHeader(
  WidgetTester tester, {
  required MediaItem metadata,
  required VideoHeaderStyle style,
  Player? player,
}) async {
  final watchTogether = WatchTogetherProvider();
  addTearDown(watchTogether.dispose);

  await tester.pumpWidget(
    TranslationProvider(
      child: ChangeNotifierProvider<WatchTogetherProvider>.value(
        value: watchTogether,
        child: MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SizedBox(
              width: 900,
              child: VideoControlsHeader(metadata: metadata, style: style, player: player, onBack: () {}),
            ),
          ),
        ),
      ),
    ),
  );
}
