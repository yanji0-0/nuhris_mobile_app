import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/app_nav.dart';
import '../providers/account_provider.dart';
import '../theme/app_theme.dart';
import '../utils/initials.dart';

class NuhrisAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const NuhrisAppBar({
    super.key,
    required this.title,
    required this.onNavigate,
    required this.onSignOut,
    this.backgroundColor = const Color(0xFF0A1B66),
    this.foregroundColor = Colors.white,
  });

  final String title;
  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      surfaceTintColor: backgroundColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      scrolledUnderElevation: 0,
      title: Text(title),
      actions: [
        IconButton(
          onPressed: () => onNavigate(AppNavItem.notifications),
          icon: const Icon(Icons.notifications_none_rounded),
          tooltip: 'Notifications',
        ),
        const SizedBox(width: 2),
        _ProfileMenuButton(
          onSignOut: onSignOut,
          foregroundColor: foregroundColor,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _ProfileMenuButton extends ConsumerWidget {
  const _ProfileMenuButton({
    required this.onSignOut,
    required this.foregroundColor,
  });

  final VoidCallback onSignOut;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(accountProvider);
    final profileAsync = ref.watch(profilePhotoProvider);

    return PopupMenuButton<String>(
      tooltip: 'Profile',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 12,
      splashRadius: 24,
      color: Colors.white,
      onSelected: (value) {
        if (value == 'sign_out') {
          onSignOut();
        }
      },
      itemBuilder: (context) {
        final account = accountAsync.maybeWhen(
          data: (value) => value,
          orElse: () => const <String, dynamic>{},
        );
        final user = (account['user'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        final employee =
            (account['employee'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        final firstName = (employee['first_name'] ?? '').toString().trim();
        final lastName = (employee['last_name'] ?? '').toString().trim();
        final fullName = [lastName, firstName]
            .where((part) => part.isNotEmpty)
            .join(', ');
        final displayName = fullName.isNotEmpty
            ? fullName
            : (user['name'] ?? 'Employee').toString();
        final email = (employee['email'] ?? user['email'] ?? '').toString();

        return [
          PopupMenuItem<String>(
            enabled: false,
            height: 74,
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  profileAsync.when(
                    data: (photoUrl) {
                      final hasPhoto =
                          photoUrl != null && photoUrl.trim().isNotEmpty;
                      return CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.nuhrisYellow,
                        backgroundImage: hasPhoto
                            ? NetworkImage(photoUrl.trim())
                            : null,
                        child: !hasPhoto
                            ? Text(
                                twoLetterInitials(
                                  firstName: firstName,
                                  lastName: lastName,
                                  displayName: displayName,
                                ),
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              )
                            : null,
                      );
                    },
                    loading: () => CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.nuhrisYellow,
                      child: const SizedBox.shrink(),
                    ),
                    error: (_, __) => CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.nuhrisYellow,
                      child: Text(
                        twoLetterInitials(
                          firstName: firstName,
                          lastName: lastName,
                          displayName: displayName,
                        ),
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const PopupMenuDivider(height: 1),
          PopupMenuItem<String>(
            value: 'sign_out',
            child: Row(
              children: [
                Icon(Icons.logout_rounded, color: foregroundColor),
                const SizedBox(width: 10),
                const Text(
                  'Sign Out',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ];
      },
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        alignment: Alignment.center,
        child: FutureBuilder<Map<String, dynamic>>(
          future: ref.read(accountProvider.future),
          builder: (context, snap) {
            final account = snap.data ?? const <String, dynamic>{};
            final employee = (account['employee'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
            final firstName = (employee['first_name'] ?? '').toString().trim();
            final lastName = (employee['last_name'] ?? '').toString().trim();
            final displayName = [lastName, firstName].where((p) => p.isNotEmpty).join(', ');
            return Text(
              twoLetterInitials(firstName: firstName, lastName: lastName, displayName: displayName),
              style: TextStyle(color: foregroundColor, fontWeight: FontWeight.w900),
            );
          },
        ),
      ),
    );
  }
}
