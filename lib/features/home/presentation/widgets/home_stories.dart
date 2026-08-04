import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// Bosh sahifa storisi — video admin paneldan yuklanadi (backend'dan keladi).
/// Sarlavha yo'q — faqat video ko'rsatiladi.
class StoryData {
  const StoryData({
    required this.videoUrl,
    required this.accentStart,
    required this.accentEnd,
  });

  final String videoUrl;
  final Color accentStart;
  final Color accentEnd;
}

class StoryCard extends StatelessWidget {
  const StoryCard({
    super.key,
    required this.story,
    required this.seen,
    required this.onTap,
  });

  final StoryData story;
  final bool seen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ringColors = seen
        ? const [Color(0xFFB8C0CC), Color(0xFF7F8A98)]
        : [story.accentStart, story.accentEnd];

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 78,
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: ringColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ringColors.first.withValues(alpha: 0.20),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0F172A),
                ),
                child: _StoryPreviewFrame(videoUrl: story.videoUrl),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryPreviewFrame extends StatefulWidget {
  const _StoryPreviewFrame({required this.videoUrl});

  final String videoUrl;

  @override
  State<_StoryPreviewFrame> createState() => _StoryPreviewFrameState();
}

class _StoryPreviewFrameState extends State<_StoryPreviewFrame> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final controller = _controller;
      if (controller == null) return;

      await controller.initialize();
      await controller.seekTo(Duration.zero);
      await controller.pause();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const ColoredBox(color: Color(0xFF111827));
    }

    if (_errorMessage != null || !controller.value.isInitialized) {
      return const ColoredBox(color: Color(0xFF111827));
    }

    final size = controller.value.size;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: size.width > 0 ? size.width : 1,
        height: size.height > 0 ? size.height : 1,
        child: VideoPlayer(controller),
      ),
    );
  }
}

class StoryViewerPage extends StatefulWidget {
  const StoryViewerPage({
    super.key,
    required this.stories,
    required this.initialIndex,
  });

  final List<StoryData> stories;
  final int initialIndex;

  @override
  State<StoryViewerPage> createState() => StoryViewerPageState();
}

class StoryViewerPageState extends State<StoryViewerPage> {
  static const String _telegramUrl = 'https://t.me/taraqqiyot_namangan_rasmiy';
  static const String _instagramUrl =
      'https://www.instagram.com/taraqqiyot_namangan/';

  VideoPlayerController? _controller;
  late int _currentIndex;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showControls = true;
  bool _showFollowOverlay = false;
  bool _autoAdvanceTriggered = false;
  Timer? _controlsHideTimer;

  Future<void> _openExternalLink(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Havola ochilmasa jim o'tamiz — storis ko'rishni buzmaydi
    }
  }

  StoryData get _currentStory => widget.stories[_currentIndex];
  bool get _hasPreviousStory => _currentIndex > 0;
  bool get _hasNextStory => _currentIndex < widget.stories.length - 1;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _initialize();
  }

  Future<void> _initialize() async {
    _cancelControlsHideTimer();
    final previousController = _controller;
    _controller = null;
    await previousController?.dispose();
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(_currentStory.videoUrl),
    );
    _controller = controller;

    _autoAdvanceTriggered = false;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _showControls = true;
        _showFollowOverlay = false;
      });
    }

    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(1.0);
      controller.addListener(() {
        if (!mounted || _controller != controller) return;
        final value = controller.value;
        final ended =
            value.isInitialized &&
            value.duration > Duration.zero &&
            value.position >= value.duration &&
            !value.isPlaying;
        if (ended && !_autoAdvanceTriggered) {
          _autoAdvanceTriggered = true;
          if (_hasNextStory) {
            // Video tugagach avtomatik keyingi storisga o'tamiz
            _switchStory(1);
          } else if (!_showFollowOverlay) {
            // Oxirgi storis tugaganda "Bizni kuzatib boring" oynasini ochamiz
            setState(() {
              _showFollowOverlay = true;
            });
          }
        }
      });
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _showControls = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          if (!mounted) return;
          await controller.play();
          _scheduleControlsHide();
        } catch (error) {
          if (!mounted) return;
          setState(() {
            _errorMessage = error.toString();
          });
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _switchStory(int direction) async {
    final nextIndex = _currentIndex + direction;
    if (nextIndex < 0 || nextIndex >= widget.stories.length) return;
    setState(() {
      _currentIndex = nextIndex;
    });
    await _initialize();
  }

  void _cancelControlsHideTimer() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = null;
  }

  void _scheduleControlsHide() {
    _cancelControlsHideTimer();
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _showControls = false;
      });
    });
  }

  void _showControlsTemporarily() {
    if (!mounted) return;
    setState(() {
      _showControls = true;
    });
    _scheduleControlsHide();
  }

  @override
  void dispose() {
    _cancelControlsHideTimer();
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildStoryProgressSegment(
    int index,
    VideoPlayerController? controller,
  ) {
    const double barHeight = 3;
    final BorderRadius radius = BorderRadius.circular(8);
    final Color trackColor = Colors.white.withValues(alpha: 0.28);

    // Ko'rib bo'lingan storislar to'liq oq, keyingilari xira chiziq
    if (index != _currentIndex) {
      return Container(
        height: barHeight,
        decoration: BoxDecoration(
          color: index < _currentIndex ? Colors.white : trackColor,
          borderRadius: radius,
        ),
      );
    }

    if (controller == null) {
      return Container(
        height: barHeight,
        decoration: BoxDecoration(color: trackColor, borderRadius: radius),
      );
    }

    // Joriy storis — video pozitsiyasiga qarab to'ladi
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final value = controller.value;
        double progress = 0;
        if (value.isInitialized && value.duration.inMilliseconds > 0) {
          progress =
              (value.position.inMilliseconds / value.duration.inMilliseconds)
                  .clamp(0.0, 1.0);
        }
        return Container(
          height: barHeight,
          decoration: BoxDecoration(color: trackColor, borderRadius: radius),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: radius,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fon qora bo'lgani uchun status bar (soat, batareya) shu sahifada
    // oq bo'lishi kerak — globaldagi qora uslubni bekor qiladi
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
      backgroundColor: const Color(0xFF050816),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            final controller = _controller;

            return GestureDetector(
              // Chapga surish — keyingi storis, o'ngga surish — oldingisi
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -150) {
                  _switchStory(1);
                } else if (velocity > 150) {
                  _switchStory(-1);
                }
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Color(0xFF050816)),
                        if (!_isLoading &&
                            _errorMessage == null &&
                            controller != null &&
                            controller.value.isInitialized)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _showControlsTemporarily();
                            },
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: controller.value.aspectRatio > 0
                                    ? controller.value.aspectRatio
                                    : 9 / 16,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    VideoPlayer(controller),
                                    if (_showControls)
                                      Positioned(
                                        left: 12,
                                        right: 12,
                                        bottom: 14,
                                        child: _StoryControlsBar(
                                          controller: controller,
                                          onUserAction:
                                              _showControlsTemporarily,
                                          onPlayPause: () {
                                            setState(() {
                                              if (controller.value.isPlaying) {
                                                controller.pause();
                                              } else {
                                                final ended =
                                                    controller.value.position >=
                                                    controller.value.duration;
                                                if (ended) {
                                                  controller.seekTo(
                                                    Duration.zero,
                                                  );
                                                }
                                                controller.play();
                                              }
                                            });
                                            _showControlsTemporarily();
                                          },
                                          onToggleMute: () {
                                            setState(() {
                                              final isMuted =
                                                  controller.value.volume == 0;
                                              controller.setVolume(
                                                isMuted ? 1.0 : 0.0,
                                              );
                                            });
                                            _showControlsTemporarily();
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_hasPreviousStory)
                    Positioned(
                      left: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _StorySideButton(
                          icon: Icons.chevron_left_rounded,
                          onTap: () => _switchStory(-1),
                        ),
                      ),
                    ),
                  if (_hasNextStory)
                    Positioned(
                      right: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _StorySideButton(
                          icon: Icons.chevron_right_rounded,
                          onTap: () => _switchStory(1),
                        ),
                      ),
                    ),
                  if (_showFollowOverlay)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.85),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                image: const DecorationImage(
                                  image: AssetImage('assets/logo.png'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Bizni kuzatib boring!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _SocialCircleButton(
                                  icon: FontAwesomeIcons.instagram,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft,
                                    colors: [
                                      Color(0xFF515BD4),
                                      Color(0xFF8134AF),
                                      Color(0xFFDD2A7B),
                                      Color(0xFFF58529),
                                    ],
                                  ),
                                  onTap: () => _openExternalLink(_instagramUrl),
                                ),
                                const SizedBox(width: 28),
                                _SocialCircleButton(
                                  icon: FontAwesomeIcons.telegram,
                                  color: const Color(0xFF229ED9),
                                  onTap: () => _openExternalLink(_telegramUrl),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Segmentli progress: har bir storis uchun bitta chiziq
                        Row(
                          children: [
                            for (int i = 0; i < widget.stories.length; i++) ...[
                              if (i > 0) const SizedBox(width: 4),
                              Expanded(
                                child: _buildStoryProgressSegment(
                                  i,
                                  controller,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                // Logo va nom bosilganda Instagram sahifamiz ochiladi
                                onTap: () => _openExternalLink(_instagramUrl),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          width: 1.5,
                                        ),
                                        image: const DecorationImage(
                                          image: AssetImage('assets/logo.png'),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Flexible(
                                      child: Text(
                                        'Taraqqiyot teaching center',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          shadows: [
                                            Shadow(
                                              color: Color(0x99000000),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              splashRadius: 22,
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      ),
    );
  }
}

class _SocialCircleButton extends StatelessWidget {
  const _SocialCircleButton({
    required this.icon,
    required this.onTap,
    this.color,
    this.gradient,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: gradient == null ? color : null,
          gradient: gradient,
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Center(child: FaIcon(icon, color: Colors.white, size: 30)),
      ),
    );
  }
}

class _StorySideButton extends StatelessWidget {
  const _StorySideButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.44),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: Colors.white, size: 34),
        ),
      ),
    );
  }
}

class _StoryControlsBar extends StatelessWidget {
  const _StoryControlsBar({
    required this.controller,
    required this.onUserAction,
    required this.onPlayPause,
    required this.onToggleMute,
  });

  final VideoPlayerController controller;
  final VoidCallback onUserAction;
  final VoidCallback onPlayPause;
  final VoidCallback onToggleMute;

  static const Color _accentRed = Color(0xFFE0304E);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isPlaying = controller.value.isPlaying;
        final isMuted = controller.value.volume == 0;
        final duration = controller.value.duration;
        final position = controller.value.position;
        final maxMs = duration.inMilliseconds > 0 ? duration.inMilliseconds : 1;

        return Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    onUserAction();
                    onPlayPause();
                  },
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: _accentRed,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _formatDuration(position),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6.5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: _accentRed,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: position.inMilliseconds.clamp(0, maxMs).toDouble(),
                    min: 0,
                    max: maxMs.toDouble(),
                    onChanged: (value) {
                      onUserAction();
                      controller.seekTo(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
              ),
              Text(
                _formatDuration(duration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              IconButton(
                padding: EdgeInsets.zero,
                splashRadius: 20,
                onPressed: () {
                  onUserAction();
                  onToggleMute();
                },
                icon: Icon(
                  isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
