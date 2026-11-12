import 'media_item.dart';

/// Watched and total episode counts for a show or season.
typedef LeafWatchCount = ({int viewed, int total});

extension LeafWatchCountX on MediaItem {
  /// Watched/total leaves for a container, or null when the server sent no
  /// total. Derived from [MediaItem.unwatchedCount] so Jellyfin's
  /// `UnplayedItemCount` fallback counts too.
  LeafWatchCount? get leafWatchCount {
    final total = leafWatchTotal;
    final unwatched = unwatchedCount;
    if (total == null || unwatched == null) return null;
    return (viewed: (total - unwatched).clamp(0, total), total: total);
  }
}
