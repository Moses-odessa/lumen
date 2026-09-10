import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/l10n/app_localizations.dart';
import 'package:lumen/core/l10n/interface_lang.dart';
import 'package:lumen/data/repositories/player_repository.dart';
import 'package:lumen/domain/entities/player.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/features/onboarding/presentation/onboarding_screen.dart';
import 'package:lumen/main.dart';

/// Связка «язык интерфейса → `MaterialApp`»: две строки `main.dart`, которые
/// не охранял никто.
///
/// Почему отдельный файл. Тесты подписей (`sky_naming_test.dart`,
/// `profile_naming_test.dart`) собирают свой `MaterialApp` и локаль подают ему
/// сами — иначе они проверяли бы подпись созвездия в отрыве от языка, на
/// котором игрок читает всё остальное на том же экране. Но поданная своей же
/// рукой локаль повторяет ровно ту строку, на которой держится приложение:
/// убери из `main.dart` `locale: Locale(interfaceLang)` — и они все останутся
/// зелёными, а игрок с немецким телефоном, выбравший в онбординге English,
/// получит английские имена созвездий и немецкий интерфейс. То есть ровно то
/// расхождение, ради которого язык интерфейса и стал провайдером. С
/// `didChangeLocales` было хуже: слова этого в тестах не было вовсе, и правку
/// можно было удалить бесследно.
///
/// Поэтому здесь проверяются не имена, а два звена, которых нет больше нигде,
/// и оба — на настоящем `LumenApp`:
///
/// * язык, на котором `Localizations` отдаёт экрану строки, — тот же, который
///   `interfaceLangProvider` отдаёт именам созвездий (`main.dart`, `locale:`);
/// * смена языка телефона на живом приложении доходит до провайдера
///   (`main.dart`, `didChangeLocales`). Riverpod о сигналах платформы не
///   знает: без сброса интерфейс переключился бы сразу — его локали Flutter
///   переспрашивает сам, — а имена остались бы на прежнем языке до
///   перезапуска.
///
/// Вместе с тестами подписей это и есть обещание волны: подпись ходит за
/// провайдером, интерфейс ходит за провайдером — значит, разойтись друг с
/// другом они не могут. Составить обещание из двух половин пришлось потому,
/// что целиком, от ассета до подписи внутри `LumenApp`, оно стоило бы теста с
/// онбордингом, навигацией по вкладкам и двумя базами, а ловило бы то же
/// самое.
///
/// Контентная база здесь не нужна: язык интерфейса виден по загруженному
/// пакету переводов, а гейт роутера держит некалиброванного игрока в
/// онбординге, который не открывает ни ассет, ни базу игрока.
///
/// Строки сравниваются с `lookupAppLocalizations`, а не вписаны в тест:
/// переводы правятся в ARB, и вписанная строка устарела бы молча — тогда как
/// исчезнувший ключ обрушит компиляцию громко.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  /// Приложение целиком; игрок до калибровки не дошёл, поэтому виден
  /// онбординг — самый дешёвый экран, у которого есть локализованные строки.
  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    required String? uiLang,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(playerControllerProvider.notifier).replace(
          Player(
            targetLang: 'de',
            nativeLang: 'uk',
            uiLang: uiLang,
            tier: Tier.a0,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LumenApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Язык, на котором экран получил строки.
  ///
  /// Спрашивается загруженный пакет переводов, а не `Localizations.localeOf`:
  /// локаль в дереве — это запрос, а игрок читает то, что отдал делегат, и
  /// сойтись с провайдером обязан именно ответ.
  String bundleLang(WidgetTester tester) => AppLocalizations.of(
        tester.element(find.byType(OnboardingScreen)),
      ).localeName;

  testWidgets('интерфейс говорит на языке, который назвал провайдер',
      (tester) async {
    // Телефон немецкий, а в онбординге выбран итальянский: единственная
    // расстановка, на которой видно, кто решает язык интерфейса. Совпади
    // настройка с системой — проверять было бы нечего, потому что оба ответа
    // одинаковы и при удалённой связке.
    binding.platformDispatcher.localesTestValue = const [Locale('de')];
    addTearDown(binding.platformDispatcher.clearLocalesTestValue);

    final container = await pumpApp(tester, uiLang: 'it');

    // Имена созвездий берутся с этого языка: `constellationNamingProvider`
    // читает тот же провайдер.
    expect(container.read(interfaceLangProvider), 'it');
    expect(bundleLang(tester), 'it',
        reason: 'интерфейс решил язык сам и разошёлся с именами созвездий');

    // Тот же ответ, но на экране, а не в делегате: без этого проверка
    // осталась бы утверждением о загруженном пакете, а не о том, что читает
    // игрок.
    final italian = lookupAppLocalizations(const Locale('it'));
    final german = lookupAppLocalizations(const Locale('de'));
    expect(italian.onboardingStartCalibration,
        isNot(german.onboardingStartCalibration),
        reason: 'переводы совпали — на этой паре языков ничего не различить');
    expect(find.text(italian.onboardingStartCalibration), findsOneWidget);
    expect(find.text(german.onboardingStartCalibration), findsNothing);
  });

  testWidgets('смена языка телефона доходит и до имён, а не только до строк',
      (tester) async {
    // Игрок оставил интерфейс «как в системе» — ветка, которой идёт
    // продакшен у всех, кто настройку не трогал.
    binding.platformDispatcher.localesTestValue = const [Locale('it')];
    addTearDown(binding.platformDispatcher.clearLocalesTestValue);

    final container = await pumpApp(tester, uiLang: null);
    expect(container.read(interfaceLangProvider), 'it');
    expect(bundleLang(tester), 'it');

    // Язык телефона сменился, игра не перезапускалась. Для Flutter это
    // сигнал платформы, для Riverpod — ничто: зависимости провайдера не
    // изменились, и без `didChangeLocales` он отдавал бы «it» до перезапуска.
    binding.platformDispatcher.localesTestValue = const [Locale('de')];
    await tester.pumpAndSettle();

    expect(container.read(interfaceLangProvider), 'de',
        reason: 'имена созвездий остались на прежнем языке — сброса нет');
    expect(bundleLang(tester), 'de');

    final german = lookupAppLocalizations(const Locale('de'));
    final italian = lookupAppLocalizations(const Locale('it'));
    expect(find.text(german.onboardingStartCalibration), findsOneWidget);
    expect(find.text(italian.onboardingStartCalibration), findsNothing,
        reason: 'интерфейс переключился, а язык имён — нет: это и есть'
            ' расхождение, от которого заведён один провайдер');
  });
}
