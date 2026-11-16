import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

import '../data/chat_repository.dart';

const _accent = Color(0xFF2E86DE);

enum AttachAction { galleryPhoto, cameraPhoto, galleryVideo, cameraVideo }

Future<AttachAction?> askAttachAction(BuildContext context) {
  Widget item(IconData icon, String label, AttachAction action) => ListTile(
        leading: Icon(icon, size: 32),
        title: Text(label, style: const TextStyle(fontSize: 20)),
        onTap: () => Navigator.of(context).pop(action),
      );

  return showModalBottomSheet<AttachAction>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            item(Icons.photo_library_outlined, 'รูปภาพจากคลัง', AttachAction.galleryPhoto),
            item(Icons.photo_camera_outlined, 'ถ่ายรูป', AttachAction.cameraPhoto),
            item(Icons.video_library_outlined, 'วิดีโอจากคลัง', AttachAction.galleryVideo),
            item(Icons.videocam_outlined, 'ถ่ายวิดีโอ (ไม่เกิน 1 นาที)', AttachAction.cameraVideo),
          ],
        ),
      ),
    ),
  );
}

String formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class PickedVideo {
  const PickedVideo({
    required this.path,
    required this.width,
    required this.height,
    required this.durationMs,
  });

  final String path;
  final int width;
  final int height;
  final int durationMs;
}

class VideoPickException implements Exception {
  const VideoPickException(this.message);

  final String message;
}

Future<PickedVideo?> pickChatVideo(ImageSource source) async {
  final file = await ImagePicker().pickVideo(
    source: source,
    maxDuration: ChatRepository.maxVideoDuration,
  );
  if (file == null) return null;

  final size = await File(file.path).length();
  if (size > ChatRepository.maxVideoBytes) {
    throw const VideoPickException('วิดีโอใหญ่เกิน 100 MB กรุณาเลือกคลิปที่สั้นกว่านี้');
  }

  final controller = VideoPlayerController.file(File(file.path));
  try {
    await controller.initialize();
    final value = controller.value;
    final limit = ChatRepository.maxVideoDuration + const Duration(seconds: 1);
    if (value.duration > limit) {
      throw const VideoPickException('วิดีโอยาวเกิน 1 นาที กรุณาเลือกคลิปที่สั้นกว่านี้');
    }
    return PickedVideo(
      path: file.path,
      width: value.size.width.round().clamp(1, 10000),
      height: value.size.height.round().clamp(1, 10000),
      durationMs: value.duration.inMilliseconds.clamp(1, 600000),
    );
  } finally {
    await controller.dispose();
  }
}

class VoiceRecorderBar extends StatefulWidget {
  const VoiceRecorderBar({
    super.key,
    required this.onSend,
    required this.onCancel,
    required this.onError,
  });

  final void Function(String path, int durationMs) onSend;
  final VoidCallback onCancel;
  final void Function(String message) onError;

  @override
  State<VoiceRecorderBar> createState() => _VoiceRecorderBarState();
}

class _VoiceRecorderBarState extends State<VoiceRecorderBar> {
  final _recorder = AudioRecorder();
  final _watch = Stopwatch();
  Timer? _ticker;
  bool _started = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      if (!await _recorder.hasPermission()) {
        _fail('ต้องอนุญาตให้ใช้ไมโครโฟนก่อน จึงจะอัดเสียงได้');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
      if (!mounted) return;
      _watch.start();
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        if (_watch.elapsed >= ChatRepository.maxVoiceDuration) {
          _send();
        } else {
          setState(() {});
        }
      });
      setState(() => _started = true);
    } catch (_) {
      _fail('เริ่มอัดเสียงไม่สำเร็จ');
    }
  }

  void _fail(String message) {
    if (_finished) return;
    _finished = true;
    widget.onError(message);
  }

  Future<void> _send() async {
    if (_finished || !_started) return;
    _finished = true;
    _ticker?.cancel();
    _watch.stop();
    final durationMs = _watch.elapsedMilliseconds;
    final path = await _recorder.stop();
    if (path == null || durationMs < 800) {
      widget.onError('เสียงสั้นเกินไป กรุณาอัดให้นานขึ้น');
      return;
    }
    widget.onSend(path, durationMs);
  }

  Future<void> _cancel() async {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();
    _watch.stop();
    try {
      await _recorder.cancel();
    } catch (_) {}
    widget.onCancel();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (!_finished) {
      _recorder.cancel().catchError((_) {});
    }
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final left = ChatRepository.maxVoiceDuration - _watch.elapsed;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: _cancel,
            child: Text('ยกเลิก', style: TextStyle(fontSize: 18, color: scheme.error)),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fiber_manual_record,
                        color: _started ? Colors.red : scheme.outline, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      _started ? 'กำลังอัดเสียง ${formatDuration(_watch.elapsed)}' : 'กำลังเตรียม...',
                      style: TextStyle(fontSize: 18, color: scheme.onSurface),
                    ),
                  ],
                ),
                if (_started)
                  Text('เหลือ ${formatDuration(left.isNegative ? Duration.zero : left)}',
                      style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: _accent),
            iconSize: 28,
            tooltip: 'ส่งเสียง',
            onPressed: _started ? _send : null,
            icon: const Icon(Icons.send_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class AudioMessageContent extends StatefulWidget {
  const AudioMessageContent({super.key, required this.message});

  final ChatMessage message;

  @override
  State<AudioMessageContent> createState() => _AudioMessageContentState();
}

class _AudioMessageContentState extends State<AudioMessageContent> {
  static _AudioMessageContentState? _active;

  AudioPlayer? _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  Duration _position = Duration.zero;
  bool _playing = false;
  bool _loading = false;

  Duration get _total => Duration(milliseconds: widget.message.durationMs ?? 0);

  Future<void> _toggle() async {
    if (_playing) {
      await _player?.pause();
      return;
    }
    if (_active != null && _active != this) {
      await _active!._player?.pause();
    }
    _active = this;

    final existing = _player;
    if (existing != null) {
      await existing.play();
      return;
    }

    setState(() => _loading = true);
    final player = AudioPlayer();
    _player = player;
    _positionSub = player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _stateSub = player.playerStateStream.listen((state) {
      if (!mounted) return;
      final completed = state.processingState == ProcessingState.completed;
      if (completed) {
        player.pause();
        player.seek(Duration.zero);
      }
      setState(() => _playing = state.playing && !completed);
    });
    try {
      await player.setUrl(widget.message.mediaUrl!);
    } catch (_) {
      _player = null;
      await _positionSub?.cancel();
      await _stateSub?.cancel();
      await player.dispose();
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เปิดเสียงไม่สำเร็จ')),
        );
      }
      return;
    }
    if (mounted) setState(() => _loading = false);
    await player.play();
  }

  @override
  void dispose() {
    if (_active == this) _active = null;
    _positionSub?.cancel();
    _stateSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = _total.inMilliseconds == 0 ? const Duration(seconds: 1) : _total;
    final progress = (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final shown = _playing || _position > Duration.zero ? _position : _total;

    return SizedBox(
      width: 220,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 40,
                    tooltip: _playing ? 'หยุด' : 'เล่นเสียง',
                    onPressed: _toggle,
                    icon: Icon(
                      _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      color: _accent,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: _accent,
                    backgroundColor: scheme.outlineVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(formatDuration(shown),
                    style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VideoMessageContent extends StatelessWidget {
  const VideoMessageContent({super.key, required this.message, required this.width});

  final ChatMessage message;
  final double width;

  @override
  Widget build(BuildContext context) {
    final w = message.width ?? 16;
    final h = message.height ?? 9;
    final ratio = (w / h).clamp(0.6, 1.8);
    final duration = Duration(milliseconds: message.durationMs ?? 0);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VideoViewerPage(url: message.mediaUrl!),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: width,
          child: AspectRatio(
            aspectRatio: ratio,
            child: ColoredBox(
              color: Colors.black87,
              child: Stack(
                children: [
                  const Center(
                    child: Icon(Icons.play_circle_fill, size: 64, color: Colors.white),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 6,
                    child: Text(
                      formatDuration(duration),
                      style: const TextStyle(fontSize: 15, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VideoViewerPage extends StatefulWidget {
  const VideoViewerPage({super.key, required this.url});

  final String url;

  @override
  State<VideoViewerPage> createState() => _VideoViewerPageState();
}

class _VideoViewerPageState extends State<VideoViewerPage> {
  late final VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..addListener(_onUpdate);
    _controller.initialize().then((_) {
      if (mounted) _controller.play();
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.value;
    Widget body;
    if (_failed) {
      body = const Center(
        child: Text('เปิดวิดีโอไม่สำเร็จ', style: TextStyle(fontSize: 18, color: Colors.white)),
      );
    } else if (!value.isInitialized) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio,
                child: GestureDetector(
                  onTap: () => value.isPlaying ? _controller.pause() : _controller.play(),
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
            child: Row(
              children: [
                IconButton(
                  iconSize: 44,
                  tooltip: value.isPlaying ? 'หยุด' : 'เล่น',
                  onPressed: () => value.isPlaying ? _controller.pause() : _controller.play(),
                  icon: Icon(
                    value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: Colors.white,
                  ),
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(playedColor: _accent),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${formatDuration(value.position)} / ${formatDuration(value.duration)}',
                  style: const TextStyle(fontSize: 15, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: body),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                iconSize: 32,
                tooltip: 'ปิด',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
