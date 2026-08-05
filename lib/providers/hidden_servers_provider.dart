import 'package:flutter/foundation.dart';
import '../mixins/disposable_change_notifier_mixin.dart';
import '../services/storage_service.dart';
import 'multi_server_provider.dart';

/// Provider for managing hidden media-server state across the app.
///
/// A hidden server stays connected — downloads and direct navigation still
/// resolve through it — but contributes nothing to browse surfaces (home hubs,
/// Continue Watching, the library list, search). Keeping the state here means
/// hiding a server in settings updates every screen at once.
///
/// Scoped per profile, like [HiddenLibrariesProvider]: which servers you want
/// to see is a per-profile preference.
class HiddenServersProvider extends ChangeNotifier with DisposableChangeNotifierMixin {
  StorageService? _storageService;
  final String? profileId;

  /// App-scoped server provider the hidden set is pushed into. This provider is
  /// profile-scoped and shorter-lived, so it owns clearing the filter on
  /// dispose — otherwise one profile's hidden servers would linger into the
  /// next profile's session until that session's provider finished loading.
  final MultiServerProvider? _multiServer;

  Set<String> _hiddenServerIds = {};
  bool _isInitialized = false;
  Future<void>? _initFuture;

  HiddenServersProvider({this._storageService, this.profileId, this._multiServer}) {
    // Start initialization eagerly to reduce race conditions
    _initFuture = _initialize();
  }

  @override
  void dispose() {
    _multiServer?.setHiddenServerIds(const {});
    super.dispose();
  }

  void _publish() {
    _multiServer?.setHiddenServerIds(_hiddenServerIds);
    safeNotifyListeners();
  }

  /// Ensures the provider is initialized. Call this before accessing hidden
  /// servers in contexts where you need the actual persisted values.
  Future<void> ensureInitialized() => _initFuture ?? _initialize();

  /// Check if the provider has completed initialization
  bool get isInitialized => _isInitialized;

  /// Get an unmodifiable copy of hidden server ids
  Set<String> get hiddenServerIds => Set.unmodifiable(_hiddenServerIds);

  Future<void> _initialize() async {
    if (_isInitialized) return;
    await _loadFromStorage();
    _isInitialized = true;
    _publish();
  }

  Future<void> _loadFromStorage() async {
    final storage = _storageService ??= await StorageService.getInstance();
    final scopedProfileId = profileId;
    _hiddenServerIds = scopedProfileId == null
        ? storage.getHiddenServers()
        : storage.getHiddenServersForProfile(scopedProfileId);
  }

  Future<void> _saveToStorage() async {
    final storage = _storageService ??= await StorageService.getInstance();
    final scopedProfileId = profileId;
    if (scopedProfileId == null) {
      await storage.saveHiddenServers(_hiddenServerIds);
    } else {
      await storage.saveHiddenServersForProfile(scopedProfileId, _hiddenServerIds);
    }
  }

  /// Hide a server by its id, in memory and in storage.
  Future<void> hideServer(String serverId) async {
    if (!_isInitialized) await _initialize();
    if (_hiddenServerIds.contains(serverId)) return;
    _hiddenServerIds = Set.from(_hiddenServerIds)..add(serverId);
    await _saveToStorage();
    _publish();
  }

  /// Unhide a server by its id, in memory and in storage.
  Future<void> unhideServer(String serverId) async {
    if (!_isInitialized) await _initialize();
    if (!_hiddenServerIds.contains(serverId)) return;
    _hiddenServerIds = Set.from(_hiddenServerIds)..remove(serverId);
    await _saveToStorage();
    _publish();
  }

  Future<void> setServerHidden(String serverId, {required bool hidden}) =>
      hidden ? hideServer(serverId) : unhideServer(serverId);

  /// Check if a specific server is hidden
  bool isServerHidden(String serverId) => _hiddenServerIds.contains(serverId);

  /// Re-read from storage. Used after a profile switch or a settings import,
  /// where storage changed outside this provider.
  Future<void> refresh() async {
    await _loadFromStorage();
    _isInitialized = true;
    _publish();
  }
}
