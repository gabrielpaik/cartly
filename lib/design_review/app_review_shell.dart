import 'package:flutter/material.dart';

ThemeData buildWimcReviewTheme() {
  return ThemeData(
    fontFamily: 'Pretendard',
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE31837)),
    scaffoldBackgroundColor: Colors.white,
  );
}

class ReviewSurface extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final bool readOnly;
  final double maxWidth;

  const ReviewSurface({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.readOnly = false,
    this.maxWidth = 480,
  });

  @override
  Widget build(BuildContext context) {
    final content = Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        ),
      ),
    );

    if (!readOnly) return content;
    return ReadOnlyPreview(child: content);
  }
}

class ReadOnlyPreview extends StatelessWidget {
  final Widget child;
  final String label;

  const ReadOnlyPreview({
    super.key,
    required this.child,
    this.label = 'READ-ONLY PREVIEW',
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(child: child),
        Positioned(
          top: 12,
          right: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
