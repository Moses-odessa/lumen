import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/cloud/user_data.dart';

/// Слияние — самая опасная операция в проекте: её ошибка стирает прогресс
/// молча и навсегда. Поэтому тестов здесь больше, чем кода.
void main() {
  final t0 = DateTime.utc(2026, 6, 1);

  WordSnapshot word(
    String id, {
    DateTime? reviewed,
    double stability = 10,
    int reps = 1,
  }) =>
      WordSnapshot(
        conceptId: id,
        tier: 'a0',
        difficulty: 5,
        stability: stability,
        lastReview: reviewed,
        reps: reps,
      );

  PlayerSnapshot player({
    String tier = 'a1',
    int orbit = 0,
    int sparks = 0,
    DateTime? played,
    bool calibrated = true,
  }) =>
      PlayerSnapshot(
        targetLang: 'de',
        nativeLang: 'ru',
        tier: tier,
        orbit: orbit,
        sparks: sparks,
        lastPlayedAt: played,
        calibrated: calibrated,
      );

  group('кодирование', () {
    test('снимок переживает JSON без потерь', () {
      final data = UserData(
        player: player(orbit: 7, sparks: 300, played: t0),
        words: [word('a', reviewed: t0, stability: 12.5, reps: 4)],
        sessions: [
          SessionSnapshot(
            startedAt: t0,
            durationMs: 360000,
            lmGained: 42,
            score: 900,
            newWords: 6,
          ),
        ],
        customWords: const [
          CustomWordSnapshot(
            id: 'custom_x',
            target: 'Quittung',
            native: 'квитанция',
            deck: 'custom',
          ),
        ],
      );

      final restored =
          decodeUserData(jsonDecode(jsonEncode(encodeUserData(data)))
              as Map<String, Object?>);

      expect(restored.player!.orbit, 7);
      expect(restored.player!.sparks, 300);
      expect(restored.words.single.stability, 12.5);
      expect(restored.words.single.reps, 4);
      expect(restored.sessions.single.lmGained, 42);
      expect(restored.customWords.single.target, 'Quittung');
    });

    test('журнал ответов в облако не уходит', () {
      // Он большой, нужен только локально и на другом устройстве бесполезен.
      final json = encodeUserData(const UserData());
      expect(json.containsKey('reviews'), isFalse);
    });

    test('версия формата записывается', () {
      expect(encodeUserData(const UserData())['version'], UserData.version);
    });
  });

  group('разбор мусора', () {
    test('пустой объект не роняет разбор', () {
      final data = decodeUserData(const {});
      expect(data.isEmpty, isTrue);
    });

    test('null вместо списков не роняет разбор', () {
      final data = decodeUserData(const {
        'player': null,
        'wordStates': null,
        'sessions': null,
      });
      expect(data.words, isEmpty);
      expect(data.sessions, isEmpty);
    });

    test('одна битая запись не уносит весь снимок', () {
      final data = decodeUserData({
        'wordStates': [
          {'conceptId': 'ok', 'difficulty': 5.0, 'stability': 3.0},
          // Без conceptId — разобрать нельзя.
          {'difficulty': 5.0},
          'вообще не объект',
        ],
      });
      expect(data.words, hasLength(1));
      expect(data.words.single.conceptId, 'ok');
    });

    test('отсутствующие поля заполняются разумными значениями', () {
      final data = decodeUserData({
        'wordStates': [
          {'conceptId': 'x'},
        ],
      });
      expect(data.words.single.tier, 'a0');
      expect(data.words.single.reps, 0);
      expect(data.words.single.lastReview, isNull);
    });

    test('битая дата не ломает запись целиком', () {
      final data = decodeUserData({
        'wordStates': [
          {'conceptId': 'x', 'lastReview': 'позавчера'},
        ],
      });
      expect(data.words.single.lastReview, isNull);
    });
  });

  group('слияние слов', () {
    test('слова из обоих источников попадают в результат', () {
      final merged = mergeUserData(
        UserData(words: [word('a', reviewed: t0)]),
        UserData(words: [word('b', reviewed: t0)]),
      );
      expect(merged.words.map((w) => w.conceptId), ['a', 'b']);
    });

    test('побеждает более свежее повторение', () {
      final merged = mergeUserData(
        UserData(words: [word('a', reviewed: t0, reps: 2)]),
        UserData(
          words: [
            word('a',
                reviewed: t0.add(const Duration(days: 3)),
                reps: 5,
                stability: 40),
          ],
        ),
      );

      expect(merged.words.single.reps, 5);
      expect(merged.words.single.stability, 40);
    });

    test('старая облачная запись не затирает свежую локальную', () {
      // Именно так теряется прогресс: телефон играл, планшет лежал.
      final merged = mergeUserData(
        UserData(
          words: [word('a', reviewed: t0.add(const Duration(days: 5)), reps: 9)],
        ),
        UserData(words: [word('a', reviewed: t0, reps: 1)]),
      );
      expect(merged.words.single.reps, 9);
    });

    test('запись без даты не побеждает запись с датой', () {
      final merged = mergeUserData(
        UserData(words: [word('a', reviewed: t0, reps: 4)]),
        UserData(words: [word('a', reps: 0)]),
      );
      expect(merged.words.single.reps, 4);
    });

    test('слияние с пустым снимком ничего не теряет', () {
      final local = UserData(words: [word('a', reviewed: t0)]);
      expect(mergeUserData(local, const UserData()).words, hasLength(1));
      expect(mergeUserData(const UserData(), local).words, hasLength(1));
    });

    test('слияние идемпотентно', () {
      final data = UserData(
        player: player(played: t0),
        words: [word('a', reviewed: t0), word('b', reviewed: t0)],
      );
      final once = mergeUserData(data, data);
      final twice = mergeUserData(once, once);

      expect(twice.words.length, once.words.length);
      expect(twice.player!.orbit, once.player!.orbit);
    });
  });

  group('слияние сессий и своих слов', () {
    test('сессии объединяются без дублей', () {
      final session = SessionSnapshot(
        startedAt: t0,
        durationMs: 1,
        lmGained: 1,
        score: 1,
        newWords: 1,
      );
      final merged = mergeUserData(
        UserData(sessions: [session]),
        UserData(sessions: [session]),
      );
      expect(merged.sessions, hasLength(1));
    });

    test('разные сессии сохраняются обе', () {
      final merged = mergeUserData(
        UserData(sessions: [
          SessionSnapshot(
              startedAt: t0,
              durationMs: 1,
              lmGained: 1,
              score: 1,
              newWords: 1),
        ]),
        UserData(sessions: [
          SessionSnapshot(
              startedAt: t0.add(const Duration(days: 1)),
              durationMs: 1,
              lmGained: 1,
              score: 1,
              newWords: 1),
        ]),
      );
      expect(merged.sessions, hasLength(2));
    });

    test('свои слова объединяются по id', () {
      final merged = mergeUserData(
        const UserData(customWords: [
          CustomWordSnapshot(
              id: 'x', target: 'A', native: 'а', deck: 'custom'),
        ]),
        const UserData(customWords: [
          CustomWordSnapshot(
              id: 'y', target: 'B', native: 'б', deck: 'custom'),
        ]),
      );
      expect(merged.customWords.map((c) => c.id), ['x', 'y']);
    });
  });

  group('слияние профиля', () {
    test('берётся профиль того, кто играл позже', () {
      final merged = mergeUserData(
        UserData(player: player(tier: 'a1', played: t0)),
        UserData(
          player: player(tier: 'a1', played: t0.add(const Duration(days: 2))),
        ),
      );
      expect(merged.player!.lastPlayedAt,
          t0.add(const Duration(days: 2)));
    });

    test('орбита и искры берутся максимумом', () {
      // Расхождение часов на устройствах не должно стоить игроку валюты.
      final merged = mergeUserData(
        UserData(player: player(orbit: 12, sparks: 50, played: t0)),
        UserData(
          player: player(
            orbit: 3,
            sparks: 900,
            played: t0.add(const Duration(days: 1)),
          ),
        ),
      );
      expect(merged.player!.orbit, 12);
      expect(merged.player!.sparks, 900);
    });

    test('ярус берётся выше из двух', () {
      // Понизить его игрок может сам одним тапом, а необъяснимое понижение
      // после синхронизации выглядит как потеря прогресса.
      final merged = mergeUserData(
        UserData(player: player(tier: 'b1', played: t0)),
        UserData(
          player: player(tier: 'a1', played: t0.add(const Duration(days: 5))),
        ),
      );
      expect(merged.player!.tier, 'b1');
    });

    test('пройденная калибровка не отменяется', () {
      final merged = mergeUserData(
        UserData(player: player(calibrated: true, played: t0)),
        UserData(
          player: player(
            calibrated: false,
            played: t0.add(const Duration(days: 9)),
          ),
        ),
      );
      expect(merged.player!.calibrated, isTrue);
    });

    test('единственный профиль выживает', () {
      expect(
        mergeUserData(UserData(player: player()), const UserData()).player,
        isNotNull,
      );
      expect(
        mergeUserData(const UserData(), UserData(player: player())).player,
        isNotNull,
      );
    });
  });
}
