import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/buttons.dart';

class IntroSlide {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;

  const IntroSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });
}

const List<IntroSlide> kIntroSlides = [
  IntroSlide(
    icon: Icons.home_work_outlined,
    title: 'Welcome to Hissa',
    subtitle:
        'The simplest way for households, roommates and families to track shared expenses together.',
    gradient: [Color(0xFF3B86A5), Color(0xFF005F86)],
  ),
  IntroSlide(
    icon: Icons.receipt_long_outlined,
    title: 'Track every expense',
    subtitle:
        'Add expenses in seconds. Split bills equally, by percentage or by custom amounts — Hissa keeps the math exact.',
    gradient: [Color(0xFFE5853B), Color(0xFFBF5700)],
  ),
  IntroSlide(
    icon: Icons.swap_horiz_rounded,
    title: 'Settle up fairly',
    subtitle:
        'See who owes whom at a glance and record payments with cash, bank transfer, eSewa or Khalti in one tap.',
    gradient: [Color(0xFFF7BD3A), Color(0xFFF2A900)],
  ),
  IntroSlide(
    icon: Icons.donut_small_outlined,
    title: 'Understand your spending',
    subtitle:
        'Monthly insights, category breakdowns and one-tap CSV export keep you on top of where the money goes.',
    gradient: [Color(0xFF5A7F70), Color(0xFF43695B)],
  ),
];

/// First-run feature carousel. Swipable slides introduce the app, with a
/// Skip control and a final "Get Started" CTA.
class IntroScreen extends StatefulWidget {
  final VoidCallback onDone;

  const IntroScreen({super.key, required this.onDone});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  const Icon(
                    Icons.home_work_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
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
                    child: const Text(
                      'Skip',
                      style: TextStyle(fontWeight: FontWeight.w700),
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
                    label: _isLast ? 'Get started' : 'Next',
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

  const _IntroPage({required this.slide});

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
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.2,
              color:
                  isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            slide.subtitle,
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
