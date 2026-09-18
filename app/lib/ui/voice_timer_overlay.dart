import 'dart:async';
import 'dart:math';
import 'package:flutter/semantics.dart';

import 'package:flutter/material.dart';

import '../app_container.dart';
import '../core/events.dart';
import '../l10n/messages.dart';
import '../managers/settings/definitions.dart' as defs;
import '../managers/voice_timers/voice_timer_manager.dart';
import 'toast.dart';

/// Timer pills live above the screensaver, Now Playing and camera views.
class VoiceTimerOverlay extends StatefulWidget {
  const VoiceTimerOverlay({super.key, required this.container});
  final AppContainer container;

  @override
  State<VoiceTimerOverlay> createState() => _VoiceTimerOverlayState();
}

class _VoiceTimerOverlayState extends State<VoiceTimerOverlay> {
  AppContainer get c => widget.container;
  Timer? _tick;
  StreamSubscription<SettingChanged>? _settings;
  double _x = .5, _y = .08;

  @override
  void initState() {
    super.initState();
    _readPosition();
    c.voiceTimers.timers.addListener(_changed);
    c.voiceTimers.alerts.addListener(_changed);
    c.voiceTimers.error.addListener(_error);
    _settings = c.bus.on<SettingChanged>().listen((e) {
      if (e.key == defs.voiceTimerPosition.key) {
        setState(_readPosition);
      }
    });
    _changed();
  }

  void _readPosition() {
    final parts = c.settings.get(defs.voiceTimerPosition).split(',');
    double part(int i, double fallback) {
      final v = i < parts.length ? double.tryParse(parts[i]) : null;
      return v != null && v.isFinite ? v.clamp(0, 1) : fallback;
    }

    _x = part(0, .5);
    _y = part(1, .08);
  }

  void _changed() {
    _tick?.cancel();
    _tick = null;
    if (c.voiceTimers.timers.value.any((t) => t.active)) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
    if (mounted) setState(() {});
  }

  void _error() => showToast(
    context,
    title: l10n(context).voiceTimerActionError,
    kind: ToastKind.error,
  );

  void _save() => c.settings.set(
    defs.voiceTimerPosition,
    '${_x.toStringAsFixed(4)},${_y.toStringAsFixed(4)}',
  );

  @override
  void dispose() {
    c.voiceTimers.timers.removeListener(_changed);
    c.voiceTimers.alerts.removeListener(_changed);
    c.voiceTimers.error.removeListener(_error);
    _settings?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timers = [
      ...c.voiceTimers.alerts.value,
      ...c.voiceTimers.timers.value.where(
        (t) => !c.voiceTimers.alerts.value.any((a) => a.id == t.id),
      ),
    ];
    if (timers.isEmpty) return const SizedBox.shrink();
    final strings = l10n(context);
    final now = DateTime.now();
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = max(0.0, constraints.maxWidth - 24);
          final availableHeight = max(0.0, constraints.maxHeight - 24);
          if (availableWidth < 100 || availableHeight < 80) {
            return const SizedBox.shrink();
          }
          final columns = min(timers.length, availableWidth >= 510 ? 2 : 1);
          final width = min(
            availableWidth,
            columns * 250.0 + (columns - 1) * 10,
          );
          final pillWidth = (width - (columns - 1) * 10) / columns;
          final rows = (timers.length / columns).ceil();
          final textScale = MediaQuery.textScalerOf(context);
          final pillHeight = max(
            56.0,
            textScale.scale(13) * 1.15 + textScale.scale(21) * 1.15 + 16,
          );
          final naturalHeight = rows * (pillHeight + 10) - 10 + 20;
          final height = min(availableHeight, naturalHeight);
          final overflow = naturalHeight > height;
          final freeX = availableWidth - width;
          final freeY = availableHeight - height;
          void drag(DragUpdateDetails d) => setState(() {
            if (freeX > 0) _x = (_x + d.delta.dx / freeX).clamp(0, 1);
            if (freeY > 0) _y = (_y + d.delta.dy / freeY).clamp(0, 1);
          });
          return Stack(
            children: [
              Positioned(
                left: 12 + _x * freeX,
                top: 12 + _y * freeY,
                width: width,
                height: height,
                child: Listener(
                  onPointerDown: (_) => c.screensaver.markControlTouch(),
                  child: Column(
                    children: [
                      Tooltip(
                        message: strings.voiceTimerDrag,
                        child: GestureDetector(
                          key: const ValueKey('timer-drag-handle'),
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: drag,
                          onPanEnd: (_) => _save(),
                          child: SizedBox(
                            width: 64,
                            height: 20,
                            child: Center(
                              child: Container(
                                width: 30,
                                height: 4,
                                decoration: const ShapeDecoration(
                                  color: Color(0x99FFFFFF),
                                  shape: StadiumBorder(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: overflow
                              ? null
                              : const NeverScrollableScrollPhysics(),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final timer in timers)
                                GestureDetector(
                                  key: ValueKey('voice-timer-${timer.id}'),
                                  onTap: () => c.voiceTimers.control(
                                    timer.id,
                                    timer.active ? 'pause' : 'resume',
                                  ),
                                  onDoubleTap: () =>
                                      c.voiceTimers.control(timer.id, 'cancel'),
                                  onPanUpdate: overflow ? null : drag,
                                  onPanEnd: overflow ? null : (_) => _save(),
                                  child: Tooltip(
                                    message: timer.finished
                                        ? strings.voiceTimerDismissHint
                                        : timer.active
                                        ? strings.voiceTimerPauseHint
                                        : strings.voiceTimerResumeHint,
                                    child: Semantics(
                                      button: true,
                                      label:
                                          '${timer.name.isEmpty ? strings.voiceTimerDefaultName : timer.name}, ${voiceTimerTime(timer.remaining(now))}',
                                      customSemanticsActions: {
                                        CustomSemanticsAction(
                                          label: strings.voiceTimerCancel,
                                        ): () => c.voiceTimers.control(
                                          timer.id,
                                          'cancel',
                                        ),
                                      },
                                      child: _TimerPill(
                                        timer: timer,
                                        width: pillWidth,
                                        height: pillHeight,
                                        now: now,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TimerPill extends StatelessWidget {
  const _TimerPill({
    required this.timer,
    required this.width,
    required this.height,
    required this.now,
  });
  final VoiceTimer timer;
  final double width;
  final double height;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final remaining = timer.remaining(now);
    final accent = timer.finished
        ? const Color(0xFFFF8A65)
        : timer.active
        ? const Color(0xFF81C784)
        : const Color(0xFFFFD54F);
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.fromLTRB(6, 6, 18, 6),
      decoration: const ShapeDecoration(
        color: Color(0xB31C1C1E),
        shape: StadiumBorder(side: BorderSide(color: Color(0x30FFFFFF))),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .16),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox.square(
                  dimension: 38,
                  child: CircularProgressIndicator(
                    value: timer.totalSeconds > 0
                        ? remaining / timer.totalSeconds
                        : 0,
                    strokeWidth: 2,
                    color: accent,
                    backgroundColor: const Color(0x24FFFFFF),
                  ),
                ),
                Icon(
                  timer.finished
                      ? Icons.notifications_active_outlined
                      : timer.active
                      ? Icons.timer_outlined
                      : Icons.pause_rounded,
                  size: 22,
                  color: accent,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timer.name.isEmpty
                      ? l10n(context).voiceTimerDefaultName
                      : timer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.15,
                  ),
                ),
                Text(
                  timer.finished
                      ? l10n(context).voiceTimerFinished
                      : voiceTimerTime(remaining),
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
