import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_powered_coach_2026/features/onboarding/data/onboarding_local_storage.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  final _slides = const [
    _OnboardingSlide(
      stepLabel: '01',
      title: 'Build Speaking Confidence Faster',
      description:
          'AI Powered Coach helps students and aspiring speakers practice communication with a clear, guided flow.',
      icon: Icons.record_voice_over_rounded,
      accent: Color(0xFF1F86D8),
      heroGradient: [Color(0xFF1C87DC), Color(0xFF4AA9F3)],
      tags: ['Student Friendly', 'Guided Practice', 'Clean Workflow'],
      bullets: [
        'Start with a topic that matches your real scenario.',
        'Practice daily in short sessions for better consistency.',
      ],
    ),
    _OnboardingSlide(
      stepLabel: '02',
      title: 'Get Live Delivery Feedback',
      description:
          'While speaking, you can monitor transcript updates and delivery metrics to instantly improve your flow.',
      icon: Icons.multitrack_audio_rounded,
      accent: Color(0xFF2088D9),
      heroGradient: [Color(0xFF1E7ECF), Color(0xFF389EEB)],
      tags: ['Live Transcript', 'Pace Tracking', 'Filler Word Alerts'],
      bullets: [
        'See your words-per-minute and speaking pace trends.',
        'Detect filler words and improve clarity in real time.',
      ],
    ),
    _OnboardingSlide(
      stepLabel: '03',
      title: 'Analyze Content and Progress',
      description:
          'Review each session with content and delivery scores, then track your improvement through visual trends.',
      icon: Icons.insights_rounded,
      accent: Color(0xFF1A76C1),
      heroGradient: [Color(0xFF186FB6), Color(0xFF2E90DA)],
      tags: ['Session Scores', 'Trend Charts', 'History Records'],
      bullets: [
        'Check strengths and areas to improve after every session.',
        'Compare recent sessions and monitor long-term growth.',
      ],
    ),
    _OnboardingSlide(
      stepLabel: '04',
      title: 'Follow Personalized Coaching',
      description:
          'Receive custom recommendations based on your weak points and keep momentum using smart reminders.',
      icon: Icons.auto_awesome_rounded,
      accent: Color(0xFF145F9F),
      heroGradient: [Color(0xFF155D99), Color(0xFF247AC3)],
      tags: ['Custom Drills', 'Priority Actions', 'Practice Reminders'],
      bullets: [
        'Mark recommendations as done as you improve.',
        'Stay consistent with reminders and repeatable routines.',
      ],
    ),
  ];

  bool get _isLastPage => _currentPage == _slides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) {
      return;
    }

    setState(() {
      _isCompleting = true;
    });

    await OnboardingLocalStorage.markCompleted();
    if (!mounted) {
      return;
    }
    context.go('/login');
  }

  void _nextPage() {
    if (_isLastPage) {
      _completeOnboarding();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];

    return Scaffold(
      body: Stack(
        children: [
          _OnboardingBackground(accent: slide.accent),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      const _BrandPill(),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFD6E9FA)),
                        ),
                        child: Text(
                          '${_currentPage + 1}/${_slides.length}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: const Color(0xFF2A6F9F),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: _isCompleting ? null : _completeOnboarding,
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _slides.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        return _OnboardingSlideView(slide: _slides[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      final selected = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: selected ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: selected
                              ? slide.accent
                              : const Color(0xFFBDD9EF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isCompleting ? null : _nextPage,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _isCompleting
                            ? const SizedBox(
                                key: ValueKey('loading'),
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                key: ValueKey('button_$_currentPage'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isLastPage
                                        ? Icons.rocket_launch_rounded
                                        : Icons.arrow_forward_rounded,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(_isLastPage ? 'Get Started' : 'Next'),
                                ],
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
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.stepLabel,
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.heroGradient,
    required this.tags,
    required this.bullets,
  });

  final String stepLabel;
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final List<Color> heroGradient;
  final List<String> tags;
  final List<String> bullets;
}

class _OnboardingSlideView extends StatelessWidget {
  const _OnboardingSlideView({required this.slide});

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heroHeight = constraints.maxHeight < 620 ? 180.0 : 220.0;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: heroHeight,
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: slide.heroGradient,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F2379B9),
                        blurRadius: 26,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -18,
                        top: -22,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -22,
                        bottom: -32,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'FEATURE ${slide.stepLabel}',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 1.4,
                            ),
                          ),
                          child: Icon(
                            slide.icon,
                            size: 42,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          'Smart Practice Mode',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  slide.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF113A59),
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  slide.description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF3D5B74),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: slide.tags.map((tag) {
                    return _TagChip(text: tag, accent: slide.accent);
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFD2E6F9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: slide.bullets.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 3, right: 8),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: slide.accent,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: const Color(0xFF35536D)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingBackground extends StatelessWidget {
  const _OnboardingBackground({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE6F4FF), Color(0xFFF3FAFF), Color(0xFFF9FCFF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -90,
            child: _GlowBlob(size: 260, color: accent.withValues(alpha: 0.16)),
          ),
          Positioned(
            top: 180,
            right: -100,
            child: _GlowBlob(size: 240, color: accent.withValues(alpha: 0.12)),
          ),
          Positioned(
            bottom: -120,
            right: -70,
            child: _GlowBlob(size: 260, color: accent.withValues(alpha: 0.14)),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _BrandPill extends StatelessWidget {
  const _BrandPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD6E9FA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF1F86D8),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.psychology_alt_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'AI Coach',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF20587F),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: const Color(0xFF2B5F86),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
