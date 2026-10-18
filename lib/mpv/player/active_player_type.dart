import 'platform/player_android.dart';
import 'player.dart';

extension ActivePlayerType on Player {
  /// The engine playing right now. Differs from [Player.playerType] only on
  /// Android, where ExoPlayer hands a file it can't play to mpv.
  String get activePlayerType {
    final self = this;
    return self is PlayerAndroid && self.usingMpvFallback ? 'mpv' : playerType;
  }

  /// [activePlayerType] as shown to the viewer.
  String get activePlayerLabel => switch (activePlayerType) {
    'mpv' => 'MPV',
    'exoplayer' => 'ExoPlayer',
    final other => other,
  };
}
