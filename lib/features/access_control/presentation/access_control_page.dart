import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:ai_powered_coach_2026/core/constants/firestore_collections.dart';
import 'package:ai_powered_coach_2026/core/widgets/app_empty_view.dart';
import 'package:ai_powered_coach_2026/core/widgets/app_error_view.dart';
import 'package:ai_powered_coach_2026/core/widgets/app_loading_view.dart';

class AccessControlPage extends StatelessWidget {
  const AccessControlPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: AppEmptyView(
          message: 'Please login to access role management.',
          icon: Icons.lock_outline_rounded,
        ),
      );
    }

    final currentUserStream = FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(user.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Access Control')),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: currentUserStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingView(message: 'Loading access level...');
            }
            if (snapshot.hasError) {
              return const AppErrorView(
                message: 'Cannot load access settings right now.',
              );
            }

            final data = snapshot.data?.data() ?? <String, dynamic>{};
            final currentRole = _normalizeRole(data['role'] as String?);
            final isPrivileged =
                currentRole == 'admin' || currentRole == 'developer';

            if (!isPrivileged) {
              return const AppEmptyView(
                message:
                    'You do not have permission to open this page.\nRequired role: admin or developer.',
                icon: Icons.shield_outlined,
              );
            }

            return _AccessControlContent(
              currentUserId: user.uid,
              currentRole: currentRole,
            );
          },
        ),
      ),
    );
  }
}

class _AccessControlContent extends StatefulWidget {
  const _AccessControlContent({
    required this.currentUserId,
    required this.currentRole,
  });

  final String currentUserId;
  final String currentRole;

  @override
  State<_AccessControlContent> createState() => _AccessControlContentState();
}

class _AccessControlContentState extends State<_AccessControlContent> {
  final Set<String> _updatingUserIds = <String>{};
  static const _roles = ['user', 'admin', 'developer'];

  Future<void> _updateRole({
    required String targetUserId,
    required String role,
  }) async {
    if (_updatingUserIds.contains(targetUserId)) {
      return;
    }

    setState(() {
      _updatingUserIds.add(targetUserId);
    });

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(targetUserId)
          .set({
            'role': role,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role updated to "${_roleLabel(role)}".')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to update role. Check Firestore rules and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingUserIds.remove(targetUserId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersStream = FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .limit(100)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: usersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingView(message: 'Loading users...');
        }
        if (snapshot.hasError) {
          return const AppErrorView(
            message: 'Cannot load user accounts right now.',
          );
        }

        final docs =
            snapshot.data?.docs ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        if (docs.isEmpty) {
          return const AppEmptyView(
            message: 'No user records found yet.',
            icon: Icons.group_off_outlined,
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF7FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFC7E0F8)),
              ),
              child: Text(
                'Signed in as ${_roleLabel(widget.currentRole)}.\nUse this page to assign roles for testing (user/admin/developer).',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF1E4F77),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...docs.map((doc) {
              final data = doc.data();
              final firstName = (data['firstName'] as String? ?? '').trim();
              final lastName = (data['lastName'] as String? ?? '').trim();
              final displayName = (data['displayName'] as String? ?? '').trim();
              final email = (data['email'] as String? ?? 'No email').trim();
              final role = _normalizeRole(data['role'] as String?);
              final isCurrentUser = doc.id == widget.currentUserId;
              final isUpdating = _updatingUserIds.contains(doc.id);

              final resolvedName = _resolveName(
                firstName: firstName,
                lastName: lastName,
                displayName: displayName,
                email: email,
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resolvedName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFF123B5C),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF5A748D),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('${doc.id}-$role'),
                              initialValue: role,
                              items: _roles
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item,
                                      child: Text(_roleLabel(item)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (isCurrentUser || isUpdating)
                                  ? null
                                  : (value) {
                                      if (value == null || value == role) {
                                        return;
                                      }
                                      _updateRole(
                                        targetUserId: doc.id,
                                        role: value,
                                      );
                                    },
                              decoration: const InputDecoration(
                                labelText: 'Access Role',
                                prefixIcon: Icon(
                                  Icons.admin_panel_settings_outlined,
                                ),
                              ),
                            ),
                          ),
                          if (isUpdating) ...[
                            const SizedBox(width: 10),
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        ],
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Current account role is locked here to avoid accidental lockout.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFF6F7D8A)),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  String _resolveName({
    required String firstName,
    required String lastName,
    required String displayName,
    required String email,
  }) {
    final merged = '$firstName $lastName'.trim();
    if (merged.isNotEmpty) {
      return merged;
    }
    if (displayName.isNotEmpty) {
      return displayName;
    }
    return email.split('@').first;
  }
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
