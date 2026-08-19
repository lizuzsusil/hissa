import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';

class IntroSlide {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;

  const IntroSlide({
    required this.icon,
    this.title = '',
    this.subtitle = '',
    required this.gradient,
  });
}

const List<IntroSlide> kIntroSlides = [
  IntroSlide(
    icon: Icons.home_work_outlined,
    gradient: [Color(0xFF45A8D8), Color(0xFF1373A8)],
  ),
  IntroSlide(
    icon: Icons.receipt_long_outlined,
    gradient: [Color(0xFFED6B1E), Color(0xFFC44F07)],
  ),
  IntroSlide(
    icon: Icons.swap_horiz_rounded,
    gradient: [Color(0xFFF8CC4A), Color(0xFFF5A623)],
  ),
  IntroSlide(
    icon: Icons.donut_small_outlined,
    gradient: [Color(0xFF34C07E), Color(0xFF158A4F)],
  ),
];

/// First-run feature carousel. Swipable slides introduce the app, with a
/// Skip control and a final "Get Started" CTA.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == kIntroSlides.length - 1;

  void _next() {
    if (_isLast) {
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titles = [
      l10n.introTitle1,
      l10n.introTitle2,
      l10n.introTitle3,
      l10n.introTitle4,
    ];
    final subtitles = [
      l10n.introSubtitle1,
      l10n.introSubtitle2,
      l10n.introSubtitle3,
      l10n.introSubtitle4,
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Hissa',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onDone,
                    style: TextButton.styleFrom(
                      foregroundColor: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                    child: Text(
                      l10n.skip,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: kIntroSlides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, index) => _IntroPage(
                  slide: kIntroSlides[index],
                  title: titles[index],
                  subtitle: subtitles[index],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  _Dots(count: kIntroSlides.length, index: _index),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: _isLast ? l10n.getStarted : l10n.next,
                    icon: Icons.arrow_forward_rounded,
                    onPressed: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  final IntroSlide slide;
  final String title;
  final String subtitle;

  const _IntroPage({required this.slide, this.title = '', this.subtitle = ''});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: slide.gradient,
              ),
              borderRadius: BorderRadius.circular(38),
              boxShadow: [
                BoxShadow(
                  color: slide.gradient.last.withValues(alpha: 0.35),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(slide.icon, size: 62, color: Colors.white),
          ),
          const SizedBox(height: 44),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.2,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              height: 1.5,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;

  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 26 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
