import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_service.dart';
import '../../providers.dart';
import '../theme.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).signIn();
    } on SignInCancelled {
      // El usuario cerró el diálogo: no es un error.
    } catch (e) {
      _error = 'No se pudo ingresar. Revisá la conexión y la configuración de Firebase.\n$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(Icons.auto_stories, size: 40, color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 24),
                  Text('Diario', style: theme.textTheme.displaySmall!.copyWith(fontFamily: diaryFontFamily)),
                  const SizedBox(height: 8),
                  Text(
                    'Tu día, en pocas palabras o en muchas.',
                    textAlign: TextAlign.center,
                    style: context.diaryBody.copyWith(color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _signIn,
                      icon: _busy
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.login),
                      label: const Text('Continuar con Google'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tus entradas se guardan en tu cuenta y se sincronizan entre la compu y el celular.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: scheme.error)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
