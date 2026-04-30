import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_powered_coach_2026/core/constants/firestore_collections.dart';
import 'package:ai_powered_coach_2026/core/theme/theme_mode_controller.dart';
import 'package:ai_powered_coach_2026/core/widgets/app_empty_view.dart';
import 'package:ai_powered_coach_2026/core/widgets/app_error_view.dart';
import 'package:ai_powered_coach_2026/core/widgets/app_loading_view.dart';
import 'package:ai_powered_coach_2026/services/notifications/practice_reminder_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isSaving = false;
  bool _isResettingRecommendations = false;
  bool _isSendingTestReminder = false;
  final Map<String, dynamic> _pendingSettings = {};

  Future<void> _updateSetting({
    required String userId,
    required String key,
    required dynamic value,
    required dynamic previousValue,
    Future<void> Function()? onSaved,
    String? failureMessage,
  }) async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _pendingSettings[key] = value;
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(userId)
          .set({
            'settings.$key': value,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      if (onSaved != null) {
        await onSaved();
      }
    } catch (error) {
      debugPrint('Failed to update setting "$key": $error');
      if (mounted) {
        setState(() {
          _pendingSettings[key] = previousValue;
        });
      }
      _showSnack(
        failureMessage ?? 'Failed to update setting. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _restoreCompletedRecommendations({
    required String userId,
  }) async {
    if (_isResettingRecommendations) {
      return;
    }

    setState(() {
      _isResettingRecommendations = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.recommendations)
          .where('userId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        _showSnack('No completed recommendations to restore.');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.set(doc.reference, {
          'isCompleted': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
      _showSnack('Completed recommendations restored.');
    } catch (_) {
      _showSnack('Failed to restore recommendations.');
    } finally {
      if (mounted) {
        setState(() {
          _isResettingRecommendations = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendTestReminder({
    required String preferredSessionLength,
  }) async {
    if (_isSendingTestReminder) {
      return;
    }

    setState(() {
      _isSendingTestReminder = true;
    });

    try {
      await PracticeReminderService.showTestReminder(
        preferredSessionLength: preferredSessionLength,
      );
      _showSnack('Test reminder sent. Check your notification tray.');
    } catch (_) {
      _showSnack(
        'Could not send test reminder. Allow notifications and try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingTestReminder = false;
        });
      }
    }
  }

  T _resolveSetting<T>({
    required Map<String, dynamic> cloudSettings,
    required String key,
    required T fallback,
  }) {
    if (_pendingSettings.containsKey(key)) {
      return _pendingSettings[key] as T;
    }
    final cloudValue = cloudSettings[key];
    if (cloudValue is T) {
      return cloudValue;
    }
    return fallback;
  }

  void _reconcilePendingSettings(Map<String, dynamic> cloudSettings) {
    if (_pendingSettings.isEmpty) {
      return;
    }

    final keysToRemove = <String>[];
    _pendingSettings.forEach((key, pendingValue) {
      if (cloudSettings.containsKey(key) &&
          cloudSettings[key] == pendingValue) {
        keysToRemove.add(key);
      }
    });

    if (keysToRemove.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        for (final key in keysToRemove) {
          _pendingSettings.remove(key);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeControllerProvider);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: AppEmptyView(
          message: 'Please login to open settings.',
          icon: Icons.lock_outline_rounded,
        ),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(user.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingView(message: 'Loading settings...');
            }
            if (snapshot.hasError) {
              return const AppErrorView(
                message: 'Cannot load settings right now. Please try again.',
              );
            }

            final data = snapshot.data?.data() ?? <String, dynamic>{};
            final rawSettings = data['settings'];
            final settings = rawSettings is Map
                ? rawSettings.cast<String, dynamic>()
                : <String, dynamic>{};
            _reconcilePendingSettings(settings);

            final autoSaveSessions = _resolveSetting<bool>(
              cloudSettings: settings,
              key: 'autoSaveSessions',
              fallback: true,
            );
            final showLiveTranscript = _resolveSetting<bool>(
              cloudSettings: settings,
              key: 'showLiveTranscript',
              fallback: true,
            );
            final practiceReminders = _resolveSetting<bool>(
              cloudSettings: settings,
              key: 'practiceReminders',
              fallback: true,
            );
            final sessionLength = _resolveSetting<String>(
              cloudSettings: settings,
              key: 'preferredSessionLength',
              fallback: '3 min',
            );

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SettingsCard(
                  title: 'Practice Settings',
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        value: autoSaveSessions,
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                _updateSetting(
                                  userId: user.uid,
                                  key: 'autoSaveSessions',
                                  value: value,
                                  previousValue: autoSaveSessions,
                                );
                              },
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Auto-save speaking sessions'),
                        subtitle: const Text(
                          'Automatically save session analysis to your account.',
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        value: showLiveTranscript,
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                _updateSetting(
                                  userId: user.uid,
                                  key: 'showLiveTranscript',
                                  value: value,
                                  previousValue: showLiveTranscript,
                                );
                              },
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show live transcript'),
                        subtitle: const Text(
                          'Display real-time speech transcript during recording.',
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        value: practiceReminders,
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                _updateSetting(
                                  userId: user.uid,
                                  key: 'practiceReminders',
                                  value: value,
                                  previousValue: practiceReminders,
                                  onSaved: () async {
                                    await PracticeReminderService.syncReminder(
                                      enabled: value,
                                      preferredSessionLength: sessionLength,
                                    );
                                  },
                                  failureMessage: value
                                      ? 'Could not enable reminders. Allow notifications and try again.'
                                      : null,
                                );
                              },
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable practice reminders'),
                        subtitle: const Text(
                          'Receive reminders for your speaking practice goals.',
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        key: ValueKey('session-length-$sessionLength'),
                        initialValue: sessionLength,
                        items: const [
                          DropdownMenuItem(
                            value: '1 min',
                            child: Text('1 minute'),
                          ),
                          DropdownMenuItem(
                            value: '3 min',
                            child: Text('3 minutes'),
                          ),
                          DropdownMenuItem(
                            value: '5 min',
                            child: Text('5 minutes'),
                          ),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                if (value == null) return;
                                _updateSetting(
                                  userId: user.uid,
                                  key: 'preferredSessionLength',
                                  value: value,
                                  previousValue: sessionLength,
                                  onSaved: () async {
                                    if (!practiceReminders) {
                                      return;
                                    }
                                    await PracticeReminderService.syncReminder(
                                      enabled: true,
                                      preferredSessionLength: value,
                                    );
                                  },
                                );
                              },
                        decoration: const InputDecoration(
                          labelText: 'Preferred Session Length',
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isSendingTestReminder
                              ? null
                              : () {
                                  _sendTestReminder(
                                    preferredSessionLength: sessionLength,
                                  );
                                },
                          icon: _isSendingTestReminder
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.notifications_active_outlined),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _isSendingTestReminder
                                  ? 'Sending test reminder...'
                                  : 'Test Reminder Now',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SettingsCard(
                  title: 'Appearance',
                  child: DropdownButtonFormField<String>(
                    initialValue: themeModeToStorageValue(themeMode),
                    items: const [
                      DropdownMenuItem(value: 'system', child: Text('System')),
                      DropdownMenuItem(value: 'light', child: Text('Light')),
                      DropdownMenuItem(value: 'dark', child: Text('Dark')),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      final nextThemeMode = themeModeFromStorageValue(value);
                      ref
                          .read(themeModeControllerProvider.notifier)
                          .setThemeMode(nextThemeMode);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Theme Mode',
                      prefixIcon: Icon(Icons.dark_mode_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _SettingsCard(
                  title: 'Recommendation Controls',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Restore completed recommendations if you want to review them again.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF56728C),
                        ),
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compactButton = constraints.maxWidth < 340;
                          final labelText = _isResettingRecommendations
                              ? 'Restoring...'
                              : compactButton
                              ? 'Restore Recommendations'
                              : 'Restore Completed Recommendations';

                          return OutlinedButton.icon(
                            onPressed: _isResettingRecommendations
                                ? null
                                : () {
                                    _restoreCompletedRecommendations(
                                      userId: user.uid,
                                    );
                                  },
                            icon: _isResettingRecommendations
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.restart_alt_rounded),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(labelText),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SettingsCard(
                  title: 'Account',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        user.email ?? 'No email',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFF123B5C),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Logout'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SettingsCard(
                  title: 'App Info',
                  child: Text(
                    'AI Powered Coach\nVersion 1.0.0\n\nBuilt for capstone project focused on speaking and communication improvement.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF56728C),
                      height: 1.45,
                    ),
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2430) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF33475B) : const Color(0xFFD2E6F9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: isDark ? const Color(0xFFEAF3FF) : const Color(0xFF123B5C),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
