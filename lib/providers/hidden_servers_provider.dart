import 'package:flutter/foundation.dart';
import '../mixins/disposable_change_notifier_mixin.dart';
import '../services/storage_service.dart';

/// Provider for managing hidden server state across the app.
/// This ensures that when a server is hidden/unhidden in one screen,
/// all other screens are automatically updated.
class HiddenServersProvider extends ChangeNotifier with DisposableChangeNotifierMixin {
  late StorageService _storageService;
  Set<String> _hiddenServerIds = {};
  bool _isInitialized = false;
  Future<void>? _initFuture;

  HiddenServersProvider() {
    // Start initialization eagerly to reduce race conditions
    _initFuture = _initialize();
  }

  /// Ensures the provider is initialized. Call this before accessing hidden
  /// servers in contexts where you need the actual persisted values.
  Future<void> ensureInitialized() => _initFuture ?? _initialize();

  /// Check if the provider has completed initialization
  bool get isInitialized => _isInitialized;

  /// Get an unmodifiable copy of hidden server IDs
  Set<String> get hiddenServerIds => Set.unmodifiable(_hiddenServerIds);

  /// Initialize the provider by loading hidden servers from storage
  Future<void> _initialize() async {
    if (_isInitialized) return;
    _storageService = await StorageService.getInstance();
    _hiddenServerIds = _storageService.getHiddenServers();
    _isInitialized = true;
    safeNotifyListeners();
  }

  /// Hide a server by its ID
  /// Updates both in-memory state and persistent storage
  Future<void> hideServer(String serverId) async {
    if (!_isInitialized) await _initialize();
    if (!_hiddenServerIds.contains(serverId)) {
      _hiddenServerIds = Set.from(_hiddenServerIds)..add(serverId);
      await _storageService.saveHiddenServers(_hiddenServerIds);
      safeNotifyListeners();
    }
  }

  /// Unhide a server by its ID
  /// Updates both in-memory state and persistent storage
  Future<void> unhideServer(String serverId) async {
    if (!_isInitialized) await _initialize();
    if (_hiddenServerIds.contains(serverId)) {
      _hiddenServerIds = Set.from(_hiddenServerIds)..remove(serverId);
      await _storageService.saveHiddenServers(_hiddenServerIds);
      safeNotifyListeners();
    }
  }

  /// Check if a specific server is hidden
  bool isServerHidden(String serverId) => _hiddenServerIds.contains(serverId);

  /// Refresh hidden servers from storage
  /// Useful if storage was modified outside the provider
  Future<void> refresh() async {
    _hiddenServerIds = _storageService.getHiddenServers();
    safeNotifyListeners();
  }
}
