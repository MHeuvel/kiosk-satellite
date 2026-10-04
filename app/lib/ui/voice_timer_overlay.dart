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

/// The pills' size at a Timer pill scale of 100%.
const _baseScale = 1.2;

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
  double _scale = _baseScale;

  @override
  void initState() {
    super.initState();
    _readPosition();
    _readScale();
    c.voiceTimers.timers.addListener(_changed);
    c.voiceTimers.alerts.addListener(_changed);
    c.voiceTimers.alertHidden.addListener(_changed);
    c.voiceTimers.error.addListener(_error);
    _settings = c.bus.on<SettingChanged>().listen((e) {
      if (e.key == defs.voiceTimerPosition.key) {
        setState(_readPosition);
      } else if (e.key == defs.voiceTimerPillScale.key) {
        setState(_readScale);
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

  void _readScale() => _scale =
      _baseScale *
      c.settings.get(defs.voiceTimerPillScale).clamp(50, 300) /
      100;

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
    c.voiceTimers.alertHidden.removeListener(_changed);
    c.voiceTimers.error.removeListener(_error);
    _settings?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timers = [
      if (!c.voiceTimers.alertHidden.value) ...c.voiceTimers.alerts.value,
      ...c.voiceTimers.timers.value.where(
        (t) => !c.voiceTimers.alerts.value.any((a) => a.id == t.id),
      ),
    ];
    if (timers.isEmpty) return const SizedBox.shrink();
    final strings = l10n(context);
    final now = DateTime.now();
    final scale = _scale;
    final gap = 10.0 * scale;
    final naturalWidth = 250.0 * scale;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = max(0.0, constraints.maxWidth - 24);
          final availableHeight = max(0.0, constraints.maxHeight - 24);
          if (availableWidth < 100 || availableHeight < 80) {
            return const SizedBox.shrink();
          }
          final columns = min(
            timers.length,
            availableWidth >= 2 * naturalWidth + gap ? 2 : 1,
          );
          final width = min(
            availableWidth,
            columns * naturalWidth + (columns - 1) * gap,
          );
          final pillWidth = (width - (columns - 1) * gap) / columns;
          final rows = (timers.length / columns).ceil();
          final textScale = MediaQuery.textScalerOf(context);
          final pillHeight = max(
            56.0 * scale,
            textScale.scale(13 * scale) * 1.15 +
                textScale.scale(21 * scale) * 1.15 +
                16 * scale,
          );
          final naturalHeight = rows * (pillHeight + gap) - gap + 20;
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
                            spacing: gap,
                            runSpacing: gap,
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
                                        scale: scale,
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
    required this.scale,
    required this.now,
  });
  final VoiceTimer timer;
  final double width;
  final double height;
  final double scale;
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
      padding: EdgeInsets.fromLTRB(6 * scale, 6 * scale, 18 * scale, 6 * scale),
      decoration: ShapeDecoration(
        color: const Color(0xB31C1C1E),
        shape: StadiumBorder(
          side: BorderSide(color: const Color(0x30FFFFFF), width: scale),
        ),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 40 * scale,
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
                  dimension: 38 * scale,
                  child: CircularProgressIndicator(
                    value: timer.totalSeconds > 0
                        ? remaining / timer.totalSeconds
                        : 0,
                    strokeWidth: 2 * scale,
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
                  size: 22 * scale,
                  color: accent,
                ),
              ],
            ),
          ),
          SizedBox(width: 10 * scale),
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13 * scale,
                    height: 1.15,
                  ),
                ),
                Text(
                  timer.finished
                      ? l10n(context).voiceTimerFinished
                      : voiceTimerTime(remaining),
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21 * scale,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
