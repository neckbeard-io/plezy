import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plezy/utils/formatters.dart';

import '../../../media/media_item.dart';
import '../../../media/media_item_types.dart';
import '../../../mpv/player/active_player_type.dart';
import '../../../mpv/player/player.dart';
import '../../../i18n/strings.g.dart';
import '../../../watch_together/widgets/watch_together_overlay.dart';
import '../../../watch_together/providers/watch_together_provider.dart';
import '../../app_bar_back_button.dart';
import '../../system_clock.dart';

/// Header layout style for video controls
enum VideoHeaderStyle {
  /// Multi-line: Series name on first line, episode info on second line
  multiLine,

  /// Single-line: All info combined with separators (for macOS)
  singleLine,
}

/// Shared header widget for video controls with back button and title.
///
/// Displays the video title with optional series/episode information.
/// Supports both single-line (macOS) and multi-line (other platforms) layouts.
class VideoControlsHeader extends StatelessWidget {
  final MediaItem metadata;
  final VideoHeaderStyle style;

  /// When set, the header names the engine playing (ExoPlayer or MPV) and
  /// updates when ExoPlayer falls back to mpv.
  final Player? player;

  /// Optional trailing widget (e.g., track/chapter controls)
  final Widget? trailing;

  /// Optional callback for back button. If null, defaults to Navigator.pop(true).
  final VoidCallback? onBack;
  final VoidCallback? onCancelAutoHide;
  final VoidCallback? onStartAutoHide;

  /// Whether to show the system clock. Off for a portrait phone, where the
  /// header is too narrow to fit the clock beside the title and trailing
  /// controls.
  final bool showClock;

  const VideoControlsHeader({
    super.key,
    required this.metadata,
    this.style = VideoHeaderStyle.multiLine,
    this.player,
    this.trailing,
    this.onBack,
    this.onCancelAutoHide,
    this.onStartAutoHide,
    this.showClock = true,
  });

  @override
  Widget build(BuildContext context) {
    final itemTitle = metadata.title ?? t.common.unknown;
    return Row(
      children: [
        AppBarBackButton(style: BackButtonStyle.video, onPressed: onBack ?? () => Navigator.of(context).pop(true)),
        const SizedBox(width: 16),
        Expanded(
          child: style == VideoHeaderStyle.singleLine
              ? _buildSingleLineTitle(itemTitle)
              : _buildMultiLineTitle(itemTitle),
        ),
        Selector<WatchTogetherProvider, bool>(
          selector: (_, p) => p.isInSession,
          builder: (context, inSession, child) {
            if (!inSession) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: WatchTogetherSessionIndicator(
                onCancelAutoHide: onCancelAutoHide,
                onStartAutoHide: onStartAutoHide,
              ),
            );
          },
        ),
        if (showClock)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SystemClock(
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: .w500),
            ),
          ),
        ?trailing,
      ],
    );
  }

  /// Air date for episodes, release year for movies.
  String? _releaseLabel() {
    if (metadata.isEpisode) {
      final airDate = metadata.originallyAvailableAt;
      return airDate != null && airDate.isNotEmpty ? formatAbbreviatedDate(airDate) : null;
    }
    if (metadata.isMovie && metadata.year != null) return '${metadata.year}';
    return null;
  }

  Widget _buildSingleLineTitle(String itemTitle) {
    final seriesName = metadata.grandparentTitle ?? itemTitle;
    final hasEpisodeInfo = metadata.parentIndex != null && metadata.index != null;

    final List<String> parts = [seriesName];

    if (hasEpisodeInfo) {
      parts.add('S${metadata.parentIndex}E${metadata.index}');
      parts.add(itemTitle);
    }

    final releaseLabel = _releaseLabel();
    if (releaseLabel != null) parts.add(releaseLabel);

    return _withPlayerLabel(
      (playerLabel) => Text(
        toBulletedString([...parts, ?playerLabel]),
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: .w500),
        maxLines: 1,
        overflow: .ellipsis,
      ),
    );
  }

  /// Rebuilds [builder] with the active player's label, or null without a
  /// [player]. ExoPlayer can hand a file to mpv mid-session, so it listens.
  Widget _withPlayerLabel(Widget Function(String? playerLabel) builder) {
    final player = this.player;
    if (player == null) return builder(null);
    return StreamBuilder<void>(
      stream: player.streams.backendSwitched,
      builder: (context, _) => builder(player.activePlayerLabel),
    );
  }

  Widget _buildMultiLineTitle(String itemTitle) {
    final List<String> secondLineParts = [];

    if (metadata.parentIndex != null && metadata.index != null) {
      secondLineParts.add('S${metadata.parentIndex}');
      secondLineParts.add('E${metadata.index}');
      secondLineParts.add(itemTitle);
    }

    // Just left of the runtime, which stays the rightmost value.
    final releaseLabel = _releaseLabel();
    if (releaseLabel != null) secondLineParts.add(releaseLabel);

    if (metadata.durationMs != null) {
      secondLineParts.add(formatDurationTextual(metadata.durationMs!));
    }

    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(
          metadata.grandparentTitle ?? itemTitle,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: .bold),
          maxLines: 1,
          overflow: .ellipsis,
        ),
        if (secondLineParts.isNotEmpty)
          Text(
            toBulletedString(secondLineParts),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            maxLines: 1,
            overflow: .ellipsis,
          ),
        _withPlayerLabel(
          (playerLabel) => playerLabel == null
              ? const SizedBox.shrink()
              : Text(
                  playerLabel,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  maxLines: 1,
                  overflow: .ellipsis,
                ),
        ),
      ],
    );
  }
}
