import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/player_repository.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/ritual/presentation/ritual_screen.dart';
import '../../features/settings/presentation/audio_spike_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/sky/presentation/sky_screen.dart';

/// Пути приложения в одном месте — чтобы не искать строки по коду.
abstract final class Routes {
  static const sky = '/';
  static const game = '/game';
  static const profile = '/profile';
  static const settings = '/settings';
  static const onboarding = '/onboarding';

  /// Спайк по задержке звука — измеряется на реальном телефоне (M1).
  static const audioSpike = '/settings/audio-spike';
}

/// Роутер: четыре вкладки в `StatefulShellRoute.indexedStack` и один
/// redirect-гейт — пока калибровка не пройдена, игрок видит только онбординг.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _PlayerGateRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.sky,
    refreshListenable: refresh,
    redirect: (context, state) {
      final player = ref.read(playerControllerProvider);
      final calibrated = player?.calibrated ?? false;
      final loc = state.matchedLocation;

      // Пока калибровка не пройдена — только онбординг. Загрузка состояния
      // выполняется до первого кадра, поэтому мигания здесь не будет.
      if (!calibrated) {
        return loc == Routes.onboarding ? null : Routes.onboarding;
      }
      // Прошли — онбординг больше не нужен.
      if (loc == Routes.onboarding) return Routes.sky;
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.sky, builder: (_, _) => const SkyScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.game,
              builder: (_, _) => const RitualScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.profile,
              builder: (_, _) => const ProfileScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.settings,
              builder: (_, _) => const SettingsScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.audioSpike,
        builder: (_, _) => const AudioSpikeScreen(),
      ),
    ],
  );
});

/// Мостик Riverpod → Listenable: пересчитывает redirect, когда меняется
/// состояние игрока (прошёл калибровку, сбросил данные).
class _PlayerGateRefresh extends ChangeNotifier {
  _PlayerGateRefresh(Ref ref) {
    _sub = ref.listen<Object?>(
      playerControllerProvider,
      (_, _) => notifyListeners(),
    );
  }

  late final ProviderSubscription _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
