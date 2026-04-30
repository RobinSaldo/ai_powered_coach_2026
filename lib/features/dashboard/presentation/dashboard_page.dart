import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_powered_coach_2026/core/widgets/app_error_view.dart';
import 'package:ai_powered_coach_2026/core/widgets/app_loading_view.dart';
import 'package:ai_powered_coach_2026/features/profile/data/user_profile_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Powered Coach'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              context.push('/settings');
            },
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: () {
              context.push('/profile');
            },
            icon: const Icon(Icons.person_outline_rounded),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) => _DashboardContent(profile: profile),
        loading: () =>
            const AppLoadingView(message: 'Loading your dashboard...'),
        error: (_, _) => const AppErrorView(
          message: 'Failed to load profile. Please refresh the app.',
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.profile});

  final Map<String, dynamic>? profile;

  @override
  Widget build(BuildContext context) {
    final name = _extractName(profile);
    final firstName = (profile?['firstName'] as String?)?.trim() ?? '';
    final lastName = (profile?['lastName'] as String?)?.trim() ?? '';
    final email = (profile?['email'] as String?) ?? 'No email found';
    final photoBase64 = (profile?['photoBase64'] as String?)?.trim() ?? '';
    final photoUrl = (profile?['photoUrl'] as String?)?.trim() ?? '';
    final role = _normalizeRole(profile?['role'] as String?);
    final skillLevel = (profile?['skillLevel'] as String?) ?? 'Beginner';
    final totalSessions = (profile?['totalSessions'] as num?)?.toInt() ?? 0;
    final currentStreak = (profile?['currentStreak'] as num?)?.toInt() ?? 0;
    final bestStreak = (profile?['bestStreak'] as num?)?.toInt() ?? 0;
    final averageScore = (profile?['avgScore'] as num?)?.toInt() ?? 0;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final horizontalPadding = isWide ? 40.0 : 20.0;
          final miniCardAspectRatio = constraints.maxWidth < 420 ? 1.2 : 1.5;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              18,
              horizontalPadding,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WelcomeHeader(
                  name: name,
                  email: email,
                  role: role,
                  photoBase64: photoBase64,
                  photoUrl: photoUrl,
                  firstName: firstName,
                  lastName: lastName,
                ),
                const SizedBox(height: 18),
                _MainStatCard(
                  averageScore: averageScore,
                  skillLevel: skillLevel,
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: isWide ? 3 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: miniCardAspectRatio,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _MiniStatCard(
                      title: 'Total Sessions',
                      value: '$totalSessions',
                      icon: Icons.mic_rounded,
                    ),
                    _MiniStatCard(
                      title: 'Current Streak',
                      value: '$currentStreak days',
                      icon: Icons.local_fire_department_rounded,
                    ),
                    _MiniStatCard(
                      title: 'Best Streak',
                      value: '$bestStreak days',
                      icon: Icons.workspace_premium_rounded,
                    ),
                    _MiniStatCard(
                      title: 'Skill Level',
                      value: skillLevel,
                      icon: Icons.trending_up_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF103A5C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.menu_book_rounded,
                  title: 'Practice Session (Word-by-Word)',
                  subtitle:
                      'Read guided scripts and light each word only when matched.',
                  badge: 'New',
                  onTap: () {
                    context.push('/practice-session');
                  },
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.graphic_eq_rounded,
                  title: 'Start Speaking Session',
                  subtitle: 'Record speech and get AI-powered feedback.',
                  badge: 'Next',
                  onTap: () {
                    context.push('/recording');
                  },
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.timeline_rounded,
                  title: 'View Progress Tracking',
                  subtitle: 'See your weekly trends and improvement curve.',
                  badge: 'Live',
                  onTap: () {
                    context.push('/progress');
                  },
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Personalized Recommendations',
                  subtitle:
                      'Get custom speaking exercises based on weak points.',
                  badge: 'Live',
                  onTap: () {
                    context.push('/recommendations');
                  },
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.account_circle_outlined,
                  title: 'Edit User Profile',
                  subtitle:
                      'Update your name and goal, and review AI skill level.',
                  badge: 'Live',
                  onTap: () {
                    context.push('/profile');
                  },
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.settings_suggest_outlined,
                  title: 'App Settings',
                  subtitle: 'Configure practice options and account controls.',
                  badge: 'Live',
                  onTap: () {
                    context.push('/settings');
                  },
                ),
                if (role != 'user') ...[
                  const SizedBox(height: 12),
                  _ActionCard(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Access Control',
                    subtitle:
                        'Assign and verify account roles for user/admin/developer testing.',
                    badge: role == 'developer' ? 'DEV' : 'ADMIN',
                    onTap: () {
                      context.push('/access-control');
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _extractName(Map<String, dynamic>? profile) {
    final firstName = (profile?['firstName'] as String?)?.trim() ?? '';
    final lastName = (profile?['lastName'] as String?)?.trim() ?? '';
    final fullName = '$firstName $lastName'.trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }

    final displayName = (profile?['displayName'] as String?)?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    return 'Student';
  }

  String _normalizeRole(String? role) {
    switch ((role ?? '').trim().toLowerCase()) {
      case 'admin':
        return 'admin';
      case 'developer':
        return 'developer';
      default:
        return 'user';
    }
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({
    required this.name,
    required this.email,
    required this.role,
    required this.photoBase64,
    required this.photoUrl,
    required this.firstName,
    required this.lastName,
  });

  final String name;
  final String email;
  final String role;
  final String photoBase64;
  final String photoUrl;
  final String firstName;
  final String lastName;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashboardAvatar(
          name: name,
          firstName: firstName,
          lastName: lastName,
          photoBase64: photoBase64,
          photoUrl: photoUrl,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, $name',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF123B5C),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF4E6982)),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F3FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Role: ${_roleLabel(role)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF1B5F95),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'developer':
        return 'Developer';
      default:
        return 'User';
    }
  }
}

class _DashboardAvatar extends StatelessWidget {
  const _DashboardAvatar({
    required this.name,
    required this.firstName,
    required this.lastName,
    required this.photoBase64,
    required this.photoUrl,
  });

  final String name;
  final String firstName;
  final String lastName;
  final String photoBase64;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final initials = _resolveInitials();
    final memoryBytes = _decodeBase64(photoBase64);
    final resolvedImage = photoUrl.trim();

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFB7D6EF)),
      ),
      child: ClipOval(
        child: memoryBytes != null
            ? Image.memory(
                memoryBytes,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _DashboardAvatarFallback(initials: initials),
              )
            : resolvedImage.isNotEmpty
            ? Image.network(
                resolvedImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _DashboardAvatarFallback(initials: initials),
              )
            : _DashboardAvatarFallback(initials: initials),
      ),
    );
  }

  Uint8List? _decodeBase64(String input) {
    final raw = input.trim();
    if (raw.isEmpty) {
      return null;
    }

    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  String _resolveInitials() {
    final first = firstName.trim();
    final last = lastName.trim();
    if (first.isNotEmpty || last.isNotEmpty) {
      final firstInitial = first.isNotEmpty ? first[0] : '';
      final lastInitial = last.isNotEmpty ? last[0] : '';
      return (firstInitial + lastInitial).toUpperCase();
    }

    final pieces = name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (pieces.isEmpty) {
      return 'U';
    }
    if (pieces.length == 1) {
      return pieces.first[0].toUpperCase();
    }
    return '${pieces[0][0]}${pieces[1][0]}'.toUpperCase();
  }
}

class _DashboardAvatarFallback extends StatelessWidget {
  const _DashboardAvatarFallback({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2A91DE),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MainStatCard extends StatelessWidget {
  const _MainStatCard({required this.averageScore, required this.skillLevel});

  final int averageScore;
  final String skillLevel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2088DA), Color(0xFF4AA4EC)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24338DD4),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Average Score',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$averageScore / 100',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Level: $skillLevel',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCFE3F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1F78BE)),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF4E6982),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF113857),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD3E8FB)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F3FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF1A6FAF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF143A58),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF55728D),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F5FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Color(0xFF1C6CA9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
