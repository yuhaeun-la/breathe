import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'settings_provider.dart';
import 'settings_screen.dart';

void main() {
  runApp(const BreatheApp());
}

class BreatheApp extends StatelessWidget {
  const BreatheApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BreathSettings(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Pretendard',
          useMaterial3: true,
        ),
        home: const BreatheScreen(),
      ),
    );
  }
}

class BreatheScreen extends StatefulWidget {
  const BreatheScreen({super.key});

  @override
  State<BreatheScreen> createState() => _BreatheScreenState();
}

class _BreatheScreenState extends State<BreatheScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  Animation<double>? _scaleAnimation;
  Animation<double>? _opacityAnimation;

  String _currentPhase = 'inhale';
  int _remainingSeconds = 4;
  bool _isPaused = true;
  bool _isInBackground = false;

  Timer? _timer;
  int _lastTotalDuration = 0;
  int _lastInhaleDuration = 4;
  int _lastHoldDuration = 7;
  int _lastExhaleDuration = 8;
  DateTime? _backgroundTime;
  double _backgroundProgress = 0.0;
  bool _isKorean = false;

  String _getPhaseText(String phase) {
    if (!_isKorean) {
      switch (phase) {
        case 'inhale':
          return 'Inhale';
        case 'hold':
          return 'Hold';
        case 'exhale':
          return 'Exhale';
        default:
          return 'Breathe';
      }
    } else {
      switch (phase) {
        case 'inhale':
          return '들이쉬기';
        case 'hold':
          return '멈춤';
        case 'exhale':
          return '내쉬기';
        default:
          return '호흡';
      }
    }
  }

  String _getCycleSummary(BreathSettings settings) {
    if (_isKorean) {
      return '들이쉬기 ${settings.inhaleDuration}초 · 멈춤 ${settings.holdDuration}초 · 내쉬기 ${settings.exhaleDuration}초';
    } else {
      return 'Inhale ${settings.inhaleDuration}s · Hold ${settings.holdDuration}s · Exhale ${settings.exhaleDuration}s';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(vsync: this);
    _isKorean = Platform.localeName.startsWith('ko');
    
    // AnimationController 리스너로 타이머 동기화
    _controller.addListener(_onAnimationUpdate);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // 백그라운드로 이동
      if (!_isPaused && !_isInBackground) {
        _isInBackground = true;
        _backgroundTime = DateTime.now();
        _backgroundProgress = _controller.value;
        _controller.stop();
        _timer?.cancel();
      }
    } else if (state == AppLifecycleState.resumed) {
      // 포그라운드로 복귀
      if (_isInBackground && !_isPaused) {
        _isInBackground = false;
        if (_backgroundTime != null) {
          final elapsed = DateTime.now().difference(_backgroundTime!);
          final settings = Provider.of<BreathSettings>(context, listen: false);
          final totalSeconds = settings.totalDuration;
          final elapsedSeconds = elapsed.inSeconds;
          
          // 경과 시간만큼 진행률 업데이트
          final progressDelta = elapsedSeconds / totalSeconds;
          var newProgress = _backgroundProgress + progressDelta;
          
          // 사이클이 넘어갔다면 나머지만 사용
          if (newProgress >= 1.0) {
            newProgress = newProgress % 1.0;
          }
          
          _controller.value = newProgress;
          _updatePhaseFromProgress(newProgress, settings);
        }
        _controller.repeat();
        _startTimer(Provider.of<BreathSettings>(context, listen: false));
      }
    }
  }

  void _onAnimationUpdate() {
    if (!_isPaused && !_isInBackground && mounted) {
      final settings = Provider.of<BreathSettings>(context, listen: false);
      _updatePhaseFromProgress(_controller.value, settings);
    }
  }

  void _updatePhaseFromProgress(double progress, BreathSettings settings) {
    if (!mounted) return;
    
    final totalDuration = settings.totalDuration;
    final elapsedSeconds = (progress * totalDuration).round();
    final elapsed = elapsedSeconds % totalDuration;

    String newPhase;
    int newRemainingSeconds;

    if (elapsed < settings.inhaleDuration) {
      newPhase = 'inhale';
      newRemainingSeconds = settings.inhaleDuration - elapsed;
    } else if (elapsed < settings.inhaleDuration + settings.holdDuration) {
      newPhase = 'hold';
      newRemainingSeconds = settings.holdDuration - (elapsed - settings.inhaleDuration);
    } else {
      newPhase = 'exhale';
      newRemainingSeconds = settings.exhaleDuration - 
          (elapsed - settings.inhaleDuration - settings.holdDuration);
    }

    if (newPhase != _currentPhase || newRemainingSeconds != _remainingSeconds) {
      setState(() {
        _currentPhase = newPhase;
        _remainingSeconds = newRemainingSeconds;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = Provider.of<BreathSettings>(context);
    _setupAnimations(settings);
  }

  void _setupAnimations(BreathSettings settings) {
    final totalDuration = settings.totalDuration;

    // Only recreate animations if durations changed
    if (totalDuration != _lastTotalDuration) {
      _lastTotalDuration = totalDuration;
      _timer?.cancel();
      _controller.stop();

      _controller.duration = Duration(seconds: totalDuration);

      // Scale animation
      _scaleAnimation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 0.6, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: settings.inhaleDuration / totalDuration,
        ),
        TweenSequenceItem(
          tween: ConstantTween<double>(1.0),
          weight: settings.holdDuration / totalDuration,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 0.6)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: settings.exhaleDuration / totalDuration,
        ),
      ]).animate(_controller);

      // Opacity animation
      _opacityAnimation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 0.6, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: settings.inhaleDuration / totalDuration,
        ),
        TweenSequenceItem(
          tween: ConstantTween<double>(1.0),
          weight: settings.holdDuration / totalDuration,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 0.6)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: settings.exhaleDuration / totalDuration,
        ),
      ]).animate(_controller);

      // Don't auto-start on initialization
    }
  }

  void _startTimer(BreathSettings settings) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        final elapsed = timer.tick % settings.totalDuration;

        if (elapsed < settings.inhaleDuration) {
          _currentPhase = 'inhale';
          _remainingSeconds =
              settings.inhaleDuration - (elapsed % settings.inhaleDuration);
        } else if (elapsed <
            settings.inhaleDuration + settings.holdDuration) {
          _currentPhase = 'hold';
          _remainingSeconds = settings.holdDuration -
              ((elapsed - settings.inhaleDuration) % settings.holdDuration);
        } else {
          _currentPhase = 'exhale';
          _remainingSeconds = settings.exhaleDuration -
              ((elapsed - settings.inhaleDuration - settings.holdDuration) %
                  settings.exhaleDuration);
        }
      });
    });
  }

  void _restart() {
    final settings = Provider.of<BreathSettings>(context, listen: false);
    _controller.stop();
    _timer?.cancel();
    _controller.value = 0.0;
    setState(() {
      _currentPhase = 'inhale';
      _remainingSeconds = settings.inhaleDuration;
      _isPaused = true;
    });
  }

  void _togglePlayPause() {
    final settings = Provider.of<BreathSettings>(context, listen: false);
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _controller.stop();
        _timer?.cancel();
      } else {
        _controller.repeat();
        _startTimer(settings);
      }
    });
  }

  Color _getPhaseColor() {
    switch (_currentPhase) {
      case 'inhale':
        return const Color(0xFF64B5F6); // Blue
      case 'hold':
        return const Color(0xFFFFD54F); // Gold
      case 'exhale':
        return const Color(0xFFFF8A65); // Coral
      default:
        return const Color(0xFF81C784);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F5E9), // Soft mint green
              Color(0xFFF3E5F5), // Soft lavender
              Color(0xFFFCE4EC), // Soft pink
            ],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _isPaused
                        ? 0.5
                        : (_opacityAnimation?.value ?? 0.8),
                    child: Transform.scale(
                        scale: _scaleAnimation?.value ?? 0.8,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeInOut,
                          width: 280,
                          height: 280,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                _getPhaseColor().withValues(alpha: 0.5),
                                _getPhaseColor().withValues(alpha: 0.3),
                                _getPhaseColor().withValues(alpha: 0.1),
                              ],
                            ),
                            border: Border.all(
                              color: _getPhaseColor().withValues(alpha: 0.15),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _getPhaseColor().withValues(alpha: 0.4),
                                blurRadius: 60,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _getPhaseText(_currentPhase),
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Colors.white.withValues(alpha: 0.95),
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '$_remainingSeconds',
                                  style: TextStyle(
                                    fontSize: 56,
                                    fontWeight: FontWeight.w300,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                },
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getCycleSummary(Provider.of<BreathSettings>(context)),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ),
                  const SizedBox(height: 280),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _restart,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          child: Icon(
                            Icons.refresh_rounded,
                            color: _getPhaseColor(),
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: _togglePlayPause,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          child: Icon(
                            _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                            color: _getPhaseColor(),
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 48,
              right: 20,
              child: IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  color: Color(0xFF666666),
                  size: 28,
                ),
                onPressed: () async {
                  final wasPaused = _isPaused;
                  if (!wasPaused) {
                    _togglePlayPause(); // Pause during settings
                  }
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  if (!wasPaused) {
                    _togglePlayPause(); // Resume if it was playing
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
