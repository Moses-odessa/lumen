/// Недельные лиги.
///
/// Рейтинг считается по **приросту яркости**, а не по XP. Это не деталь, а
/// защита механики: любая валюта, которую можно нафармить повтором лёгкого,
/// будет фармиться, а у горящих слов прирост яркости близок к нулю — их
/// перепроходить бессмысленно.
///
/// Чистый Dart: ни сети, ни базы. Ранжирование должно быть проверяемым без
/// сервера, потому что именно от него зависит, честной ли выглядит игра.
library;

/// Участник недельной группы.
class LeagueMember {
  const LeagueMember({
    required this.id,
    required this.displayName,
    required this.lumensGained,
    this.daysPlayed = 0,
  });

  final String id;
  final String displayName;

  /// Прирост яркости за неделю — единственная величина рейтинга.
  final int lumensGained;

  final int daysPlayed;
}

/// Место в таблице.
class LeagueStanding {
  const LeagueStanding({
    required this.rank,
    required this.member,
    required this.zone,
  });

  final int rank;
  final LeagueMember member;
  final LeagueZone zone;
}

/// Что произойдёт с участником в конце недели.
enum LeagueZone {
  /// Верхняя часть таблицы — переход выше.
  promotion,

  /// Середина — остаётся.
  stay,

  /// Нижняя часть — переход ниже.
  relegation,
}

abstract final class League {
  /// Размер недельной группы (docs/CONCEPT.md). TODO(balance)
  static const int groupSize = 24;

  /// Сколько поднимается и сколько опускается. TODO(balance)
  static const int promoted = 5;
  static const int relegated = 5;

  /// Таблица группы.
  ///
  /// При равном приросте выше тот, кто играл больше дней: регулярность
  /// ценнее одного героического вечера — ровно то, чему игра учит.
  static List<LeagueStanding> standings(List<LeagueMember> members) {
    final sorted = [...members]..sort((a, b) {
        final byLumens = b.lumensGained.compareTo(a.lumensGained);
        if (byLumens != 0) return byLumens;
        final byDays = b.daysPlayed.compareTo(a.daysPlayed);
        // Последний критерий — идентификатор: таблица обязана быть
        // одинаковой у всех, кто её открыл.
        return byDays != 0 ? byDays : a.id.compareTo(b.id);
      });

    return [
      for (var i = 0; i < sorted.length; i++)
        LeagueStanding(
          rank: i + 1,
          member: sorted[i],
          zone: _zone(i + 1, sorted.length),
        ),
    ];
  }

  static LeagueZone _zone(int rank, int total) {
    if (rank <= promoted) return LeagueZone.promotion;
    // Зона вылета считается от фактического размера группы: в неполной
    // группе опускать половину участников было бы издевательством.
    if (total > promoted + relegated && rank > total - relegated) {
      return LeagueZone.relegation;
    }
    return LeagueZone.stay;
  }

  /// Место конкретного игрока; `null` — его нет в группе.
  static LeagueStanding? find(List<LeagueStanding> table, String id) {
    for (final standing in table) {
      if (standing.member.id == id) return standing;
    }
    return null;
  }

  /// Ключ недели: по нему группа собирается на сервере и по нему же
  /// клиент понимает, что неделя сменилась.
  ///
  /// Неделя считается от понедельника в UTC — иначе игроки в разных
  /// поясах попадали бы в разные недели одной и той же группы.
  static String weekKey(DateTime moment) {
    final utc = moment.toUtc();
    final monday = DateTime.utc(utc.year, utc.month, utc.day)
        .subtract(Duration(days: utc.weekday - 1));
    return '${monday.year.toString().padLeft(4, '0')}-'
        'W${_weekNumber(monday).toString().padLeft(2, '0')}';
  }

  static int _weekNumber(DateTime monday) {
    final firstDay = DateTime.utc(monday.year, 1, 1);
    final days = monday.difference(firstDay).inDays;
    return (days / 7).floor() + 1;
  }
}
