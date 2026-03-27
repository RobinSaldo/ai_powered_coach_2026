import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_powered_coach_2026/core/constants/firestore_collections.dart';
import 'package:ai_powered_coach_2026/core/widgets/app_empty_view.dart';
import 'package:ai_powered_coach_2026/core/widgets/app_error_view.dart';
import 'package:ai_powered_coach_2026/core/widgets/app_loading_view.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _displayNameController = TextEditingController();
  final _goalController = TextEditingController();

  bool _isSaving = false;
  bool _seededFromCloud = false;
  int _dropdownResetVersion = 0;
  String _selectedSkillLevel = 'Beginner';

  static const _skillLevels = ['Beginner', 'Intermediate', 'Advanced'];

  @override
  void dispose() {
    _displayNameController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile({required String userId}) async {
    if (_isSaving) {
      return;
    }

    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      _showSnack('Display name is required.');
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
            'displayName': displayName,
            'targetGoal': _goalController.text.trim().isEmpty
                ? 'Improve speaking confidence'
                : _goalController.text.trim(),
            'skillLevel': _selectedSkillLevel,
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

  void _applyCloudValues({required Map<String, dynamic> data}) {
    if (_seededFromCloud) {
      return;
    }

    _displayNameController.text =
        (data['displayName'] as String?)?.trim().isNotEmpty == true
        ? (data['displayName'] as String)
        : 'Student';
    _goalController.text =
        (data['targetGoal'] as String?)?.trim().isNotEmpty == true
        ? (data['targetGoal'] as String)
        : 'Improve speaking confidence';

    final cloudSkill = (data['skillLevel'] as String?) ?? 'Beginner';
    if (_skillLevels.contains(cloudSkill)) {
      _selectedSkillLevel = cloudSkill;
    }
    _dropdownResetVersion++;
    _seededFromCloud = true;
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

            final email =
                (data['email'] as String?) ?? (user.email ?? 'No email');
            final totalSessions = (data['totalSessions'] as num?)?.toInt() ?? 0;
            final avgScore = (data['avgScore'] as num?)?.toDouble() ?? 0;

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
                      Text(
                        email,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
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
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
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
                DropdownButtonFormField<String>(
                  key: ValueKey('skill-level-$_dropdownResetVersion'),
                  initialValue: _selectedSkillLevel,
                  items: _skillLevels
                      .map(
                        (level) =>
                            DropdownMenuItem(value: level, child: Text(level)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedSkillLevel = value;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Skill Level',
                    prefixIcon: Icon(Icons.trending_up_rounded),
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
