import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_powered_coach_2026/core/constants/firestore_collections.dart';
import 'package:ai_powered_coach_2026/core/widgets/app_empty_view.dart';
import 'package:ai_powered_coach_2026/core/widgets/app_error_view.dart';
import 'package:ai_powered_coach_2026/core/widgets/app_loading_view.dart';
import 'package:ai_powered_coach_2026/features/profile/data/profile_photo_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _goalController = TextEditingController();

  late final ProfilePhotoService _photoService;

  bool _isSaving = false;
  bool _isUpdatingPhoto = false;
  bool _seededFromCloud = false;

  @override
  void initState() {
    super.initState();
    _photoService = ProfilePhotoService();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile({required String userId}) async {
    if (_isSaving) {
      return;
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final displayName = _composeDisplayName(
      firstName: firstName,
      lastName: lastName,
    );
    if (firstName.isEmpty || lastName.isEmpty) {
      _showSnack('First name and last name are required.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(userId)
          .set({
            'firstName': firstName,
            'lastName': lastName,
            'displayName': displayName,
            'targetGoal': _goalController.text.trim().isEmpty
                ? 'Improve speaking confidence'
                : _goalController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      _showSnack('Profile updated successfully.');
    } catch (_) {
      _showSnack(
        'Failed to update profile. Check Firestore rules and try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _changeProfilePhoto({
    required String userId,
    required ProfilePhotoSource source,
  }) async {
    if (_isUpdatingPhoto) {
      return;
    }

    setState(() {
      _isUpdatingPhoto = true;
    });

    try {
      final picked = await _photoService.pickPhoto(source: source);
      if (picked == null) {
        _showSnack('No photo selected.');
        return;
      }

      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(userId)
          .set({
            'photoBase64': picked.base64,
            'photoUrl': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      try {
        await FirebaseAuth.instance.currentUser?.updatePhotoURL(null);
      } catch (_) {
        // Keep Firestore as source of truth if Auth profile update fails.
      }

      _showSnack('Profile photo updated.');
    } on ProfilePhotoTooLargeException {
      _showSnack('Image too large. Please choose a smaller photo.');
    } catch (_) {
      _showSnack('Failed to set photo. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingPhoto = false;
        });
      }
    }
  }

  Future<void> _removeProfilePhoto({
    required String userId,
    required bool hasProfilePhoto,
  }) async {
    if (_isUpdatingPhoto) {
      return;
    }
    if (!hasProfilePhoto) {
      _showSnack('No profile photo to remove.');
      return;
    }

    setState(() {
      _isUpdatingPhoto = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(userId)
          .set({
            'photoBase64': FieldValue.delete(),
            'photoUrl': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      try {
        await FirebaseAuth.instance.currentUser?.updatePhotoURL(null);
      } catch (_) {
        // Keep Firestore as source of truth if Auth profile update fails.
      }
      _showSnack('Profile photo removed.');
    } catch (_) {
      _showSnack('Failed to remove photo. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingPhoto = false;
        });
      }
    }
  }

  void _applyCloudValues({required Map<String, dynamic> data}) {
    if (_seededFromCloud) {
      return;
    }

    final firstName = (data['firstName'] as String?)?.trim() ?? '';
    final lastName = (data['lastName'] as String?)?.trim() ?? '';
    final cloudDisplayName = (data['displayName'] as String?)?.trim() ?? '';
    final emailSeed = (data['email'] as String?)?.split('@').first ?? 'Student';

    _firstNameController.text = firstName.isNotEmpty
        ? firstName
        : (cloudDisplayName.isNotEmpty
              ? cloudDisplayName.split(' ').first
              : emailSeed);
    _lastNameController.text = lastName;
    _goalController.text =
        (data['targetGoal'] as String?)?.trim().isNotEmpty == true
        ? (data['targetGoal'] as String)
        : 'Improve speaking confidence';

    _seededFromCloud = true;
  }

  String _composeDisplayName({
    required String firstName,
    required String lastName,
  }) {
    final merged = '$firstName $lastName'.trim();
    return merged.replaceAll(RegExp(r'\s+'), ' ');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: AppEmptyView(
          message: 'Please login to open your profile.',
          icon: Icons.lock_outline_rounded,
        ),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(user.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              context.push('/settings');
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingView(message: 'Loading profile...');
            }
            if (snapshot.hasError) {
              return const AppErrorView(
                message:
                    'Cannot load profile right now. Please try again later.',
              );
            }

            final data = snapshot.data?.data() ?? <String, dynamic>{};
            _applyCloudValues(data: data);

            final firstName = (data['firstName'] as String?)?.trim() ?? '';
            final lastName = (data['lastName'] as String?)?.trim() ?? '';
            final displayName = (data['displayName'] as String?)?.trim() ?? '';
            final email =
                (data['email'] as String?) ?? (user.email ?? 'No email');
            final photoBase64 = (data['photoBase64'] as String?)?.trim() ?? '';
            final photoUrl =
                (data['photoUrl'] as String?)?.trim() ?? (user.photoURL ?? '');
            final hasProfilePhoto =
                photoBase64.isNotEmpty || photoUrl.isNotEmpty;
            final role = (data['role'] as String?) ?? 'user';
            final totalSessions = (data['totalSessions'] as num?)?.toInt() ?? 0;
            final avgScore = (data['avgScore'] as num?)?.toDouble() ?? 0;
            final currentStreak = (data['currentStreak'] as num?)?.toInt() ?? 0;
            final bestStreak = (data['bestStreak'] as num?)?.toInt() ?? 0;
            final skillInsight = _inferSkillLevelInsight(
              avgScore: avgScore,
              totalSessions: totalSessions,
              bestStreak: bestStreak,
            );

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1F86D8), Color(0xFF52ACEF)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile Summary',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _ProfilePhotoAvatar(
                            photoBase64: photoBase64,
                            photoUrl: photoUrl,
                            firstName: firstName,
                            lastName: lastName,
                            displayName: displayName,
                            size: 72,
                            borderColor: Colors.white.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  email,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.95,
                                        ),
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Role: ${_roleLabel(role)}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ProfileMetricCard(
                              label: 'Sessions',
                              value: '$totalSessions',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ProfileMetricCard(
                              label: 'Avg Score',
                              value: avgScore.toStringAsFixed(1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _ProfileMetricCard(
                              label: 'Current Streak',
                              value: '$currentStreak days',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ProfileMetricCard(
                              label: 'Best Streak',
                              value: '$bestStreak days',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isUpdatingPhoto
                                ? null
                                : () {
                                    _changeProfilePhoto(
                                      userId: user.uid,
                                      source: ProfilePhotoSource.gallery,
                                    );
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            icon: _isUpdatingPhoto
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.photo_library_outlined),
                            label: Text(
                              _isUpdatingPhoto ? 'Uploading...' : 'Gallery',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isUpdatingPhoto
                                ? null
                                : () {
                                    _changeProfilePhoto(
                                      userId: user.uid,
                                      source: ProfilePhotoSource.camera,
                                    );
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Camera'),
                          ),
                          if (hasProfilePhoto)
                            TextButton.icon(
                              onPressed: _isUpdatingPhoto
                                  ? null
                                  : () {
                                      _removeProfilePhoto(
                                        userId: user.uid,
                                        hasProfilePhoto: hasProfilePhoto,
                                      );
                                    },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Remove'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 420;
                    if (compact) {
                      return Column(
                        children: [
                          TextField(
                            controller: _firstNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'First Name',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _lastNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Last Name',
                              prefixIcon: Icon(Icons.badge_rounded),
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'First Name',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _lastNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Last Name',
                              prefixIcon: Icon(Icons.badge_rounded),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _goalController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Target Goal',
                    hintText: 'Example: Improve interview speaking confidence',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1A2430)
                        : const Color(0xFFF8FCFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF365068)
                          : const Color(0xFFC7DFF3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.psychology_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Skill Level (AI)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              skillInsight.level,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  skillInsight.reason,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5B7892),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Metrics: Avg ${avgScore.toStringAsFixed(1)} | Sessions $totalSessions | Best streak $bestStreak days',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5B7892),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () {
                            _saveProfile(userId: user.uid);
                          },
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Saving...' : 'Save Profile'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  _SkillLevelInsight _inferSkillLevelInsight({
    required double avgScore,
    required int totalSessions,
    required int bestStreak,
  }) {
    if (totalSessions >= 12 && avgScore >= 82 && bestStreak >= 5) {
      return const _SkillLevelInsight(
        level: 'Advanced',
        reason:
            'AI rule matched: sessions >= 12, avg score >= 82, and best streak >= 5.',
      );
    }

    if (totalSessions >= 4 && avgScore >= 68) {
      return const _SkillLevelInsight(
        level: 'Intermediate',
        reason: 'AI rule matched: sessions >= 4 and avg score >= 68.',
      );
    }

    return const _SkillLevelInsight(
      level: 'Beginner',
      reason:
          'AI rule matched: still building baseline consistency and score trend.',
    );
  }
}

class _SkillLevelInsight {
  const _SkillLevelInsight({required this.level, required this.reason});

  final String level;
  final String reason;
}

String _roleLabel(String role) {
  switch (role.trim().toLowerCase()) {
    case 'admin':
      return 'Admin';
    case 'developer':
      return 'Developer';
    default:
      return 'User';
  }
}

class _ProfilePhotoAvatar extends StatelessWidget {
  const _ProfilePhotoAvatar({
    required this.photoBase64,
    required this.photoUrl,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.size,
    required this.borderColor,
  });

  final String photoBase64;
  final String photoUrl;
  final String firstName;
  final String lastName;
  final String displayName;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final initials = _buildInitials(
      firstName: firstName,
      lastName: lastName,
      displayName: displayName,
    );
    final memoryBytes = _decodeBase64(photoBase64);
    final resolvedImage = photoUrl.trim();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor),
      ),
      child: ClipOval(
        child: memoryBytes != null
            ? Image.memory(
                memoryBytes,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _AvatarFallback(initials: initials, size: size),
              )
            : resolvedImage.isNotEmpty
            ? Image.network(
                resolvedImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _AvatarFallback(initials: initials, size: size),
              )
            : _AvatarFallback(initials: initials, size: size),
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

  String _buildInitials({
    required String firstName,
    required String lastName,
    required String displayName,
  }) {
    final first = firstName.trim();
    final last = lastName.trim();
    if (first.isNotEmpty || last.isNotEmpty) {
      final firstInitial = first.isNotEmpty ? first[0] : '';
      final lastInitial = last.isNotEmpty ? last[0] : '';
      return (firstInitial + lastInitial).toUpperCase();
    }

    final parts = displayName
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'U';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2A91DE),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.32,
        ),
      ),
    );
  }
}

class _ProfileMetricCard extends StatelessWidget {
  const _ProfileMetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
