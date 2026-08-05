import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../i18n/strings.g.dart';
import '../../media/ids.dart';
import '../../providers/hidden_servers_provider.dart';
import '../../providers/multi_server_provider.dart';
import '../../widgets/focusable_list_tile.dart';
import '../../widgets/settings_page.dart';
import '../../widgets/settings_section.dart';

/// Per-server visibility. A hidden server stays connected — its downloads and
/// direct links keep working — but it stops contributing to home hubs,
/// Continue Watching, the library list and search.
///
/// Reads the *unfiltered* server list straight from [MultiServerManager], so a
/// hidden server can still be found here and switched back on.
class MediaServersScreen extends StatelessWidget {
  const MediaServersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: Text(t.settings.mediaServers),
      children: [
        Consumer2<MultiServerProvider, HiddenServersProvider>(
          builder: (context, multiServer, hiddenServers, _) {
            final manager = multiServer.serverManager;
            final serverIds = manager.serverIds;

            if (serverIds.isEmpty) {
              return SettingsGroup(
                title: t.settings.mediaServers,
                children: [ListTile(title: Text(t.settings.noMediaServers))],
              );
            }

            return SettingsGroup(
              title: t.settings.mediaServers,
              children: [
                for (final id in serverIds)
                  _ServerVisibilityTile(
                    serverId: ServerId(id),
                    displayName: manager.serverDisplayName(ServerId(id)),
                    isOwned: manager.isOwnerOrAdmin(ServerId(id)),
                    isHidden: hiddenServers.isServerHidden(id),
                    onChanged: (visible) => hiddenServers.setServerHidden(id, hidden: !visible),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ServerVisibilityTile extends StatelessWidget {
  final ServerId serverId;
  final String displayName;
  final bool isOwned;
  final bool isHidden;
  final ValueChanged<bool> onChanged;

  const _ServerVisibilityTile({
    required this.serverId,
    required this.displayName,
    required this.isOwned,
    required this.isHidden,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final mutedTitle = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return FocusableSwitchListTile(
      value: !isHidden,
      onChanged: onChanged,
      secondary: Icon(
        isHidden ? Symbols.visibility_off_rounded : (isOwned ? Symbols.dns_rounded : Symbols.share_rounded),
        fill: 1,
      ),
      title: Text(displayName, style: isHidden ? TextStyle(color: mutedTitle) : null),
      subtitle: Text(isOwned ? t.settings.ownedServer : t.settings.sharedServer),
    );
  }
}
