import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';


/// A compact voice-note player: play/pause, a seek bar and the time.
class AudioMessagePlayer extends StatefulWidget {
  final String filePath;
  final int? durationMs;
  final Color accent;
  final Color textColor;

  const AudioMessagePlayer({
    super.key,
    required this.filePath,
    required this.durationMs,
    required this.accent,
    required this.textColor,
  });

  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<AudioMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    if (widget.durationMs != null) {
      _total = Duration(milliseconds: widget.durationMs!);
    }
    _player.onDurationChanged.listen((d) {
      if (mounted && d > Duration.zero) setState(() => _total = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playing = state == PlayerState.playing);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.pause();
      } else {
        if (!File(widget.filePath).existsSync()) return;
        await _player.play(DeviceFileSource(widget.filePath));
      }
    } catch (_) {}
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _total.inMilliseconds;
    final value = totalMs == 0
        ? 0.0
        : (_position.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final shown = _playing || _position > Duration.zero ? _position : _total;

    return SizedBox(
      width: 210,
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 38,
              height: 38,
              decoration:
                  BoxDecoration(color: widget.accent, shape: BoxShape.circle),
              child: Icon(
                _playing ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 18,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: widget.accent,
                      inactiveTrackColor: widget.accent.withValues(alpha: 0.25),
                      thumbColor: widget.accent,
                    ),
                    child: Slider(
                      value: value,
                      onChanged: (v) async {
                        if (totalMs == 0) return;
                        final pos =
                            Duration(milliseconds: (v * totalMs).round());
                        await _player.seek(pos);
                        setState(() => _position = pos);
                      },
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.mic, size: 13, color: widget.textColor),
                    const SizedBox(width: 4),
                    Text(
                      _fmt(shown),
                      style: TextStyle(fontSize: 11, color: widget.textColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
