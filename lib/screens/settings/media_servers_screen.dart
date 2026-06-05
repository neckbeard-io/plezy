import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../i18n/strings.g.dart';
import '../../providers/hidden_servers_provider.dart';
import '../../providers/multi_server_provider.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/settings_page.dart';
import '../../media/ids.dart';
import '../../widgets/settings_section.dart';
import 'server_libraries_screen.dart';

class MediaServersScreen extends StatelessWidget {
  const MediaServersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPage.slivers(
      title: const Text('Media Servers'),
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate([
            const SettingsSectionHeader('Servers'),
            Consumer2<MultiServerProvider, HiddenServersProvider>(
              builder: (context, provider, hiddenServers, child) {
                // Show ALL servers from the manager (unfiltered) so hidden
                // ones are still accessible in settings.
                final allServerIds = provider.serverManager.serverIds;

                if (allServerIds.isEmpty) {
                  return const Padding(padding: EdgeInsets.all(16.0), child: Text('No servers connected.'));
                }

                return Column(
                  children: allServerIds.map((serverId) {
                    final displayName = provider.serverManager.serverDisplayName(ServerId(serverId));
                    final isOwned = provider.serverManager.isOwnerOrAdmin(ServerId(serverId));
                    final isHidden = hiddenServers.isServerHidden(serverId);

                    return ListTile(
                      leading: AppIcon(
                        isHidden
                            ? Symbols.visibility_off_rounded
                            : (isOwned ? Symbols.dns_rounded : Symbols.share_rounded),
                        fill: 1,
                      ),
                      title: Text(
                        displayName,
                        style: isHidden
                            ? TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))
                            : null,
                      ),
                      subtitle: Text(
                        isHidden
                            ? (isOwned
                                  ? Translations.of(context).settings.ownedHidden
                                  : Translations.of(context).settings.sharedHidden)
                            : (isOwned
                                  ? Translations.of(context).settings.owned
                                  : Translations.of(context).settings.shared),
                      ),
                      trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ServerLibrariesScreen(serverId: serverId, serverName: displayName),
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ]),
        ),
      ],
    );
  }
}
