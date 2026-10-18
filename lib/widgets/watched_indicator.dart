import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../media/leaf_watch_count.dart';
import '../media/media_item.dart';
import '../media/media_item_types.dart';
import '../media/media_kind.dart';
import '../providers/show_watch_counts_provider.dart';
import '../services/settings_service.dart';
import '../theme/mono_tokens.dart';
import 'app_icon.dart';
import 'media_progress_bar.dart';
import 'unwatched_count_badge.dart';

/// Size preset for [WatchedIndicator]: [standard] for grid/poster cards,
/// [compact] for dense surfaces (folder tree rows, episode thumbnails).
/// Add a preset here instead of hand-rolling a new overlay variant.
enum WatchedIndicatorSize {
  standard(
    checkInset: 4,
    checkPadding: 4,
    checkIconSize: 16,
    badgeSize: 24,
    badgeFontSize: 12,
    barRadius: 8,
    barMinHeight: 4,
  ),
  compact(
    checkInset: 3,
    checkPadding: 2,
    checkIconSize: 12,
    badgeSize: 20,
    badgeFontSize: 10,
    barRadius: 6,
    barMinHeight: 3,
  );

  const WatchedIndicatorSize({
    required this.checkInset,
    required this.checkPadding,
    required this.checkIconSize,
    required this.badgeSize,
    required this.badgeFontSize,
    required this.barRadius,
    required this.barMinHeight,
  });

  final double checkInset;
  final double checkPadding;
  final double checkIconSize;
  final double badgeSize;
  final double badgeFontSize;
  final double barRadius;
  final double barMinHeight;
}

/// Watched/progress overlay for media artwork: watched checkmark,
/// unwatched-count pill (shows/seasons), active-progress bar, and season
/// completion bar. The single implementation behind every surface that
/// stamps watch state onto a poster/thumbnail. Callers that must react to
/// [SettingsService.showWatchedIndicators], [SettingsService.showUnwatchedCount]
/// or [SettingsService.showWatchedTotalCount] flipping wrap themselves in a
/// [SettingsBuilder] on those prefs.
class WatchedIndicator extends StatelessWidget {
  final MediaItem item;
  final WatchedIndicatorSize size;

  /// Overrides the settings read for the unwatched-count pill — pass it when
  /// the caller already watches [SettingsService.showUnwatchedCount] so pill
  /// visibility updates reactively with the caller's rebuilds.
  final bool? showUnwatchedCount;

  /// Lets an episode card show its series' watched/total count (Continue
  /// Watching and other hub cards). Season episode lists leave it off.
  final bool showSeriesCount;

  const WatchedIndicator({
    super.key,
    required this.item,
    this.size = WatchedIndicatorSize.standard,
    this.showUnwatchedCount,
    this.showSeriesCount = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool showCount = showUnwatchedCount ?? SettingsService.instance.read(SettingsService.showUnwatchedCount);
    final bool showWatched = SettingsService.instance.read(SettingsService.showWatchedIndicators);
    final hasActiveProgress = item.hasActiveProgress;
    final unwatched = item.unwatchedCount;
    final showsCheckmark = showWatched && item.isWatched && !hasActiveProgress;
    final watchedTotal = showCount && !showsCheckmark ? _watchedTotalCount(context) : null;
    final barRadius = BorderRadius.only(
      bottomLeft: Radius.circular(size.barRadius),
      bottomRight: Radius.circular(size.barRadius),
    );

    return Stack(
      children: [
        // Watched checkmark
        if (showsCheckmark)
          Positioned(
            top: size.checkInset,
            right: size.checkInset,
            child: Container(
              padding: EdgeInsets.all(size.checkPadding),
              decoration: BoxDecoration(
                color: tokens(context).text,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
              ),
              child: AppIcon(Symbols.check_rounded, fill: 1, color: tokens(context).bg, size: size.checkIconSize),
            ),
          ),
        // Watched/total for shows/seasons and series counts on episode cards
        if (watchedTotal != null)
          Positioned(
            top: size.checkInset,
            right: size.checkInset,
            child: UnwatchedCountBadge(
              count: watchedTotal.total - watchedTotal.viewed,
              label: '${watchedTotal.viewed}/${watchedTotal.total}',
              size: size.badgeSize,
              fontSize: size.badgeFontSize,
            ),
          )
        // Unwatched count for shows/seasons
        else if (showCount &&
            !item.isWatched &&
            (item.kind == MediaKind.show || item.kind == MediaKind.season) &&
            unwatched != null &&
            unwatched > 0)
          Positioned(
            top: size.checkInset,
            right: size.checkInset,
            child: UnwatchedCountBadge(count: unwatched, size: size.badgeSize, fontSize: size.badgeFontSize),
          ),
        // Progress bar for partially watched content (episodes/movies)
        if (hasActiveProgress)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: barRadius,
              child: MediaProgressBar(
                viewOffset: item.viewOffsetMs!,
                duration: item.durationMs!,
                minHeight: size.barMinHeight,
              ),
            ),
          ),
        // Progress bar for seasons (viewed leaves / total leaves).
        if (item.isSeason && item.isPartiallyWatched)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: barRadius,
              child: LinearProgressIndicator(
                value: item.leafWatchFraction,
                backgroundColor: tokens(context).outline,
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                minHeight: size.barMinHeight,
              ),
            ),
          ),
      ],
    );
  }

  /// Counts for the watched/total pill, or null to fall back to the plain
  /// unwatched count. A finished show keeps its checkmark instead.
  LeafWatchCount? _watchedTotalCount(BuildContext context) {
    if (!SettingsService.instance.read(SettingsService.showWatchedTotalCount)) return null;
    final LeafWatchCount? count;
    if (item.kind == MediaKind.show || item.kind == MediaKind.season) {
      count = item.leafWatchCount;
    } else if (showSeriesCount && item.kind == MediaKind.episode) {
      count = context.select<ShowWatchCountsProvider?, LeafWatchCount?>((p) => p?.countFor(item));
    } else {
      return null;
    }
    return count != null && count.viewed < count.total ? count : null;
  }
}
