import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/providers/hidden_servers_provider.dart';
import 'package:plezy/providers/multi_server_provider.dart';
import 'package:plezy/services/base_shared_preferences_service.dart';
import 'package:plezy/services/data_aggregation_service.dart';
import 'package:plezy/services/multi_server_manager.dart';
import 'package:plezy/services/storage_service.dart';

import '../test_helpers/prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetSharedPreferencesForTest);

  group('HiddenServersProvider', () {
    test('starts uninitialized and exposes an empty set', () async {
      final p = HiddenServersProvider();
      expect(p.isInitialized, isFalse);
      expect(p.hiddenServerIds, isEmpty);

      await p.ensureInitialized();

      expect(p.isInitialized, isTrue);
      expect(p.hiddenServerIds, isEmpty);
      p.dispose();
    });

    test('hideServer persists the id and notifies once per real change', () async {
      final p = HiddenServersProvider();
      await p.ensureInitialized();

      var notified = 0;
      p.addListener(() => notified++);

      await p.hideServer('srv-1');
      expect(p.isServerHidden('srv-1'), isTrue);
      expect(notified, 1);

      await p.hideServer('srv-1');
      expect(notified, 1, reason: 'hiding an already-hidden server is a no-op');

      await p.unhideServer('srv-1');
      expect(p.isServerHidden('srv-1'), isFalse);
      expect(notified, 2);

      p.dispose();
    });

    test('persists across provider instances', () async {
      final first = HiddenServersProvider();
      await first.ensureInitialized();
      await first.hideServer('srv-A');
      first.dispose();

      // Reset only the cached singleton, NOT SharedPreferences.
      BaseSharedPreferencesService.resetForTesting();

      final second = HiddenServersProvider();
      await second.ensureInitialized();
      expect(second.isServerHidden('srv-A'), isTrue);
      expect(second.isServerHidden('srv-B'), isFalse);
      second.dispose();
    });

    test('profile-scoped sets stay separate', () async {
      final storage = await StorageService.getInstance();

      final owner = HiddenServersProvider(storageService: storage, profileId: 'owner');
      await owner.ensureInitialized();
      await owner.hideServer('srv-adults');

      final kids = HiddenServersProvider(storageService: storage, profileId: 'kids');
      await kids.ensureInitialized();

      expect(kids.isServerHidden('srv-adults'), isFalse);
      expect(owner.isServerHidden('srv-adults'), isTrue);

      owner.dispose();
      kids.dispose();
    });

    test('hiddenServerIds returns an unmodifiable view', () async {
      final p = HiddenServersProvider();
      await p.ensureInitialized();
      expect(() => p.hiddenServerIds.add('mutated'), throwsUnsupportedError);
      p.dispose();
    });

    test('pushes the hidden set into MultiServerProvider, and clears it on dispose', () async {
      final manager = MultiServerManager();
      addTearDown(manager.dispose);
      final multiServer = MultiServerProvider(manager, DataAggregationService(manager));
      addTearDown(multiServer.dispose);

      final storage = await StorageService.getInstance();
      await storage.saveHiddenServersForProfile('owner', {'srv-1'});

      final p = HiddenServersProvider(storageService: storage, profileId: 'owner', multiServer: multiServer);
      await p.ensureInitialized();

      expect(multiServer.hiddenServerIds, {'srv-1'});

      await p.hideServer('srv-2');
      expect(multiServer.hiddenServerIds, {'srv-1', 'srv-2'});

      // A profile switch tears this provider down; the app-scoped server
      // provider must not keep filtering by the old profile's choices.
      p.dispose();
      expect(multiServer.hiddenServerIds, isEmpty);
    });

    test('safeNotifyListeners no-ops after dispose', () async {
      final p = HiddenServersProvider();
      await p.ensureInitialized();
      p.dispose();
      await p.refresh();
    });
  });
}
