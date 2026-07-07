part of '../video_controls.dart';

extension _PlexVideoControlsKeyEventMethods on _PlexVideoControlsState {
  Future<void> _initKeyboardService() async {
    _keyboardService = await KeyboardShortcutsService.getInstance();
  }

  void _showScreenshotToast() {
    widget.toastController.show(Symbols.photo_camera_rounded, t.videoControls.screenshotSaved);
  }

  bool _isDirectionalKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;
  }

  bool _isSelectKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA;
  }

  /// Determine if the key event should toggle play/pause based on configured hotkeys.
  bool _isPlayPauseKey(KeyEvent event) {
    final logicalKey = event.logicalKey;
    final physicalKey = event.physicalKey;

    // Always accept hardware media play/pause keys (Android TV remotes)
    if (logicalKey == LogicalKeyboardKey.mediaPlayPause ||
        logicalKey == LogicalKeyboardKey.mediaPlay ||
        logicalKey == LogicalKeyboardKey.mediaPause) {
      return true;
    }

    // When the shortcuts service is available, respect the configured play/pause hotkey
    if (_keyboardService != null) {
      final hotkey = _keyboardService!.hotkeys['play_pause'];
      if (hotkey == null) return false;
      return hotkey.key == physicalKey;
    }

    // Fallback to defaults while the service is loading
    return physicalKey == PhysicalKeyboardKey.space || physicalKey == PhysicalKeyboardKey.mediaPlayPause;
  }

  bool _isMediaSeekKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.mediaFastForward ||
        key == LogicalKeyboardKey.mediaRewind ||
        key == LogicalKeyboardKey.mediaSkipForward ||
        key == LogicalKeyboardKey.mediaSkipBackward;
  }

  bool _isMediaTrackKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.mediaTrackNext || key == LogicalKeyboardKey.mediaTrackPrevious;
  }

  bool _isPlayPauseActivation(KeyEvent event) {
    return event is KeyDownEvent && _isPlayPauseKey(event);
  }

  /// Global key event handler for focus-independent shortcuts (desktop only)
  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (!mounted) return false;
    if (ModalRoute.of(context)?.isCurrent != true) return false;

    // Any actionable key (keyboard / dpad / controller) cancels an in-progress
    // auto-skip countdown. Non-consuming — we fall through so the key still
    // performs its normal action. Single cancel point for keys.
    if (event.isActionable) _cancelAutoSkipFromUserInteraction();

    // When an overlay sheet is open (e.g. subtitle search with text fields),
    // don't consume key events — let text input work normally.
    if (OverlaySheetController.maybeOf(context)?.isOpen ?? false) {
      return false;
    }

    // Back key fallback when _focusNode lost focus (TV, or desktop with nav on).
    // Focus.onKeyEvent won't fire if _focusNode lost focus, so handle ESC here.
    if ((_videoPlayerNavigationEnabled || PlatformDetector.isTV()) && event.logicalKey.isBackKey) {
      if (!_focusNode.hasFocus) {
        // Skip if an overlay sheet is open — the sheet's FocusScope handles
        // back keys via its own onKeyEvent. Without this check, this global
        // handler would call Navigator.pop() alongside the sheet's handler.
        final sheetOpen = OverlaySheetController.maybeOf(context)?.isOpen ?? false;
        if (sheetOpen) return false;
        // On TV, mark coordinator early (KeyDown) so PopScope.onPopInvokedWithResult
        // sees it before KeyUp — prevents the system back from racing ahead.
        if (PlatformDetector.isTV() && event is KeyDownEvent) {
          BackKeyCoordinator.markHandled();
        }
        final backResult = handleBackKeyAction(event, () {
          if (PlatformDetector.isTV()) {
            if (_showControls) {
              if (widget.chromeController.contentStripVisible) {
                _desktopControlsKey.currentState?.dismissContentStrip();
                widget.chromeController.setContentStripVisible(false);
                _restartHideTimerIfPlaying();
                return;
              }
              _hideControls();
              return;
            }
            (widget.onBack ?? () => Navigator.of(context).pop(true))();
            return;
          }
          if (!_showControls) {
            _showControlsWithFocus();
          } else {
            (widget.onBack ?? () => Navigator.of(context).pop(true))();
          }
        });
        if (backResult != KeyEventResult.ignored) return true;
      }
    }

    // Play/pause + directional fallback when _focusNode lost focus on TV.
    // Same pattern as the back-key fallback above: Focus.onKeyEvent won't
    // fire when _focusNode lost focus (e.g. Android system UI stole it,
    // MediaSession overlay, returning from background), so handle these
    // globally as a safety net. The !_focusNode.hasFocus guard prevents
    // double-handling when Focus.onKeyEvent already processes the event.
    if (_videoPlayerNavigationEnabled && !_focusNode.hasFocus) {
      // Play/pause — always toggle, regardless of focus state.
      if (_isPlayPauseActivation(event)) {
        _focusNode.requestFocus();
        _playOrPause();
        if (_selectShowsOsdTimeline) {
          _showControlsWithTimelineFocus();
        } else {
          _showControlsWithFocus();
        }
        return true;
      }

      // Directional keys — show controls and seek/navigate.
      if (_isDirectionalKey(event.logicalKey) && event.isActionable) {
        _focusNode.requestFocus();
        final key = event.logicalKey;
        final isHorizontal = key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight;
        if (isHorizontal) {
          _showControlsWithTimelineFocus();
          if (widget.canControl) {
            unawaited(_seekByTime(forward: key == LogicalKeyboardKey.arrowRight));
          }
        } else {
          _showControlsWithFocus();
        }
        return true;
      }

      // Select/OK — reclaim focus and mirror the normal Focus.onKeyEvent
      // behavior (Plex-style: show OSD / non-Plex: toggle play).
      if (_isSelectKey(event.logicalKey) && event is KeyDownEvent) {
        _focusNode.requestFocus();
        if (_selectShowsOsdTimeline) {
          _showControlsWithTimelineFocus();
        } else {
          _playOrPause();
          _showControlsWithFocus();
        }
        return true;
      }

      // Media seek keys (FF/RW on remotes)
      if (event is KeyDownEvent && _isMediaSeekKey(event.logicalKey)) {
        _focusNode.requestFocus();
        if (widget.canControl) {
          unawaited(_seekToChapter(forward: event.logicalKey == LogicalKeyboardKey.mediaFastForward ||
              event.logicalKey == LogicalKeyboardKey.mediaSkipForward));
        }
        _showControlsWithFocus();
        return true;
      }
    }

    // Only handle when video player navigation is disabled (desktop mode without D-pad nav)
    if (_videoPlayerNavigationEnabled) return false;

    // Skip on mobile (unless TV)
    final isMobile = PlatformDetector.isMobile(context) && !PlatformDetector.isTV();
    if (isMobile) return false;

    // Handle play/pause globally - works regardless of focus
    if (_isPlayPauseActivation(event)) {
      _playOrPause();
      _showControlsWithFocus(requestFocus: false);
      return true; // Event handled, stop propagation
    }

    // Fallback: handle all other shortcuts when focus has drifted away
    // (e.g. after controls auto-hide). The !hasFocus guard prevents
    // double-handling when the Focus onKeyEvent already processes the event.
    if (!_focusNode.hasFocus && _keyboardService != null) {
      // On Windows/Linux with navigation off, ESC only exits fullscreen —
      // never exits the player. Intercept before the keyboard shortcuts
      // service which would call onBack and pop the route.
      // Skip if an overlay sheet is open — let the sheet handle ESC.
      if (!_videoPlayerNavigationEnabled && (Platform.isWindows || Platform.isLinux) && event.logicalKey.isBackKey) {
        final sheetOpen = OverlaySheetController.maybeOf(context)?.isOpen ?? false;
        if (!sheetOpen) {
          if (event is KeyUpEvent) {
            _exitFullscreenIfNeeded();
          }
          _focusNode.requestFocus();
          return true;
        }
      }
      final result = _keyboardService!.handleVideoPlayerKeyEvent(
        event,
        widget.player,
        _toggleFullscreen,
        _toggleSubtitles,
        _nextAudioTrack,
        _nextSubtitleTrack,
        _nextChapter,
        _previousChapter,
        onBack: widget.onBack ?? () => Navigator.of(context).pop(true),
        onToggleShader: _toggleShader,
        onNextEpisode: widget.onNext,
        onPreviousEpisode: widget.onPrevious,
        onScreenshot: _showScreenshotToast,
        onZoomIn: widget.onZoomIn,
        onZoomOut: widget.onZoomOut,
        onZoomReset: widget.onResetVideoZoom,
        currentPositionEpoch: widget.currentPositionEpoch,
        onLiveSeek: widget.onLiveSeek,
        onLiveSeekBy: widget.onLiveSeekBy,
      );
      if (result == KeyEventResult.handled) {
        _focusNode.requestFocus(); // self-heal focus
        return true;
      }
    }

    return false;
  }

  KeyEventResult _handleControlsKeyEvent(KeyEvent event, bool isMobile) {
    // On Windows/Linux with navigation off, ESC only exits fullscreen —
    // never exits the player. Consume all back key events and check
    // actual window state asynchronously.
    if (!_videoPlayerNavigationEnabled && (Platform.isWindows || Platform.isLinux) && event.logicalKey.isBackKey) {
      if (event is KeyUpEvent) {
        _exitFullscreenIfNeeded();
      }
      return KeyEventResult.handled;
    }
    // On TV, mark coordinator early (KeyDown) so PopScope.onPopInvokedWithResult
    // sees it before KeyUp — prevents the system back from racing ahead.
    if (PlatformDetector.isTV() && event.logicalKey.isBackKey && event is KeyDownEvent) {
      BackKeyCoordinator.markHandled();
    }
    final backResult = handleBackKeyAction(event, () {
      if (PlatformDetector.isTV()) {
        if (_showControls) {
          if (widget.chromeController.contentStripVisible) {
            _desktopControlsKey.currentState?.dismissContentStrip();
            widget.chromeController.setContentStripVisible(false);
            _restartHideTimerIfPlaying();
            return;
          }
          _hideControls();
          return;
        }
        (widget.onBack ?? () => Navigator.of(context).pop(true))();
        return;
      }
      if (!_showControls) {
        _showControlsWithFocus();
        return;
      }
      (widget.onBack ?? () => Navigator.of(context).pop(true))();
    });
    if (backResult != KeyEventResult.ignored) {
      return backResult;
    }

    // Only handle KeyDown and KeyRepeat events.
    // Consume KeyUp events for navigation keys to prevent leaking to previous routes.
    // Let non-navigation keys (volume, etc.) pass through to the OS.
    if (!event.isActionable) {
      if (!event.logicalKey.isNavigationKey) return KeyEventResult.ignored;
      return KeyEventResult.handled;
    }

    // Reset hide timer on any keyboard/controller input when controls are visible.
    if (_showControls) {
      _restartHideTimerIfPlaying();
    }

    final key = event.logicalKey;
    final isPlayPauseKey = _isPlayPauseKey(event);

    // Always consume play/pause keys to prevent propagation to background routes.
    // On TV/mobile, handle play/pause here; on desktop, the global handler does it.
    if (isPlayPauseKey) {
      if (_videoPlayerNavigationEnabled || isMobile) {
        if (_isPlayPauseActivation(event)) {
          _playOrPause();
          if (_videoPlayerNavigationEnabled && _selectShowsOsdTimeline) {
            _showControlsWithTimelineFocus();
          } else {
            _showControlsWithFocus(requestFocus: _videoPlayerNavigationEnabled);
          }
        }
      }
      return KeyEventResult.handled;
    }

    // Handle media seek keys (Android TV remotes).
    // Uses chapter navigation if chapters are available, otherwise seeks by configured time.
    if (event is KeyDownEvent && _isMediaSeekKey(key)) {
      if (widget.canControl) {
        final isForward = key == LogicalKeyboardKey.mediaFastForward || key == LogicalKeyboardKey.mediaSkipForward;
        unawaited(_seekToChapter(forward: isForward));
      }
      _showControlsWithFocus(requestFocus: _videoPlayerNavigationEnabled);
      return KeyEventResult.handled;
    }

    // Handle next/previous track keys (Android TV remotes).
    // Uses same behavior as seek keys: chapter navigation or time-based seek.
    if (event is KeyDownEvent && _isMediaTrackKey(key)) {
      if (widget.canControl) {
        unawaited(_seekToChapter(forward: key == LogicalKeyboardKey.mediaTrackNext));
      }
      _showControlsWithFocus(requestFocus: _videoPlayerNavigationEnabled);
      return KeyEventResult.handled;
    }

    // Handle Select/Enter when controls are hidden.
    // Only intercept if this Focus node itself has primary focus (not a descendant).
    if (_isSelectKey(key) && !_showControls && _focusNode.hasPrimaryFocus) {
      if (_selectShowsOsdTimeline) {
        // Plex-style: show OSD with timeline (seek bar) focused, no play/pause toggle
        _showControlsWithTimelineFocus();
      } else {
        _playOrPause();
        _showControlsWithFocus();
      }
      return KeyEventResult.handled;
    }

    // On desktop/TV, show controls on directional input.
    // LEFT/RIGHT focuses timeline for seeking, UP/DOWN focuses play/pause.
    if (!isMobile && _isDirectionalKey(key) && (_videoPlayerNavigationEnabled || PlatformDetector.isTV())) {
      // Controls hidden, OR controls visible but no child has focus yet (race
      // between addPostFrameCallback focus scheduling and the next key press).
      // In both cases, show/keep controls and handle the directional action.
      if (!_showControls || _focusNode.hasPrimaryFocus) {
        final isHorizontal = key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight;
        if (isHorizontal) {
          _showControlsWithTimelineFocus();
          if (widget.canControl) {
            final forward = key == LogicalKeyboardKey.arrowRight;
            unawaited(_seekByTime(forward: forward));
          }
        } else if (_selectShowsOsdTimeline && key == LogicalKeyboardKey.arrowUp && _currentMarker != null) {
          // Plex-style: UP from the implicit timeline position goes to skip
          // intro/credits button when one is visible, instead of opening OSD.
          // Un-dismiss the button first (it auto-hides after 7s) so the widget
          // re-enters the tree, then focus it on the next frame.
          if (_skipButtonDismissed) {
            _setControlsState(() {
              _skipButtonDismissed = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _skipMarkerFocusNode.requestFocus();
            });
          } else {
            _skipMarkerFocusNode.requestFocus();
          }
        } else {
          _showControlsWithFocus();
        }
        return KeyEventResult.handled;
      }
      // Children (DesktopVideoControls) handle navigation first via their own onKeyEvent.
      // If we reach here, children already declined the event — consume it to prevent leaking.
      return KeyEventResult.handled;
    }

    // Pass other events to the keyboard shortcuts service.
    if (_keyboardService == null) {
      return event.logicalKey.isNavigationKey ? KeyEventResult.handled : KeyEventResult.ignored;
    }

    final result = _keyboardService!.handleVideoPlayerKeyEvent(
      event,
      widget.player,
      _toggleFullscreen,
      _toggleSubtitles,
      _nextAudioTrack,
      _nextSubtitleTrack,
      _nextChapter,
      _previousChapter,
      onBack: widget.onBack ?? () => Navigator.of(context).pop(true),
      onToggleShader: _toggleShader,
      onSkipMarker: _performAutoSkip,
      onNextEpisode: widget.onNext,
      onPreviousEpisode: widget.onPrevious,
      onScreenshot: _showScreenshotToast,
      onZoomIn: widget.onZoomIn,
      onZoomOut: widget.onZoomOut,
      onZoomReset: widget.onResetVideoZoom,
      currentPositionEpoch: widget.currentPositionEpoch,
      onLiveSeek: widget.onLiveSeek,
      onLiveSeekBy: widget.onLiveSeekBy,
      onSeekRequested: widget.onSeekRequested,
    );
    if (!event.logicalKey.isNavigationKey) return result;
    // Never return .ignored for navigation keys — prevent leaking to previous routes.
    return result == KeyEventResult.ignored ? KeyEventResult.handled : result;
  }
}
