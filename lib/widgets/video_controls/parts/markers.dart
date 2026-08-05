part of '../video_controls.dart';

extension _PlexVideoControlsMarkerMethods on _PlexVideoControlsState {
  void _listenToPosition() {
    _positionSubscription = widget.player.streams.position.listen((position) {
      _syncCurrentMarkerForPosition(position);
    });
  }

  void _syncCurrentMarkerForCurrentPosition() {
    _syncCurrentMarkerForPosition(widget.player.state.position);
  }

  void _syncCurrentMarkerForPosition(Duration position) {
    if (!_hasRenderedFirstFrame || _markers.isEmpty || !_markersLoaded) {
      _clearCurrentMarker();
      return;
    }

    MediaMarker? foundMarker;
    for (final marker in _markers) {
      if (marker.containsPosition(position)) {
        foundMarker = marker;
        break;
      }
    }

    // After skipping, the throttled post-seek position can momentarily still
    // land inside the marker we just left. Ignore it until the position moves
    // out, so the button doesn't flash back with a fresh countdown.
    if (foundMarker != null && foundMarker == _suppressedSkipMarker) return;
    _suppressedSkipMarker = null;

    if (foundMarker != _currentMarker && mounted) {
      _updateCurrentMarker(foundMarker);
    }
  }

  void _clearCurrentMarker() {
    final hasMarkerState =
        _currentMarker != null ||
        _skipButtonDismissed ||
        _autoSkipTimer != null ||
        _autoSkipProgress != 0.0 ||
        _skipButtonDismissTimer != null;
    if (!hasMarkerState) return;

    if (_currentMarker != null || _skipButtonDismissed) {
      _setControlsState(() {
        _currentMarker = null;
        _skipButtonDismissed = false;
      });
    }
    if (_skipMarkerFocusNode.hasFocus) _skipMarkerFocusNode.unfocus();
    _cancelAutoSkipTimer();
    _cancelSkipButtonDismissTimer();
  }

  /// Updates the current marker and manages auto-skip/focus behavior.
  void _updateCurrentMarker(MediaMarker? foundMarker) {
    if (!_hasRenderedFirstFrame) {
      _clearCurrentMarker();
      return;
    }

    if (foundMarker == null) {
      _clearCurrentMarker();
      return;
    }

    // Opt-in: each marker offers its button once per playback. Without this a
    // marker re-entered by seeking backwards keeps re-prompting.
    if (_suppressSkipReappearance && _shownMarkers.contains(foundMarker)) return;
    _shownMarkers.add(foundMarker);

    _setControlsState(() {
      _currentMarker = foundMarker;
      _skipButtonDismissed = false;
    });

    _startAutoSkipTimer(foundMarker);

    // Auto-skip OFF: dismiss button after 7s if no interaction
    // Auto-skip ON: button stays until controls hide
    if (!_shouldAutoSkipForMarker(foundMarker)) {
      _startSkipButtonDismissTimer();
    }

    // Auto-focus skip button on TV when marker appears (only in keyboard/TV mode)
    if (PlatformDetector.isTV() && InputModeTracker.isKeyboardMode(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _skipMarkerFocusNode.requestFocus();
        }
      });
    }
  }

  Future<void> _skipMarker({bool skipAutoPlayCountdown = false}) async {
    if (!widget.canControl) return;
    if (_currentMarker == null || !_hasRenderedFirstFrame) return;

    final marker = _currentMarker!;
    final endTime = marker.endTime;
    final duration = widget.player.state.duration;
    final isAtEnd = duration > Duration.zero && (duration - endTime).inMilliseconds <= 1000;

    if (marker.isCredits && isAtEnd) {
      if (!skipAutoPlayCountdown && widget.onNext != null) {
        widget.onNext!.call();
      } else {
        // Seeking to EOF is unreliable due to position stream throttling,
        // so pause and defer to the parent's completion flow.
        await widget.player.pause();
        widget.onReachedEnd?.call(skipAutoPlayCountdown: skipAutoPlayCountdown);
      }
    } else {
      await _seekToPosition(endTime);
    }

    if (!mounted) return;
    _setControlsState(() {
      _currentMarker = null;
    });
    // Don't let the post-seek position re-show the marker we just skipped.
    _suppressedSkipMarker = marker;
    _cancelAutoSkipTimer();
    _cancelSkipButtonDismissTimer();
  }

  void _startAutoSkipTimer(MediaMarker marker) {
    _cancelAutoSkipTimer();
    if (!_hasRenderedFirstFrame) return;

    final shouldAutoSkip = (marker.isCredits && _autoSkipCredits) || (!marker.isCredits && _autoSkipIntro);

    if (!shouldAutoSkip || _autoSkipDelay <= 0) return;

    _autoSkipProgress = 0.0;
    const tickDuration = Duration(milliseconds: 200);
    final totalTicks = (_autoSkipDelay * 1000) / tickDuration.inMilliseconds;

    if (totalTicks <= 0) return;

    _autoSkipTimer = Timer.periodic(tickDuration, (timer) {
      if (!mounted || _currentMarker != marker) {
        timer.cancel();
        return;
      }

      _setControlsState(() {
        _autoSkipProgress = (timer.tick / totalTicks).clamp(0.0, 1.0);
      });

      if (timer.tick >= totalTicks) {
        timer.cancel();
        _performAutoSkip(skipAutoPlayCountdown: true);
      }
    });
  }

  void _cancelAutoSkipTimer() {
    final hadTimer = _autoSkipTimer != null;
    _autoSkipTimer?.cancel();
    _autoSkipTimer = null;
    if (mounted && (hadTimer || _autoSkipProgress != 0.0)) {
      _setControlsState(() {
        _autoSkipProgress = 0.0;
      });
    }
  }

  bool _cancelAutoSkipFromUserInteraction() {
    final hadActiveTimer = _autoSkipTimer?.isActive ?? false;
    if (!hadActiveTimer) return false;

    _cancelAutoSkipTimer();
    if (_currentMarker != null && !_skipButtonDismissed) {
      _startSkipButtonDismissTimer();
    }
    return true;
  }

  /// Starts/restarts the skip button dismiss timer. When it fires, hides the
  /// button and cancels any active auto-skip countdown.
  void _startSkipButtonDismissTimer() {
    _skipButtonDismissTimer?.cancel();
    if (!_hasRenderedFirstFrame) return;
    _skipButtonDismissTimer = Timer(const Duration(seconds: 7), () {
      if (!mounted || _currentMarker == null) return;
      _setControlsState(() {
        _skipButtonDismissed = true;
      });
      _cancelAutoSkipTimer();
    });
  }

  void _cancelSkipButtonDismissTimer() {
    _skipButtonDismissTimer?.cancel();
    _skipButtonDismissTimer = null;
  }

  /// Perform the appropriate skip action based on marker type and next episode availability
  void _performAutoSkip({bool skipAutoPlayCountdown = false}) {
    if (!widget.canControl) return;
    if (_currentMarker == null || !_hasRenderedFirstFrame) return;
    unawaited(_skipMarker(skipAutoPlayCountdown: skipAutoPlayCountdown));
  }

  bool _shouldAutoSkipForMarker(MediaMarker marker) {
    return (marker.isCredits && _autoSkipCredits) || (!marker.isCredits && _autoSkipIntro);
  }

  bool _shouldShowAutoSkip() {
    if (_currentMarker == null) return false;
    return _shouldAutoSkipForMarker(_currentMarker!);
  }

  bool get _isSkipMarkerButtonVisible => shouldShowSkipMarkerButton(
    hasFirstFrame: _hasRenderedFirstFrame,
    hasMarker: _currentMarker != null,
    hasPlayNextPrompt: widget.playNextFocusNode != null,
    skipButtonDismissed: _skipButtonDismissed,
    controlsVisible: _showControls,
  );

  void _activateSkipMarker() {
    if (!_isSkipMarkerButtonVisible) return;
    _cancelAutoSkipTimer();
    _performAutoSkip();
  }

  Widget _buildSkipMarkerButton() {
    final isAutoSkipActive = _autoSkipTimer?.isActive ?? false;
    return SkipMarkerButton(
      marker: _currentMarker!,
      playerDuration: widget.player.state.duration,
      hasNextEpisode: widget.onNext != null,
      isAutoSkipActive: isAutoSkipActive,
      shouldShowAutoSkip: _shouldShowAutoSkip(),
      autoSkipDelay: _autoSkipDelay,
      autoSkipProgress: _autoSkipProgress,
      focusNode: _skipMarkerFocusNode,
      onActivate: _activateSkipMarker,
      // Timeline-first: DOWN off the skip button lands on the seek bar, which
      // is where the rest of the OSD navigation now starts from.
      onFocusDown: () => _desktopControlsKey.currentState?.requestTimelineFocus(),
    );
  }

  /// Whether Back belongs to the skip intro/credits button right now, rather
  /// than to the player's usual staged handling (hide controls / leave).
  bool get _skipMarkerOwnsBack => _skipMarkerFocusNode.hasFocus && _isSkipMarkerButtonVisible;

  /// Act on Back while the skip intro/credits button is focused:
  /// - a running auto-skip countdown is cancelled but the button stays, now
  ///   static, so the skip is still one press away;
  /// - otherwise the button is deactivated — focus moves to the timeline, which
  ///   dims it, and UP re-focuses it.
  void _handleSkipMarkerBack() {
    if (!_skipMarkerOwnsBack) return;

    if (_autoSkipTimer?.isActive ?? false) {
      _cancelAutoSkipTimer();
      _startSkipButtonDismissTimer();
      return;
    }

    _deactivateSkipButton();
  }

  /// Hand focus to the timeline rather than hard-hiding the button, which only
  /// dims it (opacity is focus-driven). Hiding stranded focus on the root node,
  /// where the controls' directional navigation had nothing to move from and
  /// navigation looked dead. Moving to a real control keeps D-pad navigation
  /// alive; UP from the timeline re-focuses the button at full opacity.
  void _deactivateSkipButton() {
    _cancelAutoSkipTimer();
    _cancelSkipButtonDismissTimer();
    _showControlsWithTimelineFocus();
  }

  /// Skip button opacity is focus-driven, so rebuild whenever its focus changes.
  void _onSkipMarkerFocusChange() {
    _setControlsState(() {});
  }
}
