import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../focus/dpad_navigator.dart';
import '../../focus/key_event_utils.dart';
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
  int? _reorderingIndex;

  void _cancelReorder() {
    setState(() => _reorderingIndex = null);
  }

  /// Move a visible library from [fromIndex] to [toIndex] and persist the order.
  void _moveLibrary(int fromIndex, int toIndex) {
    final librariesProvider = context.read<LibrariesProvider>();
    final hiddenProvider = context.read<HiddenLibrariesProvider>();

    final allLibraries = librariesProvider.libraries;
    final serverLibraries = allLibraries.where((l) => l.serverId == widget.serverId).toList();

    final visible = <MediaLibrary>[];
    final hidden = <MediaLibrary>[];
    for (final lib in serverLibraries) {
      if (hiddenProvider.isLibraryHidden(lib.globalKey)) {
        hidden.add(lib);
      } else {
        visible.add(lib);
      }
    }

    final item = visible.removeAt(fromIndex);
    visible.insert(toIndex, item);

    final updated = List<MediaLibrary>.from(allLibraries);
    updated.removeWhere((l) => l.serverId == widget.serverId);

    final firstIndex = allLibraries.indexWhere((l) => l.serverId == widget.serverId);
    if (firstIndex != -1) {
      updated.insertAll(firstIndex, [...visible, ...hidden]);
    } else {
      updated.addAll([...visible, ...hidden]);
    }

    librariesProvider.updateLibraryOrder(updated);
    setState(() => _reorderingIndex = toIndex);
  }

  KeyEventResult _handleReorderKeyEvent(KeyEvent event, int visibleCount) {
    final index = _reorderingIndex;
    if (index == null) return KeyEventResult.ignored;

    // Handle back key to cancel reorder
    final backResult = handleBackKeyAction(event, _cancelReorder);
    if (backResult != KeyEventResult.ignored) return backResult;

    // Select key: confirm on KeyDown, consume KeyUp
    if (event.logicalKey.isSelectKey) {
      if (event is KeyDownEvent) _cancelReorder();
      return KeyEventResult.handled;
    }

    if (!event.isActionable) return KeyEventResult.handled;

    final key = event.logicalKey;

    if (key.isUpKey && index > 0) {
      _moveLibrary(index, index - 1);
      return KeyEventResult.handled;
    }
    if (key.isDownKey && index < visibleCount - 1) {
      _moveLibrary(index, index + 1);
      return KeyEventResult.handled;
    }

    // Consume all other keys to prevent focus traversal during reorder
    return KeyEventResult.handled;
  }

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

        // Clamp reordering index if libraries changed underneath
        if (_reorderingIndex != null && _reorderingIndex! >= visibleLibraries.length) {
          _reorderingIndex = null;
        }

        final isReordering = _reorderingIndex != null;

        Widget page = SettingsPage.slivers(
          onBackPressed: isReordering ? _cancelReorder : null,
          title: Text(widget.serverName),
          slivers: [
            SliverToBoxAdapter(child: _buildServerToggle(context, hiddenServersProvider, isServerHidden)),
            SliverToBoxAdapter(child: const Divider()),
            if (visibleLibraries.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    isReordering
                        ? Translations.of(context).settings.reorderInstructions
                        : Translations.of(context).settings.libraryInstructions,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            SliverReorderableList(
              itemCount: visibleLibraries.length,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) newIndex -= 1;
                _moveLibrary(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final lib = visibleLibraries[index];
                final isThisReordering = _reorderingIndex == index;

                return Builder(
                  key: ValueKey(lib.globalKey),
                  builder: (tileContext) => ListTile(
                    tileColor: isThisReordering
                        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : null,
                    leading: isReordering
                        ? (isThisReordering
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppIcon(Symbols.arrow_upward_rounded, size: 18,
                                      color: index > 0 ? null : Theme.of(context).disabledColor),
                                  AppIcon(Symbols.arrow_downward_rounded, size: 18,
                                      color: index < visibleLibraries.length - 1
                                          ? null
                                          : Theme.of(context).disabledColor),
                                ],
                              )
                            : const SizedBox(width: 40))
                        : ReorderableDragStartListener(
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
                    trailing: isReordering
                        ? null
                        : const AppIcon(Symbols.visibility_off_rounded),
                    onTap: isReordering
                        ? null
                        : () => hiddenProvider.hideLibrary(lib.globalKey),
                    onLongPress: isReordering
                        ? null
                        : () => setState(() => _reorderingIndex = index),
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
                          trailing: const Text('Show'),
                          onTap: () => hiddenProvider.unhideLibrary(lib.globalKey),
                        );
                      }),
                  ],
                ),
              ),
          ],
        );

        // Intercept key events during reorder mode to prevent focus traversal
        // and handle up/down/select/back for reordering.
        if (isReordering) {
          page = Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) => _handleReorderKeyEvent(event, visibleLibraries.length),
            child: page,
          );
        }

        return page;
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
