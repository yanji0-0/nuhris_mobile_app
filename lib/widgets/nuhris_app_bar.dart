import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/app_nav.dart';
import '../providers/account_provider.dart';
import '../theme/app_theme.dart';
import '../utils/employee_initials.dart';

enum _AccountMenuAction { account, signOut }

class NuhrisAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const NuhrisAppBar({
    super.key,
    required this.title,
    required this.currentItem,
    required this.onNavigate,
    required this.onSignOut,
    this.showNotifications = true,
    this.backgroundColor = AppColors.appBarNavy,
    this.foregroundColor = Colors.white,
  });

  final String title;
  final AppNavItem currentItem;
  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;
  final bool showNotifications;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(accountProvider);
    final profileAsync = ref.watch(profilePhotoProvider);
    final initials = accountAsync.maybeWhen(
      data: employeeInitialsFromAccount,
      orElse: () => 'E',
    );

    return AppBar(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      surfaceTintColor: backgroundColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      scrolledUnderElevation: 0,
      title: Text(title),
      actions: [
        if (showNotifications)
          IconButton(
            onPressed: () => onNavigate(AppNavItem.notifications),
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifications',
          ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: PopupMenuButton<_AccountMenuAction>(
            tooltip: 'Account',
            color: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            position: PopupMenuPosition.under,
            offset: const Offset(0, 8),
            constraints: const BoxConstraints(minWidth: 172),
            onSelected: (action) {
              switch (action) {
                case _AccountMenuAction.account:
                  if (currentItem != AppNavItem.account) {
                    onNavigate(AppNavItem.account);
                  }
                  break;
                case _AccountMenuAction.signOut:
                  onSignOut();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<_AccountMenuAction>(
                value: _AccountMenuAction.account,
                enabled: currentItem != AppNavItem.account,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 18,
                      color: currentItem == AppNavItem.account
                          ? const Color(0xFF94A3B8)
                          : AppColors.appBarNavy,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Account',
                      style: TextStyle(
                        color: currentItem == AppNavItem.account
                            ? const Color(0xFF94A3B8)
                            : AppColors.appBarNavy,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem<_AccountMenuAction>(
                value: _AccountMenuAction.signOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: Color(0xFFC24141),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Color(0xFFC24141),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            child: _AppBarAvatar(
              initials: initials,
              profileAsync: profileAsync,
              foregroundColor: foregroundColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _AppBarAvatar extends StatelessWidget {
  const _AppBarAvatar({
    required this.initials,
    required this.profileAsync,
    required this.foregroundColor,
  });

  final String initials;
  final AsyncValue<String?> profileAsync;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final photoUrl = profileAsync.maybeWhen(
      data: (url) => url,
      orElse: () => null,
    );
    final hasPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.employeeAvatarBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1,
        ),
        image: hasPhoto
            ? DecorationImage(
                image: NetworkImage(photoUrl.trim()),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: hasPhoto
          ? null
          : Text(
              initials,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
    );
  }
}
