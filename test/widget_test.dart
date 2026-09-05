import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/repositories/player_repository.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/main.dart';

/// Смоук-тест M0: приложение стартует, redirect-гейт держит некалиброванного
/// игрока в онбординге, а после калибровки переключаются четыре вкладки.
///
/// Строки английские: локаль интерфейса в тестах не задана, значит берётся
/// системная, а в `flutter_test` это `en_US` — то есть шаблонный ARB.
void main() {
  /// Иконка вкладки, а не любая такая же иконка на экране: заглушки вех
  /// используют те же иконки, что и нижняя навигация.
  Finder tab(IconData icon) => find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(icon),
      );

  testWidgets('некалиброванный игрок попадает в онбординг', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LumenApp()));
    await tester.pumpAndSettle();

    expect(find.text('Start calibration'), findsOneWidget);
    // Вкладок ещё нет: гейт не пройден.
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('«я с нуля» открывает четыре вкладки', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LumenApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text("I'm starting from scratch"));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 4);

    // Первая вкладка — небо.
    expect(find.text('Your sky'), findsOneWidget);

    await tester.tap(tab(Icons.play_circle_outline));
    await tester.pumpAndSettle();
    expect(find.text('Daily ritual'), findsOneWidget);

    await tester.tap(tab(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsWidgets);

    await tester.tap(tab(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('калибровка «с нуля» ставит A0', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LumenApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("I'm starting from scratch"));
    await tester.pumpAndSettle();

    final player = container.read(playerControllerProvider);
    expect(player, isNotNull);
    expect(player!.calibrated, isTrue);
    expect(player.tier, Tier.a0);
    expect(player.targetLang, defaultTargetLang);
    expect(player.nativeLang, defaultNativeLang);
  });
}
