import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../i18n/strings.g.dart';
import '../../media/media_library.dart';
import '../../providers/hidden_libraries_provider.dart';
import '../../providers/hidden_servers_provider.dart';
import '../../providers/libraries_provider.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/loading_indicator_box.dart';
import '../../widgets/settings_page.dart';

class ServerLibrariesScreen extends StatefulWidget {
  final String serverId;
  final String serverName;

  const ServerLibrariesScreen({super.key, required this.serverId, required this.serverName});

  @override
  State<ServerLibrariesScreen> createState() => _ServerLibrariesScreenState();
}

class _ServerLibrariesScreenState extends State<ServerLibrariesScreen> {
  bool _hiddenLibrariesExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Consumer3<LibrariesProvider, HiddenLibrariesProvider, HiddenServersProvider>(
      builder: (context, librariesProvider, hiddenProvider, hiddenServersProvider, child) {
        final isServerHidden = hiddenServersProvider.isServerHidden(widget.serverId);

        if (librariesProvider.isLoading) {
          return SettingsPage.slivers(
            title: Text(widget.serverName),
            slivers: [
              SliverToBoxAdapter(child: _buildServerToggle(context, hiddenServersProvider, isServerHidden)),
              const SliverFillRemaining(child: Center(child: LoadingIndicatorBox())),
            ],
          );
        }

        final allLibraries = librariesProvider.libraries;
        final serverLibraries = allLibraries.where((l) => l.serverId == widget.serverId).toList();

        if (serverLibraries.isEmpty) {
          return SettingsPage.slivers(
            title: Text(widget.serverName),
            slivers: [
              SliverToBoxAdapter(child: _buildServerToggle(context, hiddenServersProvider, isServerHidden)),
              const SliverFillRemaining(child: Center(child: Text('No libraries found.'))),
            ],
          );
        }

        final visibleLibraries = <MediaLibrary>[];
        final hiddenLibraries = <MediaLibrary>[];

        for (final lib in serverLibraries) {
          if (hiddenProvider.isLibraryHidden(lib.globalKey)) {
            hiddenLibraries.add(lib);
          } else {
            visibleLibraries.add(lib);
          }
        }

        return SettingsPage.slivers(
          title: Text(widget.serverName),
          slivers: [
            SliverToBoxAdapter(child: _buildServerToggle(context, hiddenServersProvider, isServerHidden)),
            SliverToBoxAdapter(child: const Divider()),
            if (visibleLibraries.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Drag to reorder visible libraries.', style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
            SliverReorderableList(
              itemCount: visibleLibraries.length,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final item = visibleLibraries.removeAt(oldIndex);
                visibleLibraries.insert(newIndex, item);

                final updatedAllLibraries = List<MediaLibrary>.from(allLibraries);
                final updatedServerLibraries = [...visibleLibraries, ...hiddenLibraries];
                updatedAllLibraries.removeWhere((l) => l.serverId == widget.serverId);

                final firstIndex = allLibraries.indexWhere((l) => l.serverId == widget.serverId);
                if (firstIndex != -1) {
                  updatedAllLibraries.insertAll(firstIndex, updatedServerLibraries);
                } else {
                  updatedAllLibraries.addAll(updatedServerLibraries);
                }

                librariesProvider.updateLibraryOrder(updatedAllLibraries);
              },
              itemBuilder: (context, index) {
                final lib = visibleLibraries[index];

                return ListTile(
                  key: ValueKey(lib.globalKey),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: const AppIcon(Symbols.drag_handle_rounded),
                      ),
                    ),
                  ),
                  title: Text(lib.title),
                  trailing: PopupMenuButton<String>(
                    icon: const AppIcon(Symbols.more_vert_rounded),
                    onSelected: (value) {
                      if (value == 'hide') {
                        hiddenProvider.hideLibrary(lib.globalKey);
                      }
                    },
                    itemBuilder: (context) => [const PopupMenuItem(value: 'hide', child: Text('Hide Library'))],
                  ),
                );
              },
            ),
            if (hiddenLibraries.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: Text('Hidden Libraries (${hiddenLibraries.length})'),
                      trailing: AppIcon(
                        _hiddenLibrariesExpanded ? Symbols.expand_less_rounded : Symbols.expand_more_rounded,
                        fill: 1,
                      ),
                      onTap: () {
                        setState(() {
                          _hiddenLibrariesExpanded = !_hiddenLibrariesExpanded;
                        });
                      },
                    ),
                    if (_hiddenLibrariesExpanded)
                      ...hiddenLibraries.map((lib) {
                        return ListTile(
                          key: ValueKey('hidden_${lib.globalKey}'),
                          title: Text(lib.title),
                          trailing: TextButton(
                            onPressed: () {
                              hiddenProvider.unhideLibrary(lib.globalKey);
                            },
                            child: const Text('Show'),
                          ),
                        );
                      }),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildServerToggle(BuildContext context, HiddenServersProvider hiddenServersProvider, bool isServerHidden) {
    return SwitchListTile(
      secondary: AppIcon(isServerHidden ? Symbols.visibility_off_rounded : Symbols.visibility_rounded, fill: 1),
      title: Text(Translations.of(context).settings.showServer),
      subtitle: Text(Translations.of(context).settings.showServerDescription),
      value: !isServerHidden,
      onChanged: (value) {
        if (value) {
          hiddenServersProvider.unhideServer(widget.serverId);
        } else {
          hiddenServersProvider.hideServer(widget.serverId);
        }
      },
    );
  }
}
