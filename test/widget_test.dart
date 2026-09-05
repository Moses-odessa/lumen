import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/repositories/player_repository.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/main.dart';

/// Смоук-тест: приложение стартует, redirect-гейт держит некалиброванного
/// игрока в онбординге, а после калибровки переключаются четыре вкладки.
///
/// Строки английские: локаль интерфейса в тестах не задана, значит берётся
/// системная, а в `flutter_test` это `en_US` — то есть шаблонный ARB.
///
/// `pumpAndSettle` здесь намеренно не используется после входа в оболочку:
/// карта неба грузится из двух баз и на время загрузки крутит индикатор,
/// который по определению никогда не «успокоится».
void main() {
  /// Иконка вкладки, а не любая такая же иконка на экране: заглушки вех
  /// используют те же иконки, что и нижняя навигация.
  Finder tab(IconData icon) => find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(icon),
      );

  /// Несколько кадров вместо ожидания полной тишины.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

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
    await settle(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 4);

    // Первая вкладка — небо.
    expect(find.text('Your sky'), findsOneWidget);

    await tester.tap(tab(Icons.play_circle_outline));
    await settle(tester);
    // Заголовок вкладки и заголовок карточки ритуала — одна и та же строка.
    expect(find.text('Daily ritual'), findsWidgets);

    await tester.tap(tab(Icons.person_outline));
    await settle(tester);
    expect(find.text('Profile'), findsWidgets);

    await tester.tap(tab(Icons.settings_outlined));
    await settle(tester);
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
    await settle(tester);

    final player = container.read(playerControllerProvider);
    expect(player, isNotNull);
    expect(player!.calibrated, isTrue);
    expect(player.tier, Tier.a0);
    expect(player.targetLang, defaultTargetLang);
    expect(player.nativeLang, defaultNativeLang);
  });

  testWidgets('ритуал предлагает начать, а не бросает в забег сразу',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LumenApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text("I'm starting from scratch"));
    await settle(tester);

    await tester.tap(tab(Icons.play_circle_outline));
    await settle(tester);

    // Ритуал должен иметь начало и конец — значит, и явную кнопку старта.
    expect(find.text('Daily ritual'), findsWidgets);
    expect(find.text('Start'), findsOneWidget);
  });
}
