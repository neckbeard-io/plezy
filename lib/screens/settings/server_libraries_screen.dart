import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
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
  String? _reorderingGlobalKey;

  // Long-press detection state for controller select key
  Timer? _longPressTimer;
  String? _pendingSelectGlobalKey;
  int? _pendingSelectIndex;
  bool _longPressTriggered = false;

  // Explicit focus nodes keyed by library globalKey so we can
  // re-focus the correct item after hiding one.
  final Map<String, FocusNode> _focusNodes = {};

  FocusNode _getFocusNode(String globalKey) {
    return _focusNodes.putIfAbsent(globalKey, () => FocusNode(debugLabel: 'lib_$globalKey'));
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _cancelReorder() {
    final key = _reorderingGlobalKey;
    setState(() {
      _reorderingIndex = null;
      _reorderingGlobalKey = null;
    });
    if (key != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _getFocusNode(key).requestFocus();
      });
    }
  }

  void _cancelSelectTracking() {
    _longPressTimer?.cancel();
    _pendingSelectGlobalKey = null;
    _pendingSelectIndex = null;
    _longPressTriggered = false;
  }

  /// Start tracking a select key press for tap vs long-press.
  void _startSelectTracking(int index, String globalKey) {
    _longPressTimer?.cancel();
    _pendingSelectGlobalKey = globalKey;
    _pendingSelectIndex = index;
    _longPressTriggered = false;
    _longPressTimer = Timer(kLongPressTimeout, () {
      _longPressTriggered = true;
      final gk = _pendingSelectGlobalKey;
      setState(() {
        _reorderingIndex = _pendingSelectIndex;
        _reorderingGlobalKey = gk;
      });
      _pendingSelectGlobalKey = null;
      _pendingSelectIndex = null;
      // Re-focus the reordering item so the highlight stays on it
      if (gk != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _getFocusNode(gk).requestFocus();
        });
      }
    });
  }

  /// End tracking: if long-press didn't fire, treat as a tap (hide).
  void _endSelectTracking() {
    _longPressTimer?.cancel();
    if (!_longPressTriggered && _pendingSelectGlobalKey != null) {
      final hiddenIndex = _pendingSelectIndex!;
      final hiddenKey = _pendingSelectGlobalKey!;
      context.read<HiddenLibrariesProvider>().hideLibrary(hiddenKey);
      // Re-focus the next item after the hidden one is removed from the tree.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _refocusAfterHide(hiddenIndex, hiddenKey);
      });
    }
    _cancelSelectTracking();
  }

  /// After hiding a library, focus the item that now occupies the same index
  /// (or the last item if we hid the last one).
  void _refocusAfterHide(int hiddenIndex, String hiddenKey) {
    // Clean up the disposed focus node for the hidden library
    _focusNodes.remove(hiddenKey)?.dispose();

    final librariesProvider = context.read<LibrariesProvider>();
    final hiddenProvider = context.read<HiddenLibrariesProvider>();
    final visible = librariesProvider.libraries
        .where((l) => l.serverId == widget.serverId)
        .where((l) => !hiddenProvider.isLibraryHidden(l.globalKey))
        .toList();
    if (visible.isEmpty) return;

    final targetIndex = hiddenIndex < visible.length ? hiddenIndex : visible.length - 1;
    _getFocusNode(visible[targetIndex].globalKey).requestFocus();
  }

  /// Per-item key handler: intercepts select key to distinguish tap from
  /// long-press. Sits between the ListTile and MaterialApp's Shortcuts in
  /// the focus bubble chain, so returning [handled] prevents onTap from
  /// firing via keyboard while leaving touch/mouse onTap unaffected.
  KeyEventResult _handleItemKeyEvent(KeyEvent event, int index, String globalKey) {
    if (_reorderingIndex != null) return KeyEventResult.ignored;
    if (!event.logicalKey.isSelectKey) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      _startSelectTracking(index, globalKey);
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent) {
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      _endSelectTracking();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
    // Re-focus the moved item so the highlight follows it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _getFocusNode(item.globalKey).requestFocus();
    });
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
          _reorderingGlobalKey = null;
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
                final isThisReordering = _reorderingGlobalKey == lib.globalKey;

                return Focus(
                  key: ValueKey(lib.globalKey),
                  canRequestFocus: false,
                  onKeyEvent: (_, event) => _handleItemKeyEvent(event, index, lib.globalKey),
                  child: Builder(
                    builder: (tileContext) => ListTile(
                      focusNode: _getFocusNode(lib.globalKey),
                      tileColor: isThisReordering
                          ? Theme.of(context).colorScheme.primaryContainer
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
                          ? (isThisReordering ? () {} : null)
                          : () => hiddenProvider.hideLibrary(lib.globalKey),
                      onLongPress: isReordering
                          ? null
                          : () => setState(() {
                              _reorderingIndex = index;
                              _reorderingGlobalKey = lib.globalKey;
                            }),
                    ),
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

        // Always wrap in Focus to intercept key events:
        // - In reorder mode: handle up/down/select/back for reordering
        // - In normal mode: per-item Focus handles select key tap vs long-press
        return Focus(
          canRequestFocus: false,
          onKeyEvent: (_, event) {
            if (_reorderingIndex == null) return KeyEventResult.ignored;
            return _handleReorderKeyEvent(event, visibleLibraries.length);
          },
          child: page,
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
