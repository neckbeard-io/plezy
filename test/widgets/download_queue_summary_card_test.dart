import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/download_queue_summary.dart';
import 'package:plezy/widgets/download_queue_summary_card.dart';

Widget _wrap(DownloadQueueSummary summary) => MaterialApp(
  home: Scaffold(body: DownloadQueueSummaryView(summary: summary)),
);

void main() {
  testWidgets('shows the run count, current item, bytes, speed and time left', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const DownloadQueueSummary(
          total: 12,
          completed: 3,
          failed: 0,
          downloadedBytes: 4 * 1024 * 1024 * 1024,
          estimatedTotalBytes: 16 * 1024 * 1024 * 1024,
          speed: 20 * 1024 * 1024,
          timeLeft: Duration(minutes: 10),
          currentTitle: 'Slow Horses · S4 E3 · Hello Goodbye',
          currentProgress: 0.42,
        ),
      ),
    );

    expect(find.text('3 of 12 downloaded'), findsOneWidget);
    expect(find.text('Slow Horses · S4 E3 · Hello Goodbye · 42%'), findsOneWidget);
    expect(find.textContaining('20.0 MB/s'), findsOneWidget);
    expect(find.textContaining('4.00 GB of 16.00 GB'), findsOneWidget);
    expect(find.textContaining('left'), findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, closeTo(0.25, 1e-9));
  });

  testWidgets('says it is estimating until a size and speed are known', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const DownloadQueueSummary(
          total: 2,
          completed: 0,
          failed: 0,
          downloadedBytes: 0,
          estimatedTotalBytes: null,
          speed: 0,
          timeLeft: null,
          currentTitle: 'Heat',
          currentProgress: 0,
        ),
      ),
    );

    expect(find.text('Estimating time left…'), findsOneWidget);
  });
}
