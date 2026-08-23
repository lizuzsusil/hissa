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
    gradient: [AppColors.primaryBright, AppColors.primary],
  ),
  IntroSlide(
    icon: Icons.receipt_long_outlined,
    gradient: [AppColors.secondary, AppColors.secondaryDark],
  ),
  IntroSlide(
    icon: Icons.swap_horiz_rounded,
    gradient: [Color(0xFFF8CC4A), AppColors.accent],
  ),
  IntroSlide(
    icon: Icons.donut_small_outlined,
    gradient: [AppColors.positive, Color(0xFF158A4F)],
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
    _controller.nextPage(duration: AppMotion.medium, curve: AppMotion.ease);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
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
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Hissa',
                    style: AppText.displayM.copyWith(
                      fontSize: 20,
                      letterSpacing: -0.3,
                      color: p.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  GhostButton(
                    label: l10n.skip,
                    onPressed: widget.onDone,
                    foreground: p.textSecondary,
                    expanded: false,
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: Column(
                children: [
                  _Dots(count: kIntroSlides.length, index: _index),
                  const SizedBox(height: AppSpacing.xl),
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
    final p = context.palette;
    final accent = slide.gradient.last;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              gradient: AppGradients.tint(accent, alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: accent.withValues(alpha: 0.16)),
            ),
            child: Icon(slide.icon, size: 60, color: accent),
          ),
          const SizedBox(height: AppSpacing.xxxl + AppSpacing.xs),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.displayM.copyWith(
              letterSpacing: -0.6,
              height: 1.2,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg - 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppText.bodyL.copyWith(
              height: 1.5,
              color: p.textSecondary,
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
    final p = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppMotion.medium,
            curve: AppMotion.ease,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            width: i == index ? 26 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? AppColors.primary : p.borderStrong,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }
}
