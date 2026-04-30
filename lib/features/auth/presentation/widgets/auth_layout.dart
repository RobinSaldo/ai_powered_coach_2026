import 'package:flutter/material.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.form,
    required this.footerText,
    required this.footerActionText,
    required this.onFooterTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget form;
  final String footerText;
  final String footerActionText;
  final VoidCallback? onFooterTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark
        ? const Color(0xFFEFF2FF)
        : const Color(0xFF23275B);
    final subtitleColor = isDark
        ? const Color(0xFFB8C1F0)
        : const Color(0xFF656A92);
    final iconContainerColor = isDark
        ? const Color(0xFF151D4D)
        : const Color(0xFFF1EEFF);
    final iconBorderColor = isDark
        ? const Color(0xFF4F59A5)
        : const Color(0xFFC8C0FF);
    final iconColor = isDark
        ? const Color(0xFF9EC9FF)
        : const Color(0xFF5A53D2);
    final formBgColor = isDark
        ? const Color(0xCC0E1741)
        : Colors.white.withValues(alpha: 0.94);
    final formBorderColor = isDark
        ? const Color(0xFF3F4B96)
        : const Color(0xFFD7D1FF);
    final footerColor = isDark
        ? const Color(0xFFAEB5E9)
        : const Color(0xFF5E648E);

    return Scaffold(
      body: Stack(
        children: [
          _AuthBackground(isDark: isDark),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: iconContainerColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: iconBorderColor,
                            width: 1.3,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stackTrace) {
                              return Icon(icon, color: iconColor, size: 34);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: headerColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: textTheme.bodyMedium?.copyWith(
                          color: subtitleColor,
                          height: 1.45,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: formBgColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: formBorderColor,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? const Color(0x36000000)
                                  : const Color(0x14398BD3),
                              blurRadius: 26,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: form,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 2,
                        children: [
                          Text(
                            footerText,
                            style: textTheme.bodyMedium?.copyWith(
                              color: footerColor,
                            ),
                          ),
                          TextButton(
                            onPressed: onFooterTap,
                            child: Text(footerActionText),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF060B24), Color(0xFF0E1640), Color(0xFF162156)]
              : const [Color(0xFFFFFFFF), Color(0xFFF5F2FF), Color(0xFFF4F7FF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -70,
            child: _GlowBubble(
              size: 220,
              color: isDark ? const Color(0x334D6BFF) : const Color(0x665A8CFF),
            ),
          ),
          Positioned(
            top: 170,
            right: -62,
            child: _GlowBubble(
              size: 180,
              color: isDark ? const Color(0x2EA16CFF) : const Color(0x4D8A67FF),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -40,
            child: _GlowBubble(
              size: 250,
              color: isDark ? const Color(0x266B4DFF) : const Color(0x4D6B5CFF),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBubble extends StatelessWidget {
  const _GlowBubble({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.05)],
        ),
      ),
    );
  }
}
