import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/friend_repository.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.size = 56, this.icon = Icons.person_rounded});

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.tertiary),
      ),
      child: Icon(icon, size: size * 0.65, color: scheme.tertiary),
    );
  }
}

class PersonTile extends ConsumerWidget {
  const PersonTile({super.key, required this.uid, this.onTap, this.below});

  final String uid;
  final VoidCallback? onTap;
  final Widget? below;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final profile = ref.watch(publicProfileProvider(uid)).value;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            const ProfileAvatar(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile?.nickname ?? '...',
                    style: TextStyle(fontSize: 20, color: scheme.tertiary),
                  ),
                  if (below != null) ...[
                    const SizedBox(height: 6),
                    below!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SmallButton extends StatelessWidget {
  const SmallButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(96, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        backgroundColor: primary ? scheme.primary : scheme.surfaceContainerHighest,
        foregroundColor: primary ? scheme.onPrimary : scheme.onSurfaceVariant,
        textStyle: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      child: Text(label),
    );
  }
}