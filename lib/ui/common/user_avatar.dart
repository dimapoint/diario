import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';

/// Avatar de la cuenta; abre Ajustes.
class UserAvatarButton extends ConsumerWidget {
  const UserAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final scheme = Theme.of(context).colorScheme;
    final photo = user?.photoUrl;
    return IconButton(
      tooltip: 'Ajustes',
      onPressed: () => context.push('/ajustes'),
      icon: CircleAvatar(
        radius: 15,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        foregroundImage: photo == null
            ? null
            : NetworkImage(photo, webHtmlElementStrategy: WebHtmlElementStrategy.fallback),
        onForegroundImageError: photo == null ? null : (_, _) {},
        child: Text(user?.initial ?? '?', style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}
