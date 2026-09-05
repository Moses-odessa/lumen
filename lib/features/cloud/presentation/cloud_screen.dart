import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../application/cloud_controller.dart';

/// Облако: вход, выход, синхронизация.
///
/// Аккаунт необязателен, и экран говорит об этом первым делом. Без него нет
/// мультидевайса — но нет и бэкенда, расходов и персональных данных, а игра
/// работает целиком. Это не урезанный режим, а нормальное состояние.
class CloudScreen extends ConsumerStatefulWidget {
  const CloudScreen({super.key});

  @override
  ConsumerState<CloudScreen> createState() => _CloudScreenState();
}

class _CloudScreenState extends ConsumerState<CloudScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cloudControllerProvider);
    final controller = ref.read(cloudControllerProvider.notifier);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cloudTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l10n.cloudIntro,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (!state.configured)
            _NotConfigured(l10n: l10n)
          else if (state.signedIn)
            _SignedIn(l10n: l10n, state: state, controller: controller)
          else
            _SignIn(
              l10n: l10n,
              email: _email,
              password: _password,
              busy: state.syncing,
              onSignIn: () =>
                  controller.signIn(_email.text.trim(), _password.text),
              onSignUp: () =>
                  controller.signUp(_email.text.trim(), _password.text),
              onReset: () => controller.resetPassword(_email.text.trim()),
            ),
          if (state.error != null) ...[
            const SizedBox(height: 20),
            Text(
              state.error!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.cloudNotConfiguredTitle,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l10n.cloudNotConfiguredBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignIn extends StatelessWidget {
  const _SignIn({
    required this.l10n,
    required this.email,
    required this.password,
    required this.busy,
    required this.onSignIn,
    required this.onSignUp,
    required this.onReset,
  });

  final AppLocalizations l10n;
  final TextEditingController email;
  final TextEditingController password;
  final bool busy;
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: l10n.cloudEmail,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: password,
          obscureText: true,
          decoration: InputDecoration(
            labelText: l10n.cloudPassword,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy ? null : onSignIn,
          child: Text(l10n.cloudSignIn),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: busy ? null : onSignUp,
          child: Text(l10n.cloudSignUp),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy ? null : onReset,
          child: Text(l10n.cloudForgot),
        ),
      ],
    );
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn({
    required this.l10n,
    required this.state,
    required this.controller,
  });

  final AppLocalizations l10n;
  final CloudState state;
  final CloudController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final synced = state.lastSyncedAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.cloud_done_outlined),
          title: Text(l10n.cloudSyncOn),
          subtitle: Text(
            synced == null
                ? l10n.cloudNeverSynced
                : l10n.cloudLastSync(
                    '${synced.hour.toString().padLeft(2, '0')}:'
                    '${synced.minute.toString().padLeft(2, '0')}',
                  ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: state.syncing ? null : controller.push,
          child: Text(l10n.cloudPushNow),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: state.syncing ? null : controller.pull,
          child: Text(l10n.cloudPull),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: controller.signOut,
          child: Text(l10n.cloudSignOut),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.cloudSignOutNote,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: controller.deleteRemote,
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
          ),
          child: Text(l10n.cloudDeleteRemote),
        ),
      ],
    );
  }
}
