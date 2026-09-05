import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Облако')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Аккаунт нужен только для того, чтобы продолжить на другом '
            'устройстве. Без него игра работает полностью — и это не '
            'урезанный режим.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (!state.configured)
            const _NotConfigured()
          else if (state.signedIn)
            _SignedIn(state: state, controller: controller)
          else
            _SignIn(
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
  const _NotConfigured();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Облако не подключено', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Сервер появится, только если донаты покроют хостинг. До тех '
              'пор данные живут на устройстве, и их можно выгрузить файлом '
              'в настройках.',
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
    required this.email,
    required this.password,
    required this.busy,
    required this.onSignIn,
    required this.onSignUp,
    required this.onReset,
  });

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
          decoration: const InputDecoration(
            labelText: 'E-mail',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: password,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Пароль',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy ? null : onSignIn,
          child: const Text('Войти'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: busy ? null : onSignUp,
          child: const Text('Создать аккаунт'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy ? null : onReset,
          child: const Text('Забыли пароль?'),
        ),
      ],
    );
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn({required this.state, required this.controller});

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
          title: const Text('Синхронизация включена'),
          subtitle: Text(
            synced == null
                ? 'Ещё не синхронизировано'
                : 'Последний раз: ${synced.hour.toString().padLeft(2, '0')}:'
                    '${synced.minute.toString().padLeft(2, '0')}',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: state.syncing ? null : controller.push,
          child: const Text('Выгрузить сейчас'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: state.syncing ? null : controller.pull,
          child: const Text('Забрать из облака'),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: controller.signOut,
          child: const Text('Выйти'),
        ),
        const SizedBox(height: 8),
        Text(
          'Выход не удаляет локальные данные.',
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
          child: const Text('Удалить копию в облаке'),
        ),
      ],
    );
  }
}
