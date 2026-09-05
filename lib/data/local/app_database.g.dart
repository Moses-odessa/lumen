// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PlayersTable extends Players with TableInfo<$PlayersTable, PlayerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _targetLangMeta = const VerificationMeta(
    'targetLang',
  );
  @override
  late final GeneratedColumn<String> targetLang = GeneratedColumn<String>(
    'target_lang',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nativeLangMeta = const VerificationMeta(
    'nativeLang',
  );
  @override
  late final GeneratedColumn<String> nativeLang = GeneratedColumn<String>(
    'native_lang',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uiLangMeta = const VerificationMeta('uiLang');
  @override
  late final GeneratedColumn<String> uiLang = GeneratedColumn<String>(
    'ui_lang',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tierMeta = const VerificationMeta('tier');
  @override
  late final GeneratedColumn<String> tier = GeneratedColumn<String>(
    'tier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _calibratedMeta = const VerificationMeta(
    'calibrated',
  );
  @override
  late final GeneratedColumn<bool> calibrated = GeneratedColumn<bool>(
    'calibrated',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("calibrated" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _orbitMeta = const VerificationMeta('orbit');
  @override
  late final GeneratedColumn<int> orbit = GeneratedColumn<int>(
    'orbit',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sparksMeta = const VerificationMeta('sparks');
  @override
  late final GeneratedColumn<int> sparks = GeneratedColumn<int>(
    'sparks',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPlayedAt = GeneratedColumn<DateTime>(
    'last_played_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _missedInRowMeta = const VerificationMeta(
    'missedInRow',
  );
  @override
  late final GeneratedColumn<int> missedInRow = GeneratedColumn<int>(
    'missed_in_row',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _freePaceMeta = const VerificationMeta(
    'freePace',
  );
  @override
  late final GeneratedColumn<bool> freePace = GeneratedColumn<bool>(
    'free_pace',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("free_pace" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _soundEnabledMeta = const VerificationMeta(
    'soundEnabled',
  );
  @override
  late final GeneratedColumn<bool> soundEnabled = GeneratedColumn<bool>(
    'sound_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sound_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    targetLang,
    nativeLang,
    uiLang,
    tier,
    calibrated,
    orbit,
    sparks,
    lastPlayedAt,
    missedInRow,
    freePace,
    soundEnabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'players';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('target_lang')) {
      context.handle(
        _targetLangMeta,
        targetLang.isAcceptableOrUnknown(data['target_lang']!, _targetLangMeta),
      );
    } else if (isInserting) {
      context.missing(_targetLangMeta);
    }
    if (data.containsKey('native_lang')) {
      context.handle(
        _nativeLangMeta,
        nativeLang.isAcceptableOrUnknown(data['native_lang']!, _nativeLangMeta),
      );
    } else if (isInserting) {
      context.missing(_nativeLangMeta);
    }
    if (data.containsKey('ui_lang')) {
      context.handle(
        _uiLangMeta,
        uiLang.isAcceptableOrUnknown(data['ui_lang']!, _uiLangMeta),
      );
    }
    if (data.containsKey('tier')) {
      context.handle(
        _tierMeta,
        tier.isAcceptableOrUnknown(data['tier']!, _tierMeta),
      );
    } else if (isInserting) {
      context.missing(_tierMeta);
    }
    if (data.containsKey('calibrated')) {
      context.handle(
        _calibratedMeta,
        calibrated.isAcceptableOrUnknown(data['calibrated']!, _calibratedMeta),
      );
    }
    if (data.containsKey('orbit')) {
      context.handle(
        _orbitMeta,
        orbit.isAcceptableOrUnknown(data['orbit']!, _orbitMeta),
      );
    }
    if (data.containsKey('sparks')) {
      context.handle(
        _sparksMeta,
        sparks.isAcceptableOrUnknown(data['sparks']!, _sparksMeta),
      );
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    }
    if (data.containsKey('missed_in_row')) {
      context.handle(
        _missedInRowMeta,
        missedInRow.isAcceptableOrUnknown(
          data['missed_in_row']!,
          _missedInRowMeta,
        ),
      );
    }
    if (data.containsKey('free_pace')) {
      context.handle(
        _freePaceMeta,
        freePace.isAcceptableOrUnknown(data['free_pace']!, _freePaceMeta),
      );
    }
    if (data.containsKey('sound_enabled')) {
      context.handle(
        _soundEnabledMeta,
        soundEnabled.isAcceptableOrUnknown(
          data['sound_enabled']!,
          _soundEnabledMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      targetLang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_lang'],
      )!,
      nativeLang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}native_lang'],
      )!,
      uiLang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ui_lang'],
      ),
      tier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tier'],
      )!,
      calibrated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}calibrated'],
      )!,
      orbit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}orbit'],
      )!,
      sparks: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sparks'],
      )!,
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_played_at'],
      ),
      missedInRow: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}missed_in_row'],
      )!,
      freePace: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}free_pace'],
      )!,
      soundEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sound_enabled'],
      )!,
    );
  }

  @override
  $PlayersTable createAlias(String alias) {
    return $PlayersTable(attachedDatabase, alias);
  }
}

class PlayerRow extends DataClass implements Insertable<PlayerRow> {
  final int id;
  final String targetLang;
  final String nativeLang;
  final String? uiLang;
  final String tier;
  final bool calibrated;
  final int orbit;
  final int sparks;
  final DateTime? lastPlayedAt;
  final int missedInRow;
  final bool freePace;
  final bool soundEnabled;
  const PlayerRow({
    required this.id,
    required this.targetLang,
    required this.nativeLang,
    this.uiLang,
    required this.tier,
    required this.calibrated,
    required this.orbit,
    required this.sparks,
    this.lastPlayedAt,
    required this.missedInRow,
    required this.freePace,
    required this.soundEnabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['target_lang'] = Variable<String>(targetLang);
    map['native_lang'] = Variable<String>(nativeLang);
    if (!nullToAbsent || uiLang != null) {
      map['ui_lang'] = Variable<String>(uiLang);
    }
    map['tier'] = Variable<String>(tier);
    map['calibrated'] = Variable<bool>(calibrated);
    map['orbit'] = Variable<int>(orbit);
    map['sparks'] = Variable<int>(sparks);
    if (!nullToAbsent || lastPlayedAt != null) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt);
    }
    map['missed_in_row'] = Variable<int>(missedInRow);
    map['free_pace'] = Variable<bool>(freePace);
    map['sound_enabled'] = Variable<bool>(soundEnabled);
    return map;
  }

  PlayersCompanion toCompanion(bool nullToAbsent) {
    return PlayersCompanion(
      id: Value(id),
      targetLang: Value(targetLang),
      nativeLang: Value(nativeLang),
      uiLang: uiLang == null && nullToAbsent
          ? const Value.absent()
          : Value(uiLang),
      tier: Value(tier),
      calibrated: Value(calibrated),
      orbit: Value(orbit),
      sparks: Value(sparks),
      lastPlayedAt: lastPlayedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedAt),
      missedInRow: Value(missedInRow),
      freePace: Value(freePace),
      soundEnabled: Value(soundEnabled),
    );
  }

  factory PlayerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayerRow(
      id: serializer.fromJson<int>(json['id']),
      targetLang: serializer.fromJson<String>(json['targetLang']),
      nativeLang: serializer.fromJson<String>(json['nativeLang']),
      uiLang: serializer.fromJson<String?>(json['uiLang']),
      tier: serializer.fromJson<String>(json['tier']),
      calibrated: serializer.fromJson<bool>(json['calibrated']),
      orbit: serializer.fromJson<int>(json['orbit']),
      sparks: serializer.fromJson<int>(json['sparks']),
      lastPlayedAt: serializer.fromJson<DateTime?>(json['lastPlayedAt']),
      missedInRow: serializer.fromJson<int>(json['missedInRow']),
      freePace: serializer.fromJson<bool>(json['freePace']),
      soundEnabled: serializer.fromJson<bool>(json['soundEnabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'targetLang': serializer.toJson<String>(targetLang),
      'nativeLang': serializer.toJson<String>(nativeLang),
      'uiLang': serializer.toJson<String?>(uiLang),
      'tier': serializer.toJson<String>(tier),
      'calibrated': serializer.toJson<bool>(calibrated),
      'orbit': serializer.toJson<int>(orbit),
      'sparks': serializer.toJson<int>(sparks),
      'lastPlayedAt': serializer.toJson<DateTime?>(lastPlayedAt),
      'missedInRow': serializer.toJson<int>(missedInRow),
      'freePace': serializer.toJson<bool>(freePace),
      'soundEnabled': serializer.toJson<bool>(soundEnabled),
    };
  }

  PlayerRow copyWith({
    int? id,
    String? targetLang,
    String? nativeLang,
    Value<String?> uiLang = const Value.absent(),
    String? tier,
    bool? calibrated,
    int? orbit,
    int? sparks,
    Value<DateTime?> lastPlayedAt = const Value.absent(),
    int? missedInRow,
    bool? freePace,
    bool? soundEnabled,
  }) => PlayerRow(
    id: id ?? this.id,
    targetLang: targetLang ?? this.targetLang,
    nativeLang: nativeLang ?? this.nativeLang,
    uiLang: uiLang.present ? uiLang.value : this.uiLang,
    tier: tier ?? this.tier,
    calibrated: calibrated ?? this.calibrated,
    orbit: orbit ?? this.orbit,
    sparks: sparks ?? this.sparks,
    lastPlayedAt: lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
    missedInRow: missedInRow ?? this.missedInRow,
    freePace: freePace ?? this.freePace,
    soundEnabled: soundEnabled ?? this.soundEnabled,
  );
  PlayerRow copyWithCompanion(PlayersCompanion data) {
    return PlayerRow(
      id: data.id.present ? data.id.value : this.id,
      targetLang: data.targetLang.present
          ? data.targetLang.value
          : this.targetLang,
      nativeLang: data.nativeLang.present
          ? data.nativeLang.value
          : this.nativeLang,
      uiLang: data.uiLang.present ? data.uiLang.value : this.uiLang,
      tier: data.tier.present ? data.tier.value : this.tier,
      calibrated: data.calibrated.present
          ? data.calibrated.value
          : this.calibrated,
      orbit: data.orbit.present ? data.orbit.value : this.orbit,
      sparks: data.sparks.present ? data.sparks.value : this.sparks,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
      missedInRow: data.missedInRow.present
          ? data.missedInRow.value
          : this.missedInRow,
      freePace: data.freePace.present ? data.freePace.value : this.freePace,
      soundEnabled: data.soundEnabled.present
          ? data.soundEnabled.value
          : this.soundEnabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayerRow(')
          ..write('id: $id, ')
          ..write('targetLang: $targetLang, ')
          ..write('nativeLang: $nativeLang, ')
          ..write('uiLang: $uiLang, ')
          ..write('tier: $tier, ')
          ..write('calibrated: $calibrated, ')
          ..write('orbit: $orbit, ')
          ..write('sparks: $sparks, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('missedInRow: $missedInRow, ')
          ..write('freePace: $freePace, ')
          ..write('soundEnabled: $soundEnabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    targetLang,
    nativeLang,
    uiLang,
    tier,
    calibrated,
    orbit,
    sparks,
    lastPlayedAt,
    missedInRow,
    freePace,
    soundEnabled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayerRow &&
          other.id == this.id &&
          other.targetLang == this.targetLang &&
          other.nativeLang == this.nativeLang &&
          other.uiLang == this.uiLang &&
          other.tier == this.tier &&
          other.calibrated == this.calibrated &&
          other.orbit == this.orbit &&
          other.sparks == this.sparks &&
          other.lastPlayedAt == this.lastPlayedAt &&
          other.missedInRow == this.missedInRow &&
          other.freePace == this.freePace &&
          other.soundEnabled == this.soundEnabled);
}

class PlayersCompanion extends UpdateCompanion<PlayerRow> {
  final Value<int> id;
  final Value<String> targetLang;
  final Value<String> nativeLang;
  final Value<String?> uiLang;
  final Value<String> tier;
  final Value<bool> calibrated;
  final Value<int> orbit;
  final Value<int> sparks;
  final Value<DateTime?> lastPlayedAt;
  final Value<int> missedInRow;
  final Value<bool> freePace;
  final Value<bool> soundEnabled;
  const PlayersCompanion({
    this.id = const Value.absent(),
    this.targetLang = const Value.absent(),
    this.nativeLang = const Value.absent(),
    this.uiLang = const Value.absent(),
    this.tier = const Value.absent(),
    this.calibrated = const Value.absent(),
    this.orbit = const Value.absent(),
    this.sparks = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.missedInRow = const Value.absent(),
    this.freePace = const Value.absent(),
    this.soundEnabled = const Value.absent(),
  });
  PlayersCompanion.insert({
    this.id = const Value.absent(),
    required String targetLang,
    required String nativeLang,
    this.uiLang = const Value.absent(),
    required String tier,
    this.calibrated = const Value.absent(),
    this.orbit = const Value.absent(),
    this.sparks = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.missedInRow = const Value.absent(),
    this.freePace = const Value.absent(),
    this.soundEnabled = const Value.absent(),
  }) : targetLang = Value(targetLang),
       nativeLang = Value(nativeLang),
       tier = Value(tier);
  static Insertable<PlayerRow> custom({
    Expression<int>? id,
    Expression<String>? targetLang,
    Expression<String>? nativeLang,
    Expression<String>? uiLang,
    Expression<String>? tier,
    Expression<bool>? calibrated,
    Expression<int>? orbit,
    Expression<int>? sparks,
    Expression<DateTime>? lastPlayedAt,
    Expression<int>? missedInRow,
    Expression<bool>? freePace,
    Expression<bool>? soundEnabled,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (targetLang != null) 'target_lang': targetLang,
      if (nativeLang != null) 'native_lang': nativeLang,
      if (uiLang != null) 'ui_lang': uiLang,
      if (tier != null) 'tier': tier,
      if (calibrated != null) 'calibrated': calibrated,
      if (orbit != null) 'orbit': orbit,
      if (sparks != null) 'sparks': sparks,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (missedInRow != null) 'missed_in_row': missedInRow,
      if (freePace != null) 'free_pace': freePace,
      if (soundEnabled != null) 'sound_enabled': soundEnabled,
    });
  }

  PlayersCompanion copyWith({
    Value<int>? id,
    Value<String>? targetLang,
    Value<String>? nativeLang,
    Value<String?>? uiLang,
    Value<String>? tier,
    Value<bool>? calibrated,
    Value<int>? orbit,
    Value<int>? sparks,
    Value<DateTime?>? lastPlayedAt,
    Value<int>? missedInRow,
    Value<bool>? freePace,
    Value<bool>? soundEnabled,
  }) {
    return PlayersCompanion(
      id: id ?? this.id,
      targetLang: targetLang ?? this.targetLang,
      nativeLang: nativeLang ?? this.nativeLang,
      uiLang: uiLang ?? this.uiLang,
      tier: tier ?? this.tier,
      calibrated: calibrated ?? this.calibrated,
      orbit: orbit ?? this.orbit,
      sparks: sparks ?? this.sparks,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      missedInRow: missedInRow ?? this.missedInRow,
      freePace: freePace ?? this.freePace,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (targetLang.present) {
      map['target_lang'] = Variable<String>(targetLang.value);
    }
    if (nativeLang.present) {
      map['native_lang'] = Variable<String>(nativeLang.value);
    }
    if (uiLang.present) {
      map['ui_lang'] = Variable<String>(uiLang.value);
    }
    if (tier.present) {
      map['tier'] = Variable<String>(tier.value);
    }
    if (calibrated.present) {
      map['calibrated'] = Variable<bool>(calibrated.value);
    }
    if (orbit.present) {
      map['orbit'] = Variable<int>(orbit.value);
    }
    if (sparks.present) {
      map['sparks'] = Variable<int>(sparks.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt.value);
    }
    if (missedInRow.present) {
      map['missed_in_row'] = Variable<int>(missedInRow.value);
    }
    if (freePace.present) {
      map['free_pace'] = Variable<bool>(freePace.value);
    }
    if (soundEnabled.present) {
      map['sound_enabled'] = Variable<bool>(soundEnabled.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayersCompanion(')
          ..write('id: $id, ')
          ..write('targetLang: $targetLang, ')
          ..write('nativeLang: $nativeLang, ')
          ..write('uiLang: $uiLang, ')
          ..write('tier: $tier, ')
          ..write('calibrated: $calibrated, ')
          ..write('orbit: $orbit, ')
          ..write('sparks: $sparks, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('missedInRow: $missedInRow, ')
          ..write('freePace: $freePace, ')
          ..write('soundEnabled: $soundEnabled')
          ..write(')'))
        .toString();
  }
}

class $WordStatesTable extends WordStates
    with TableInfo<$WordStatesTable, WordStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _conceptIdMeta = const VerificationMeta(
    'conceptId',
  );
  @override
  late final GeneratedColumn<String> conceptId = GeneratedColumn<String>(
    'concept_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tierMeta = const VerificationMeta('tier');
  @override
  late final GeneratedColumn<String> tier = GeneratedColumn<String>(
    'tier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<double> difficulty = GeneratedColumn<double>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stabilityMeta = const VerificationMeta(
    'stability',
  );
  @override
  late final GeneratedColumn<double> stability = GeneratedColumn<double>(
    'stability',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastReviewMeta = const VerificationMeta(
    'lastReview',
  );
  @override
  late final GeneratedColumn<DateTime> lastReview = GeneratedColumn<DateTime>(
    'last_review',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueMeta = const VerificationMeta('due');
  @override
  late final GeneratedColumn<DateTime> due = GeneratedColumn<DateTime>(
    'due',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lmCachedMeta = const VerificationMeta(
    'lmCached',
  );
  @override
  late final GeneratedColumn<int> lmCached = GeneratedColumn<int>(
    'lm_cached',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fastStreakMeta = const VerificationMeta(
    'fastStreak',
  );
  @override
  late final GeneratedColumn<int> fastStreak = GeneratedColumn<int>(
    'fast_streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _burningMeta = const VerificationMeta(
    'burning',
  );
  @override
  late final GeneratedColumn<bool> burning = GeneratedColumn<bool>(
    'burning',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("burning" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lapsesMeta = const VerificationMeta('lapses');
  @override
  late final GeneratedColumn<int> lapses = GeneratedColumn<int>(
    'lapses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    conceptId,
    tier,
    difficulty,
    stability,
    lastReview,
    due,
    lmCached,
    fastStreak,
    burning,
    reps,
    lapses,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'word_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<WordStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('concept_id')) {
      context.handle(
        _conceptIdMeta,
        conceptId.isAcceptableOrUnknown(data['concept_id']!, _conceptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_conceptIdMeta);
    }
    if (data.containsKey('tier')) {
      context.handle(
        _tierMeta,
        tier.isAcceptableOrUnknown(data['tier']!, _tierMeta),
      );
    } else if (isInserting) {
      context.missing(_tierMeta);
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    } else if (isInserting) {
      context.missing(_difficultyMeta);
    }
    if (data.containsKey('stability')) {
      context.handle(
        _stabilityMeta,
        stability.isAcceptableOrUnknown(data['stability']!, _stabilityMeta),
      );
    } else if (isInserting) {
      context.missing(_stabilityMeta);
    }
    if (data.containsKey('last_review')) {
      context.handle(
        _lastReviewMeta,
        lastReview.isAcceptableOrUnknown(data['last_review']!, _lastReviewMeta),
      );
    }
    if (data.containsKey('due')) {
      context.handle(
        _dueMeta,
        due.isAcceptableOrUnknown(data['due']!, _dueMeta),
      );
    }
    if (data.containsKey('lm_cached')) {
      context.handle(
        _lmCachedMeta,
        lmCached.isAcceptableOrUnknown(data['lm_cached']!, _lmCachedMeta),
      );
    }
    if (data.containsKey('fast_streak')) {
      context.handle(
        _fastStreakMeta,
        fastStreak.isAcceptableOrUnknown(data['fast_streak']!, _fastStreakMeta),
      );
    }
    if (data.containsKey('burning')) {
      context.handle(
        _burningMeta,
        burning.isAcceptableOrUnknown(data['burning']!, _burningMeta),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('lapses')) {
      context.handle(
        _lapsesMeta,
        lapses.isAcceptableOrUnknown(data['lapses']!, _lapsesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {conceptId};
  @override
  WordStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordStateRow(
      conceptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}concept_id'],
      )!,
      tier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tier'],
      )!,
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}difficulty'],
      )!,
      stability: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stability'],
      )!,
      lastReview: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_review'],
      ),
      due: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due'],
      ),
      lmCached: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lm_cached'],
      )!,
      fastStreak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fast_streak'],
      )!,
      burning: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}burning'],
      )!,
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      )!,
      lapses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapses'],
      )!,
    );
  }

  @override
  $WordStatesTable createAlias(String alias) {
    return $WordStatesTable(attachedDatabase, alias);
  }
}

class WordStateRow extends DataClass implements Insertable<WordStateRow> {
  final String conceptId;
  final String tier;
  final double difficulty;
  final double stability;
  final DateTime? lastReview;
  final DateTime? due;
  final int lmCached;
  final int fastStreak;
  final bool burning;
  final int reps;
  final int lapses;
  const WordStateRow({
    required this.conceptId,
    required this.tier,
    required this.difficulty,
    required this.stability,
    this.lastReview,
    this.due,
    required this.lmCached,
    required this.fastStreak,
    required this.burning,
    required this.reps,
    required this.lapses,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['concept_id'] = Variable<String>(conceptId);
    map['tier'] = Variable<String>(tier);
    map['difficulty'] = Variable<double>(difficulty);
    map['stability'] = Variable<double>(stability);
    if (!nullToAbsent || lastReview != null) {
      map['last_review'] = Variable<DateTime>(lastReview);
    }
    if (!nullToAbsent || due != null) {
      map['due'] = Variable<DateTime>(due);
    }
    map['lm_cached'] = Variable<int>(lmCached);
    map['fast_streak'] = Variable<int>(fastStreak);
    map['burning'] = Variable<bool>(burning);
    map['reps'] = Variable<int>(reps);
    map['lapses'] = Variable<int>(lapses);
    return map;
  }

  WordStatesCompanion toCompanion(bool nullToAbsent) {
    return WordStatesCompanion(
      conceptId: Value(conceptId),
      tier: Value(tier),
      difficulty: Value(difficulty),
      stability: Value(stability),
      lastReview: lastReview == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReview),
      due: due == null && nullToAbsent ? const Value.absent() : Value(due),
      lmCached: Value(lmCached),
      fastStreak: Value(fastStreak),
      burning: Value(burning),
      reps: Value(reps),
      lapses: Value(lapses),
    );
  }

  factory WordStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordStateRow(
      conceptId: serializer.fromJson<String>(json['conceptId']),
      tier: serializer.fromJson<String>(json['tier']),
      difficulty: serializer.fromJson<double>(json['difficulty']),
      stability: serializer.fromJson<double>(json['stability']),
      lastReview: serializer.fromJson<DateTime?>(json['lastReview']),
      due: serializer.fromJson<DateTime?>(json['due']),
      lmCached: serializer.fromJson<int>(json['lmCached']),
      fastStreak: serializer.fromJson<int>(json['fastStreak']),
      burning: serializer.fromJson<bool>(json['burning']),
      reps: serializer.fromJson<int>(json['reps']),
      lapses: serializer.fromJson<int>(json['lapses']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conceptId': serializer.toJson<String>(conceptId),
      'tier': serializer.toJson<String>(tier),
      'difficulty': serializer.toJson<double>(difficulty),
      'stability': serializer.toJson<double>(stability),
      'lastReview': serializer.toJson<DateTime?>(lastReview),
      'due': serializer.toJson<DateTime?>(due),
      'lmCached': serializer.toJson<int>(lmCached),
      'fastStreak': serializer.toJson<int>(fastStreak),
      'burning': serializer.toJson<bool>(burning),
      'reps': serializer.toJson<int>(reps),
      'lapses': serializer.toJson<int>(lapses),
    };
  }

  WordStateRow copyWith({
    String? conceptId,
    String? tier,
    double? difficulty,
    double? stability,
    Value<DateTime?> lastReview = const Value.absent(),
    Value<DateTime?> due = const Value.absent(),
    int? lmCached,
    int? fastStreak,
    bool? burning,
    int? reps,
    int? lapses,
  }) => WordStateRow(
    conceptId: conceptId ?? this.conceptId,
    tier: tier ?? this.tier,
    difficulty: difficulty ?? this.difficulty,
    stability: stability ?? this.stability,
    lastReview: lastReview.present ? lastReview.value : this.lastReview,
    due: due.present ? due.value : this.due,
    lmCached: lmCached ?? this.lmCached,
    fastStreak: fastStreak ?? this.fastStreak,
    burning: burning ?? this.burning,
    reps: reps ?? this.reps,
    lapses: lapses ?? this.lapses,
  );
  WordStateRow copyWithCompanion(WordStatesCompanion data) {
    return WordStateRow(
      conceptId: data.conceptId.present ? data.conceptId.value : this.conceptId,
      tier: data.tier.present ? data.tier.value : this.tier,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      stability: data.stability.present ? data.stability.value : this.stability,
      lastReview: data.lastReview.present
          ? data.lastReview.value
          : this.lastReview,
      due: data.due.present ? data.due.value : this.due,
      lmCached: data.lmCached.present ? data.lmCached.value : this.lmCached,
      fastStreak: data.fastStreak.present
          ? data.fastStreak.value
          : this.fastStreak,
      burning: data.burning.present ? data.burning.value : this.burning,
      reps: data.reps.present ? data.reps.value : this.reps,
      lapses: data.lapses.present ? data.lapses.value : this.lapses,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordStateRow(')
          ..write('conceptId: $conceptId, ')
          ..write('tier: $tier, ')
          ..write('difficulty: $difficulty, ')
          ..write('stability: $stability, ')
          ..write('lastReview: $lastReview, ')
          ..write('due: $due, ')
          ..write('lmCached: $lmCached, ')
          ..write('fastStreak: $fastStreak, ')
          ..write('burning: $burning, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    conceptId,
    tier,
    difficulty,
    stability,
    lastReview,
    due,
    lmCached,
    fastStreak,
    burning,
    reps,
    lapses,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordStateRow &&
          other.conceptId == this.conceptId &&
          other.tier == this.tier &&
          other.difficulty == this.difficulty &&
          other.stability == this.stability &&
          other.lastReview == this.lastReview &&
          other.due == this.due &&
          other.lmCached == this.lmCached &&
          other.fastStreak == this.fastStreak &&
          other.burning == this.burning &&
          other.reps == this.reps &&
          other.lapses == this.lapses);
}

class WordStatesCompanion extends UpdateCompanion<WordStateRow> {
  final Value<String> conceptId;
  final Value<String> tier;
  final Value<double> difficulty;
  final Value<double> stability;
  final Value<DateTime?> lastReview;
  final Value<DateTime?> due;
  final Value<int> lmCached;
  final Value<int> fastStreak;
  final Value<bool> burning;
  final Value<int> reps;
  final Value<int> lapses;
  final Value<int> rowid;
  const WordStatesCompanion({
    this.conceptId = const Value.absent(),
    this.tier = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.stability = const Value.absent(),
    this.lastReview = const Value.absent(),
    this.due = const Value.absent(),
    this.lmCached = const Value.absent(),
    this.fastStreak = const Value.absent(),
    this.burning = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WordStatesCompanion.insert({
    required String conceptId,
    required String tier,
    required double difficulty,
    required double stability,
    this.lastReview = const Value.absent(),
    this.due = const Value.absent(),
    this.lmCached = const Value.absent(),
    this.fastStreak = const Value.absent(),
    this.burning = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : conceptId = Value(conceptId),
       tier = Value(tier),
       difficulty = Value(difficulty),
       stability = Value(stability);
  static Insertable<WordStateRow> custom({
    Expression<String>? conceptId,
    Expression<String>? tier,
    Expression<double>? difficulty,
    Expression<double>? stability,
    Expression<DateTime>? lastReview,
    Expression<DateTime>? due,
    Expression<int>? lmCached,
    Expression<int>? fastStreak,
    Expression<bool>? burning,
    Expression<int>? reps,
    Expression<int>? lapses,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (conceptId != null) 'concept_id': conceptId,
      if (tier != null) 'tier': tier,
      if (difficulty != null) 'difficulty': difficulty,
      if (stability != null) 'stability': stability,
      if (lastReview != null) 'last_review': lastReview,
      if (due != null) 'due': due,
      if (lmCached != null) 'lm_cached': lmCached,
      if (fastStreak != null) 'fast_streak': fastStreak,
      if (burning != null) 'burning': burning,
      if (reps != null) 'reps': reps,
      if (lapses != null) 'lapses': lapses,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordStatesCompanion copyWith({
    Value<String>? conceptId,
    Value<String>? tier,
    Value<double>? difficulty,
    Value<double>? stability,
    Value<DateTime?>? lastReview,
    Value<DateTime?>? due,
    Value<int>? lmCached,
    Value<int>? fastStreak,
    Value<bool>? burning,
    Value<int>? reps,
    Value<int>? lapses,
    Value<int>? rowid,
  }) {
    return WordStatesCompanion(
      conceptId: conceptId ?? this.conceptId,
      tier: tier ?? this.tier,
      difficulty: difficulty ?? this.difficulty,
      stability: stability ?? this.stability,
      lastReview: lastReview ?? this.lastReview,
      due: due ?? this.due,
      lmCached: lmCached ?? this.lmCached,
      fastStreak: fastStreak ?? this.fastStreak,
      burning: burning ?? this.burning,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conceptId.present) {
      map['concept_id'] = Variable<String>(conceptId.value);
    }
    if (tier.present) {
      map['tier'] = Variable<String>(tier.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<double>(difficulty.value);
    }
    if (stability.present) {
      map['stability'] = Variable<double>(stability.value);
    }
    if (lastReview.present) {
      map['last_review'] = Variable<DateTime>(lastReview.value);
    }
    if (due.present) {
      map['due'] = Variable<DateTime>(due.value);
    }
    if (lmCached.present) {
      map['lm_cached'] = Variable<int>(lmCached.value);
    }
    if (fastStreak.present) {
      map['fast_streak'] = Variable<int>(fastStreak.value);
    }
    if (burning.present) {
      map['burning'] = Variable<bool>(burning.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (lapses.present) {
      map['lapses'] = Variable<int>(lapses.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordStatesCompanion(')
          ..write('conceptId: $conceptId, ')
          ..write('tier: $tier, ')
          ..write('difficulty: $difficulty, ')
          ..write('stability: $stability, ')
          ..write('lastReview: $lastReview, ')
          ..write('due: $due, ')
          ..write('lmCached: $lmCached, ')
          ..write('fastStreak: $fastStreak, ')
          ..write('burning: $burning, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewsTable extends Reviews with TableInfo<$ReviewsTable, ReviewRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _conceptIdMeta = const VerificationMeta(
    'conceptId',
  );
  @override
  late final GeneratedColumn<String> conceptId = GeneratedColumn<String>(
    'concept_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latencyMsMeta = const VerificationMeta(
    'latencyMs',
  );
  @override
  late final GeneratedColumn<int> latencyMs = GeneratedColumn<int>(
    'latency_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctMeta = const VerificationMeta(
    'correct',
  );
  @override
  late final GeneratedColumn<bool> correct = GeneratedColumn<bool>(
    'correct',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("correct" IN (0, 1))',
    ),
  );
  static const VerificationMeta _gradeMeta = const VerificationMeta('grade');
  @override
  late final GeneratedColumn<int> grade = GeneratedColumn<int>(
    'grade',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conceptId,
    at,
    latencyMs,
    mode,
    correct,
    grade,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reviews';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('concept_id')) {
      context.handle(
        _conceptIdMeta,
        conceptId.isAcceptableOrUnknown(data['concept_id']!, _conceptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_conceptIdMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('latency_ms')) {
      context.handle(
        _latencyMsMeta,
        latencyMs.isAcceptableOrUnknown(data['latency_ms']!, _latencyMsMeta),
      );
    } else if (isInserting) {
      context.missing(_latencyMsMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('correct')) {
      context.handle(
        _correctMeta,
        correct.isAcceptableOrUnknown(data['correct']!, _correctMeta),
      );
    } else if (isInserting) {
      context.missing(_correctMeta);
    }
    if (data.containsKey('grade')) {
      context.handle(
        _gradeMeta,
        grade.isAcceptableOrUnknown(data['grade']!, _gradeMeta),
      );
    } else if (isInserting) {
      context.missing(_gradeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReviewRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      conceptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}concept_id'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
      latencyMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latency_ms'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      correct: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}correct'],
      )!,
      grade: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grade'],
      )!,
    );
  }

  @override
  $ReviewsTable createAlias(String alias) {
    return $ReviewsTable(attachedDatabase, alias);
  }
}

class ReviewRow extends DataClass implements Insertable<ReviewRow> {
  final int id;
  final String conceptId;
  final DateTime at;
  final int latencyMs;
  final String mode;
  final bool correct;
  final int grade;
  const ReviewRow({
    required this.id,
    required this.conceptId,
    required this.at,
    required this.latencyMs,
    required this.mode,
    required this.correct,
    required this.grade,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['concept_id'] = Variable<String>(conceptId);
    map['at'] = Variable<DateTime>(at);
    map['latency_ms'] = Variable<int>(latencyMs);
    map['mode'] = Variable<String>(mode);
    map['correct'] = Variable<bool>(correct);
    map['grade'] = Variable<int>(grade);
    return map;
  }

  ReviewsCompanion toCompanion(bool nullToAbsent) {
    return ReviewsCompanion(
      id: Value(id),
      conceptId: Value(conceptId),
      at: Value(at),
      latencyMs: Value(latencyMs),
      mode: Value(mode),
      correct: Value(correct),
      grade: Value(grade),
    );
  }

  factory ReviewRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewRow(
      id: serializer.fromJson<int>(json['id']),
      conceptId: serializer.fromJson<String>(json['conceptId']),
      at: serializer.fromJson<DateTime>(json['at']),
      latencyMs: serializer.fromJson<int>(json['latencyMs']),
      mode: serializer.fromJson<String>(json['mode']),
      correct: serializer.fromJson<bool>(json['correct']),
      grade: serializer.fromJson<int>(json['grade']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'conceptId': serializer.toJson<String>(conceptId),
      'at': serializer.toJson<DateTime>(at),
      'latencyMs': serializer.toJson<int>(latencyMs),
      'mode': serializer.toJson<String>(mode),
      'correct': serializer.toJson<bool>(correct),
      'grade': serializer.toJson<int>(grade),
    };
  }

  ReviewRow copyWith({
    int? id,
    String? conceptId,
    DateTime? at,
    int? latencyMs,
    String? mode,
    bool? correct,
    int? grade,
  }) => ReviewRow(
    id: id ?? this.id,
    conceptId: conceptId ?? this.conceptId,
    at: at ?? this.at,
    latencyMs: latencyMs ?? this.latencyMs,
    mode: mode ?? this.mode,
    correct: correct ?? this.correct,
    grade: grade ?? this.grade,
  );
  ReviewRow copyWithCompanion(ReviewsCompanion data) {
    return ReviewRow(
      id: data.id.present ? data.id.value : this.id,
      conceptId: data.conceptId.present ? data.conceptId.value : this.conceptId,
      at: data.at.present ? data.at.value : this.at,
      latencyMs: data.latencyMs.present ? data.latencyMs.value : this.latencyMs,
      mode: data.mode.present ? data.mode.value : this.mode,
      correct: data.correct.present ? data.correct.value : this.correct,
      grade: data.grade.present ? data.grade.value : this.grade,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewRow(')
          ..write('id: $id, ')
          ..write('conceptId: $conceptId, ')
          ..write('at: $at, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('mode: $mode, ')
          ..write('correct: $correct, ')
          ..write('grade: $grade')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, conceptId, at, latencyMs, mode, correct, grade);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewRow &&
          other.id == this.id &&
          other.conceptId == this.conceptId &&
          other.at == this.at &&
          other.latencyMs == this.latencyMs &&
          other.mode == this.mode &&
          other.correct == this.correct &&
          other.grade == this.grade);
}

class ReviewsCompanion extends UpdateCompanion<ReviewRow> {
  final Value<int> id;
  final Value<String> conceptId;
  final Value<DateTime> at;
  final Value<int> latencyMs;
  final Value<String> mode;
  final Value<bool> correct;
  final Value<int> grade;
  const ReviewsCompanion({
    this.id = const Value.absent(),
    this.conceptId = const Value.absent(),
    this.at = const Value.absent(),
    this.latencyMs = const Value.absent(),
    this.mode = const Value.absent(),
    this.correct = const Value.absent(),
    this.grade = const Value.absent(),
  });
  ReviewsCompanion.insert({
    this.id = const Value.absent(),
    required String conceptId,
    required DateTime at,
    required int latencyMs,
    required String mode,
    required bool correct,
    required int grade,
  }) : conceptId = Value(conceptId),
       at = Value(at),
       latencyMs = Value(latencyMs),
       mode = Value(mode),
       correct = Value(correct),
       grade = Value(grade);
  static Insertable<ReviewRow> custom({
    Expression<int>? id,
    Expression<String>? conceptId,
    Expression<DateTime>? at,
    Expression<int>? latencyMs,
    Expression<String>? mode,
    Expression<bool>? correct,
    Expression<int>? grade,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conceptId != null) 'concept_id': conceptId,
      if (at != null) 'at': at,
      if (latencyMs != null) 'latency_ms': latencyMs,
      if (mode != null) 'mode': mode,
      if (correct != null) 'correct': correct,
      if (grade != null) 'grade': grade,
    });
  }

  ReviewsCompanion copyWith({
    Value<int>? id,
    Value<String>? conceptId,
    Value<DateTime>? at,
    Value<int>? latencyMs,
    Value<String>? mode,
    Value<bool>? correct,
    Value<int>? grade,
  }) {
    return ReviewsCompanion(
      id: id ?? this.id,
      conceptId: conceptId ?? this.conceptId,
      at: at ?? this.at,
      latencyMs: latencyMs ?? this.latencyMs,
      mode: mode ?? this.mode,
      correct: correct ?? this.correct,
      grade: grade ?? this.grade,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (conceptId.present) {
      map['concept_id'] = Variable<String>(conceptId.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (latencyMs.present) {
      map['latency_ms'] = Variable<int>(latencyMs.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (correct.present) {
      map['correct'] = Variable<bool>(correct.value);
    }
    if (grade.present) {
      map['grade'] = Variable<int>(grade.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewsCompanion(')
          ..write('id: $id, ')
          ..write('conceptId: $conceptId, ')
          ..write('at: $at, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('mode: $mode, ')
          ..write('correct: $correct, ')
          ..write('grade: $grade')
          ..write(')'))
        .toString();
  }
}

class $ConstellationProgressTable extends ConstellationProgress
    with TableInfo<$ConstellationProgressTable, ConstellationProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConstellationProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _constellationMeta = const VerificationMeta(
    'constellation',
  );
  @override
  late final GeneratedColumn<String> constellation = GeneratedColumn<String>(
    'constellation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tierMeta = const VerificationMeta('tier');
  @override
  late final GeneratedColumn<String> tier = GeneratedColumn<String>(
    'tier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unlockedMeta = const VerificationMeta(
    'unlocked',
  );
  @override
  late final GeneratedColumn<bool> unlocked = GeneratedColumn<bool>(
    'unlocked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("unlocked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _litMeta = const VerificationMeta('lit');
  @override
  late final GeneratedColumn<bool> lit = GeneratedColumn<bool>(
    'lit',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("lit" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _levelsDoneMeta = const VerificationMeta(
    'levelsDone',
  );
  @override
  late final GeneratedColumn<int> levelsDone = GeneratedColumn<int>(
    'levels_done',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    constellation,
    tier,
    unlocked,
    lit,
    levelsDone,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'constellation_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConstellationProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('constellation')) {
      context.handle(
        _constellationMeta,
        constellation.isAcceptableOrUnknown(
          data['constellation']!,
          _constellationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_constellationMeta);
    }
    if (data.containsKey('tier')) {
      context.handle(
        _tierMeta,
        tier.isAcceptableOrUnknown(data['tier']!, _tierMeta),
      );
    } else if (isInserting) {
      context.missing(_tierMeta);
    }
    if (data.containsKey('unlocked')) {
      context.handle(
        _unlockedMeta,
        unlocked.isAcceptableOrUnknown(data['unlocked']!, _unlockedMeta),
      );
    }
    if (data.containsKey('lit')) {
      context.handle(
        _litMeta,
        lit.isAcceptableOrUnknown(data['lit']!, _litMeta),
      );
    }
    if (data.containsKey('levels_done')) {
      context.handle(
        _levelsDoneMeta,
        levelsDone.isAcceptableOrUnknown(data['levels_done']!, _levelsDoneMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {constellation, tier};
  @override
  ConstellationProgressRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConstellationProgressRow(
      constellation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}constellation'],
      )!,
      tier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tier'],
      )!,
      unlocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}unlocked'],
      )!,
      lit: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}lit'],
      )!,
      levelsDone: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}levels_done'],
      )!,
    );
  }

  @override
  $ConstellationProgressTable createAlias(String alias) {
    return $ConstellationProgressTable(attachedDatabase, alias);
  }
}

class ConstellationProgressRow extends DataClass
    implements Insertable<ConstellationProgressRow> {
  final String constellation;
  final String tier;
  final bool unlocked;
  final bool lit;
  final int levelsDone;
  const ConstellationProgressRow({
    required this.constellation,
    required this.tier,
    required this.unlocked,
    required this.lit,
    required this.levelsDone,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['constellation'] = Variable<String>(constellation);
    map['tier'] = Variable<String>(tier);
    map['unlocked'] = Variable<bool>(unlocked);
    map['lit'] = Variable<bool>(lit);
    map['levels_done'] = Variable<int>(levelsDone);
    return map;
  }

  ConstellationProgressCompanion toCompanion(bool nullToAbsent) {
    return ConstellationProgressCompanion(
      constellation: Value(constellation),
      tier: Value(tier),
      unlocked: Value(unlocked),
      lit: Value(lit),
      levelsDone: Value(levelsDone),
    );
  }

  factory ConstellationProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConstellationProgressRow(
      constellation: serializer.fromJson<String>(json['constellation']),
      tier: serializer.fromJson<String>(json['tier']),
      unlocked: serializer.fromJson<bool>(json['unlocked']),
      lit: serializer.fromJson<bool>(json['lit']),
      levelsDone: serializer.fromJson<int>(json['levelsDone']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'constellation': serializer.toJson<String>(constellation),
      'tier': serializer.toJson<String>(tier),
      'unlocked': serializer.toJson<bool>(unlocked),
      'lit': serializer.toJson<bool>(lit),
      'levelsDone': serializer.toJson<int>(levelsDone),
    };
  }

  ConstellationProgressRow copyWith({
    String? constellation,
    String? tier,
    bool? unlocked,
    bool? lit,
    int? levelsDone,
  }) => ConstellationProgressRow(
    constellation: constellation ?? this.constellation,
    tier: tier ?? this.tier,
    unlocked: unlocked ?? this.unlocked,
    lit: lit ?? this.lit,
    levelsDone: levelsDone ?? this.levelsDone,
  );
  ConstellationProgressRow copyWithCompanion(
    ConstellationProgressCompanion data,
  ) {
    return ConstellationProgressRow(
      constellation: data.constellation.present
          ? data.constellation.value
          : this.constellation,
      tier: data.tier.present ? data.tier.value : this.tier,
      unlocked: data.unlocked.present ? data.unlocked.value : this.unlocked,
      lit: data.lit.present ? data.lit.value : this.lit,
      levelsDone: data.levelsDone.present
          ? data.levelsDone.value
          : this.levelsDone,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConstellationProgressRow(')
          ..write('constellation: $constellation, ')
          ..write('tier: $tier, ')
          ..write('unlocked: $unlocked, ')
          ..write('lit: $lit, ')
          ..write('levelsDone: $levelsDone')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(constellation, tier, unlocked, lit, levelsDone);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConstellationProgressRow &&
          other.constellation == this.constellation &&
          other.tier == this.tier &&
          other.unlocked == this.unlocked &&
          other.lit == this.lit &&
          other.levelsDone == this.levelsDone);
}

class ConstellationProgressCompanion
    extends UpdateCompanion<ConstellationProgressRow> {
  final Value<String> constellation;
  final Value<String> tier;
  final Value<bool> unlocked;
  final Value<bool> lit;
  final Value<int> levelsDone;
  final Value<int> rowid;
  const ConstellationProgressCompanion({
    this.constellation = const Value.absent(),
    this.tier = const Value.absent(),
    this.unlocked = const Value.absent(),
    this.lit = const Value.absent(),
    this.levelsDone = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConstellationProgressCompanion.insert({
    required String constellation,
    required String tier,
    this.unlocked = const Value.absent(),
    this.lit = const Value.absent(),
    this.levelsDone = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : constellation = Value(constellation),
       tier = Value(tier);
  static Insertable<ConstellationProgressRow> custom({
    Expression<String>? constellation,
    Expression<String>? tier,
    Expression<bool>? unlocked,
    Expression<bool>? lit,
    Expression<int>? levelsDone,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (constellation != null) 'constellation': constellation,
      if (tier != null) 'tier': tier,
      if (unlocked != null) 'unlocked': unlocked,
      if (lit != null) 'lit': lit,
      if (levelsDone != null) 'levels_done': levelsDone,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConstellationProgressCompanion copyWith({
    Value<String>? constellation,
    Value<String>? tier,
    Value<bool>? unlocked,
    Value<bool>? lit,
    Value<int>? levelsDone,
    Value<int>? rowid,
  }) {
    return ConstellationProgressCompanion(
      constellation: constellation ?? this.constellation,
      tier: tier ?? this.tier,
      unlocked: unlocked ?? this.unlocked,
      lit: lit ?? this.lit,
      levelsDone: levelsDone ?? this.levelsDone,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (constellation.present) {
      map['constellation'] = Variable<String>(constellation.value);
    }
    if (tier.present) {
      map['tier'] = Variable<String>(tier.value);
    }
    if (unlocked.present) {
      map['unlocked'] = Variable<bool>(unlocked.value);
    }
    if (lit.present) {
      map['lit'] = Variable<bool>(lit.value);
    }
    if (levelsDone.present) {
      map['levels_done'] = Variable<int>(levelsDone.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConstellationProgressCompanion(')
          ..write('constellation: $constellation, ')
          ..write('tier: $tier, ')
          ..write('unlocked: $unlocked, ')
          ..write('lit: $lit, ')
          ..write('levelsDone: $levelsDone, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions
    with TableInfo<$SessionsTable, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lmGainedMeta = const VerificationMeta(
    'lmGained',
  );
  @override
  late final GeneratedColumn<int> lmGained = GeneratedColumn<int>(
    'lm_gained',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _newWordsMeta = const VerificationMeta(
    'newWords',
  );
  @override
  late final GeneratedColumn<int> newWords = GeneratedColumn<int>(
    'new_words',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    durationMs,
    lmGained,
    score,
    newWords,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('lm_gained')) {
      context.handle(
        _lmGainedMeta,
        lmGained.isAcceptableOrUnknown(data['lm_gained']!, _lmGainedMeta),
      );
    } else if (isInserting) {
      context.missing(_lmGainedMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('new_words')) {
      context.handle(
        _newWordsMeta,
        newWords.isAcceptableOrUnknown(data['new_words']!, _newWordsMeta),
      );
    } else if (isInserting) {
      context.missing(_newWordsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      lmGained: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lm_gained'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score'],
      )!,
      newWords: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}new_words'],
      )!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final int id;
  final DateTime startedAt;
  final int durationMs;
  final int lmGained;
  final int score;
  final int newWords;
  const SessionRow({
    required this.id,
    required this.startedAt,
    required this.durationMs,
    required this.lmGained,
    required this.score,
    required this.newWords,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['duration_ms'] = Variable<int>(durationMs);
    map['lm_gained'] = Variable<int>(lmGained);
    map['score'] = Variable<int>(score);
    map['new_words'] = Variable<int>(newWords);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      durationMs: Value(durationMs),
      lmGained: Value(lmGained),
      score: Value(score),
      newWords: Value(newWords),
    );
  }

  factory SessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      id: serializer.fromJson<int>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      lmGained: serializer.fromJson<int>(json['lmGained']),
      score: serializer.fromJson<int>(json['score']),
      newWords: serializer.fromJson<int>(json['newWords']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'durationMs': serializer.toJson<int>(durationMs),
      'lmGained': serializer.toJson<int>(lmGained),
      'score': serializer.toJson<int>(score),
      'newWords': serializer.toJson<int>(newWords),
    };
  }

  SessionRow copyWith({
    int? id,
    DateTime? startedAt,
    int? durationMs,
    int? lmGained,
    int? score,
    int? newWords,
  }) => SessionRow(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    durationMs: durationMs ?? this.durationMs,
    lmGained: lmGained ?? this.lmGained,
    score: score ?? this.score,
    newWords: newWords ?? this.newWords,
  );
  SessionRow copyWithCompanion(SessionsCompanion data) {
    return SessionRow(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      lmGained: data.lmGained.present ? data.lmGained.value : this.lmGained,
      score: data.score.present ? data.score.value : this.score,
      newWords: data.newWords.present ? data.newWords.value : this.newWords,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('lmGained: $lmGained, ')
          ..write('score: $score, ')
          ..write('newWords: $newWords')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, startedAt, durationMs, lmGained, score, newWords);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.durationMs == this.durationMs &&
          other.lmGained == this.lmGained &&
          other.score == this.score &&
          other.newWords == this.newWords);
}

class SessionsCompanion extends UpdateCompanion<SessionRow> {
  final Value<int> id;
  final Value<DateTime> startedAt;
  final Value<int> durationMs;
  final Value<int> lmGained;
  final Value<int> score;
  final Value<int> newWords;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.lmGained = const Value.absent(),
    this.score = const Value.absent(),
    this.newWords = const Value.absent(),
  });
  SessionsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime startedAt,
    required int durationMs,
    required int lmGained,
    required int score,
    required int newWords,
  }) : startedAt = Value(startedAt),
       durationMs = Value(durationMs),
       lmGained = Value(lmGained),
       score = Value(score),
       newWords = Value(newWords);
  static Insertable<SessionRow> custom({
    Expression<int>? id,
    Expression<DateTime>? startedAt,
    Expression<int>? durationMs,
    Expression<int>? lmGained,
    Expression<int>? score,
    Expression<int>? newWords,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (lmGained != null) 'lm_gained': lmGained,
      if (score != null) 'score': score,
      if (newWords != null) 'new_words': newWords,
    });
  }

  SessionsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? startedAt,
    Value<int>? durationMs,
    Value<int>? lmGained,
    Value<int>? score,
    Value<int>? newWords,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      durationMs: durationMs ?? this.durationMs,
      lmGained: lmGained ?? this.lmGained,
      score: score ?? this.score,
      newWords: newWords ?? this.newWords,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (lmGained.present) {
      map['lm_gained'] = Variable<int>(lmGained.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (newWords.present) {
      map['new_words'] = Variable<int>(newWords.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('lmGained: $lmGained, ')
          ..write('score: $score, ')
          ..write('newWords: $newWords')
          ..write(')'))
        .toString();
  }
}

class $DailyChallengeResultsTable extends DailyChallengeResults
    with TableInfo<$DailyChallengeResultsTable, DailyChallengeResultRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyChallengeResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctMeta = const VerificationMeta(
    'correct',
  );
  @override
  late final GeneratedColumn<int> correct = GeneratedColumn<int>(
    'correct',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeMsMeta = const VerificationMeta('timeMs');
  @override
  late final GeneratedColumn<int> timeMs = GeneratedColumn<int>(
    'time_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [day, correct, total, timeMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_challenge_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyChallengeResultRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('correct')) {
      context.handle(
        _correctMeta,
        correct.isAcceptableOrUnknown(data['correct']!, _correctMeta),
      );
    } else if (isInserting) {
      context.missing(_correctMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('time_ms')) {
      context.handle(
        _timeMsMeta,
        timeMs.isAcceptableOrUnknown(data['time_ms']!, _timeMsMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day};
  @override
  DailyChallengeResultRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyChallengeResultRow(
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      correct: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      timeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_ms'],
      )!,
    );
  }

  @override
  $DailyChallengeResultsTable createAlias(String alias) {
    return $DailyChallengeResultsTable(attachedDatabase, alias);
  }
}

class DailyChallengeResultRow extends DataClass
    implements Insertable<DailyChallengeResultRow> {
  final String day;
  final int correct;
  final int total;
  final int timeMs;
  const DailyChallengeResultRow({
    required this.day,
    required this.correct,
    required this.total,
    required this.timeMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day'] = Variable<String>(day);
    map['correct'] = Variable<int>(correct);
    map['total'] = Variable<int>(total);
    map['time_ms'] = Variable<int>(timeMs);
    return map;
  }

  DailyChallengeResultsCompanion toCompanion(bool nullToAbsent) {
    return DailyChallengeResultsCompanion(
      day: Value(day),
      correct: Value(correct),
      total: Value(total),
      timeMs: Value(timeMs),
    );
  }

  factory DailyChallengeResultRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyChallengeResultRow(
      day: serializer.fromJson<String>(json['day']),
      correct: serializer.fromJson<int>(json['correct']),
      total: serializer.fromJson<int>(json['total']),
      timeMs: serializer.fromJson<int>(json['timeMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<String>(day),
      'correct': serializer.toJson<int>(correct),
      'total': serializer.toJson<int>(total),
      'timeMs': serializer.toJson<int>(timeMs),
    };
  }

  DailyChallengeResultRow copyWith({
    String? day,
    int? correct,
    int? total,
    int? timeMs,
  }) => DailyChallengeResultRow(
    day: day ?? this.day,
    correct: correct ?? this.correct,
    total: total ?? this.total,
    timeMs: timeMs ?? this.timeMs,
  );
  DailyChallengeResultRow copyWithCompanion(
    DailyChallengeResultsCompanion data,
  ) {
    return DailyChallengeResultRow(
      day: data.day.present ? data.day.value : this.day,
      correct: data.correct.present ? data.correct.value : this.correct,
      total: data.total.present ? data.total.value : this.total,
      timeMs: data.timeMs.present ? data.timeMs.value : this.timeMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyChallengeResultRow(')
          ..write('day: $day, ')
          ..write('correct: $correct, ')
          ..write('total: $total, ')
          ..write('timeMs: $timeMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(day, correct, total, timeMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyChallengeResultRow &&
          other.day == this.day &&
          other.correct == this.correct &&
          other.total == this.total &&
          other.timeMs == this.timeMs);
}

class DailyChallengeResultsCompanion
    extends UpdateCompanion<DailyChallengeResultRow> {
  final Value<String> day;
  final Value<int> correct;
  final Value<int> total;
  final Value<int> timeMs;
  final Value<int> rowid;
  const DailyChallengeResultsCompanion({
    this.day = const Value.absent(),
    this.correct = const Value.absent(),
    this.total = const Value.absent(),
    this.timeMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyChallengeResultsCompanion.insert({
    required String day,
    required int correct,
    required int total,
    required int timeMs,
    this.rowid = const Value.absent(),
  }) : day = Value(day),
       correct = Value(correct),
       total = Value(total),
       timeMs = Value(timeMs);
  static Insertable<DailyChallengeResultRow> custom({
    Expression<String>? day,
    Expression<int>? correct,
    Expression<int>? total,
    Expression<int>? timeMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (correct != null) 'correct': correct,
      if (total != null) 'total': total,
      if (timeMs != null) 'time_ms': timeMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyChallengeResultsCompanion copyWith({
    Value<String>? day,
    Value<int>? correct,
    Value<int>? total,
    Value<int>? timeMs,
    Value<int>? rowid,
  }) {
    return DailyChallengeResultsCompanion(
      day: day ?? this.day,
      correct: correct ?? this.correct,
      total: total ?? this.total,
      timeMs: timeMs ?? this.timeMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (correct.present) {
      map['correct'] = Variable<int>(correct.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (timeMs.present) {
      map['time_ms'] = Variable<int>(timeMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyChallengeResultsCompanion(')
          ..write('day: $day, ')
          ..write('correct: $correct, ')
          ..write('total: $total, ')
          ..write('timeMs: $timeMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CustomConceptsTable extends CustomConcepts
    with TableInfo<$CustomConceptsTable, CustomConceptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomConceptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<String> target = GeneratedColumn<String>(
    'target',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nativeMeta = const VerificationMeta('native');
  @override
  late final GeneratedColumn<String> native = GeneratedColumn<String>(
    'native',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deckMeta = const VerificationMeta('deck');
  @override
  late final GeneratedColumn<String> deck = GeneratedColumn<String>(
    'deck',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, target, native, deck];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'custom_concepts';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomConceptRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('target')) {
      context.handle(
        _targetMeta,
        target.isAcceptableOrUnknown(data['target']!, _targetMeta),
      );
    } else if (isInserting) {
      context.missing(_targetMeta);
    }
    if (data.containsKey('native')) {
      context.handle(
        _nativeMeta,
        native.isAcceptableOrUnknown(data['native']!, _nativeMeta),
      );
    } else if (isInserting) {
      context.missing(_nativeMeta);
    }
    if (data.containsKey('deck')) {
      context.handle(
        _deckMeta,
        deck.isAcceptableOrUnknown(data['deck']!, _deckMeta),
      );
    } else if (isInserting) {
      context.missing(_deckMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CustomConceptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomConceptRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      target: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target'],
      )!,
      native: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}native'],
      )!,
      deck: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deck'],
      )!,
    );
  }

  @override
  $CustomConceptsTable createAlias(String alias) {
    return $CustomConceptsTable(attachedDatabase, alias);
  }
}

class CustomConceptRow extends DataClass
    implements Insertable<CustomConceptRow> {
  final String id;
  final String target;
  final String native;
  final String deck;
  const CustomConceptRow({
    required this.id,
    required this.target,
    required this.native,
    required this.deck,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['target'] = Variable<String>(target);
    map['native'] = Variable<String>(native);
    map['deck'] = Variable<String>(deck);
    return map;
  }

  CustomConceptsCompanion toCompanion(bool nullToAbsent) {
    return CustomConceptsCompanion(
      id: Value(id),
      target: Value(target),
      native: Value(native),
      deck: Value(deck),
    );
  }

  factory CustomConceptRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomConceptRow(
      id: serializer.fromJson<String>(json['id']),
      target: serializer.fromJson<String>(json['target']),
      native: serializer.fromJson<String>(json['native']),
      deck: serializer.fromJson<String>(json['deck']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'target': serializer.toJson<String>(target),
      'native': serializer.toJson<String>(native),
      'deck': serializer.toJson<String>(deck),
    };
  }

  CustomConceptRow copyWith({
    String? id,
    String? target,
    String? native,
    String? deck,
  }) => CustomConceptRow(
    id: id ?? this.id,
    target: target ?? this.target,
    native: native ?? this.native,
    deck: deck ?? this.deck,
  );
  CustomConceptRow copyWithCompanion(CustomConceptsCompanion data) {
    return CustomConceptRow(
      id: data.id.present ? data.id.value : this.id,
      target: data.target.present ? data.target.value : this.target,
      native: data.native.present ? data.native.value : this.native,
      deck: data.deck.present ? data.deck.value : this.deck,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomConceptRow(')
          ..write('id: $id, ')
          ..write('target: $target, ')
          ..write('native: $native, ')
          ..write('deck: $deck')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, target, native, deck);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomConceptRow &&
          other.id == this.id &&
          other.target == this.target &&
          other.native == this.native &&
          other.deck == this.deck);
}

class CustomConceptsCompanion extends UpdateCompanion<CustomConceptRow> {
  final Value<String> id;
  final Value<String> target;
  final Value<String> native;
  final Value<String> deck;
  final Value<int> rowid;
  const CustomConceptsCompanion({
    this.id = const Value.absent(),
    this.target = const Value.absent(),
    this.native = const Value.absent(),
    this.deck = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomConceptsCompanion.insert({
    required String id,
    required String target,
    required String native,
    required String deck,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       target = Value(target),
       native = Value(native),
       deck = Value(deck);
  static Insertable<CustomConceptRow> custom({
    Expression<String>? id,
    Expression<String>? target,
    Expression<String>? native,
    Expression<String>? deck,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (target != null) 'target': target,
      if (native != null) 'native': native,
      if (deck != null) 'deck': deck,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomConceptsCompanion copyWith({
    Value<String>? id,
    Value<String>? target,
    Value<String>? native,
    Value<String>? deck,
    Value<int>? rowid,
  }) {
    return CustomConceptsCompanion(
      id: id ?? this.id,
      target: target ?? this.target,
      native: native ?? this.native,
      deck: deck ?? this.deck,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(target.value);
    }
    if (native.present) {
      map['native'] = Variable<String>(native.value);
    }
    if (deck.present) {
      map['deck'] = Variable<String>(deck.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomConceptsCompanion(')
          ..write('id: $id, ')
          ..write('target: $target, ')
          ..write('native: $native, ')
          ..write('deck: $deck, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PlayersTable players = $PlayersTable(this);
  late final $WordStatesTable wordStates = $WordStatesTable(this);
  late final $ReviewsTable reviews = $ReviewsTable(this);
  late final $ConstellationProgressTable constellationProgress =
      $ConstellationProgressTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $DailyChallengeResultsTable dailyChallengeResults =
      $DailyChallengeResultsTable(this);
  late final $CustomConceptsTable customConcepts = $CustomConceptsTable(this);
  late final Index wordStatesDueLm = Index(
    'word_states_due_lm',
    'CREATE INDEX word_states_due_lm ON word_states (due, lm_cached)',
  );
  late final Index reviewsAt = Index(
    'reviews_at',
    'CREATE INDEX reviews_at ON reviews (at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    players,
    wordStates,
    reviews,
    constellationProgress,
    sessions,
    dailyChallengeResults,
    customConcepts,
    wordStatesDueLm,
    reviewsAt,
  ];
}

typedef $$PlayersTableCreateCompanionBuilder = PlayersCompanion Function({
  Value<int> id,
  required String targetLang,
  required String nativeLang,
  Value<String?> uiLang,
  required String tier,
  Value<bool> calibrated,
  Value<int> orbit,
  Value<int> sparks,
  Value<DateTime?> lastPlayedAt,
  Value<int> missedInRow,
  Value<bool> freePace,
  Value<bool> soundEnabled,
});
typedef $$PlayersTableUpdateCompanionBuilder = PlayersCompanion Function({
  Value<int> id,
  Value<String> targetLang,
  Value<String> nativeLang,
  Value<String?> uiLang,
  Value<String> tier,
  Value<bool> calibrated,
  Value<int> orbit,
  Value<int> sparks,
  Value<DateTime?> lastPlayedAt,
  Value<int> missedInRow,
  Value<bool> freePace,
  Value<bool> soundEnabled,
});

class $$PlayersTableFilterComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetLang => $composableBuilder(
    column: $table.targetLang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nativeLang => $composableBuilder(
    column: $table.nativeLang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uiLang => $composableBuilder(
    column: $table.uiLang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get calibrated => $composableBuilder(
    column: $table.calibrated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orbit => $composableBuilder(
    column: $table.orbit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sparks => $composableBuilder(
    column: $table.sparks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get missedInRow => $composableBuilder(
    column: $table.missedInRow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get freePace => $composableBuilder(
    column: $table.freePace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get soundEnabled => $composableBuilder(
    column: $table.soundEnabled,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlayersTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetLang => $composableBuilder(
    column: $table.targetLang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nativeLang => $composableBuilder(
    column: $table.nativeLang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uiLang => $composableBuilder(
    column: $table.uiLang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get calibrated => $composableBuilder(
    column: $table.calibrated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orbit => $composableBuilder(
    column: $table.orbit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sparks => $composableBuilder(
    column: $table.sparks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get missedInRow => $composableBuilder(
    column: $table.missedInRow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get freePace => $composableBuilder(
    column: $table.freePace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get soundEnabled => $composableBuilder(
    column: $table.soundEnabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlayersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get targetLang => $composableBuilder(
    column: $table.targetLang,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nativeLang => $composableBuilder(
    column: $table.nativeLang,
    builder: (column) => column,
  );

  GeneratedColumn<String> get uiLang =>
      $composableBuilder(column: $table.uiLang, builder: (column) => column);

  GeneratedColumn<String> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  GeneratedColumn<bool> get calibrated => $composableBuilder(
    column: $table.calibrated,
    builder: (column) => column,
  );

  GeneratedColumn<int> get orbit =>
      $composableBuilder(column: $table.orbit, builder: (column) => column);

  GeneratedColumn<int> get sparks =>
      $composableBuilder(column: $table.sparks, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get missedInRow => $composableBuilder(
    column: $table.missedInRow,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get freePace =>
      $composableBuilder(column: $table.freePace, builder: (column) => column);

  GeneratedColumn<bool> get soundEnabled => $composableBuilder(
    column: $table.soundEnabled,
    builder: (column) => column,
  );
}

class $$PlayersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayersTable,
          PlayerRow,
          $$PlayersTableFilterComposer,
          $$PlayersTableOrderingComposer,
          $$PlayersTableAnnotationComposer,
          $$PlayersTableCreateCompanionBuilder,
          $$PlayersTableUpdateCompanionBuilder,
          (PlayerRow, BaseReferences<_$AppDatabase, $PlayersTable, PlayerRow>),
          PlayerRow,
          PrefetchHooks Function()
        > {
  $$PlayersTableTableManager(_$AppDatabase db, $PlayersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> targetLang = const Value.absent(),
                Value<String> nativeLang = const Value.absent(),
                Value<String?> uiLang = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<bool> calibrated = const Value.absent(),
                Value<int> orbit = const Value.absent(),
                Value<int> sparks = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<int> missedInRow = const Value.absent(),
                Value<bool> freePace = const Value.absent(),
                Value<bool> soundEnabled = const Value.absent(),
              }) => PlayersCompanion(
                id: id,
                targetLang: targetLang,
                nativeLang: nativeLang,
                uiLang: uiLang,
                tier: tier,
                calibrated: calibrated,
                orbit: orbit,
                sparks: sparks,
                lastPlayedAt: lastPlayedAt,
                missedInRow: missedInRow,
                freePace: freePace,
                soundEnabled: soundEnabled,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String targetLang,
                required String nativeLang,
                Value<String?> uiLang = const Value.absent(),
                required String tier,
                Value<bool> calibrated = const Value.absent(),
                Value<int> orbit = const Value.absent(),
                Value<int> sparks = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<int> missedInRow = const Value.absent(),
                Value<bool> freePace = const Value.absent(),
                Value<bool> soundEnabled = const Value.absent(),
              }) => PlayersCompanion.insert(
                id: id,
                targetLang: targetLang,
                nativeLang: nativeLang,
                uiLang: uiLang,
                tier: tier,
                calibrated: calibrated,
                orbit: orbit,
                sparks: sparks,
                lastPlayedAt: lastPlayedAt,
                missedInRow: missedInRow,
                freePace: freePace,
                soundEnabled: soundEnabled,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlayersTable, PlayerRow>(table),
                  BaseReferences<_$AppDatabase, $PlayersTable, PlayerRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlayersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayersTable,
      PlayerRow,
      $$PlayersTableFilterComposer,
      $$PlayersTableOrderingComposer,
      $$PlayersTableAnnotationComposer,
      $$PlayersTableCreateCompanionBuilder,
      $$PlayersTableUpdateCompanionBuilder,
      (PlayerRow, BaseReferences<_$AppDatabase, $PlayersTable, PlayerRow>),
      PlayerRow,
      PrefetchHooks Function()
    >;
typedef $$WordStatesTableCreateCompanionBuilder = WordStatesCompanion Function({
  required String conceptId,
  required String tier,
  required double difficulty,
  required double stability,
  Value<DateTime?> lastReview,
  Value<DateTime?> due,
  Value<int> lmCached,
  Value<int> fastStreak,
  Value<bool> burning,
  Value<int> reps,
  Value<int> lapses,
  Value<int> rowid,
});
typedef $$WordStatesTableUpdateCompanionBuilder = WordStatesCompanion Function({
  Value<String> conceptId,
  Value<String> tier,
  Value<double> difficulty,
  Value<double> stability,
  Value<DateTime?> lastReview,
  Value<DateTime?> due,
  Value<int> lmCached,
  Value<int> fastStreak,
  Value<bool> burning,
  Value<int> reps,
  Value<int> lapses,
  Value<int> rowid,
});

class $$WordStatesTableFilterComposer
    extends Composer<_$AppDatabase, $WordStatesTable> {
  $$WordStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get conceptId => $composableBuilder(
    column: $table.conceptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stability => $composableBuilder(
    column: $table.stability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReview => $composableBuilder(
    column: $table.lastReview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get due => $composableBuilder(
    column: $table.due,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lmCached => $composableBuilder(
    column: $table.lmCached,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fastStreak => $composableBuilder(
    column: $table.fastStreak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get burning => $composableBuilder(
    column: $table.burning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WordStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $WordStatesTable> {
  $$WordStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get conceptId => $composableBuilder(
    column: $table.conceptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stability => $composableBuilder(
    column: $table.stability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReview => $composableBuilder(
    column: $table.lastReview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get due => $composableBuilder(
    column: $table.due,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lmCached => $composableBuilder(
    column: $table.lmCached,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fastStreak => $composableBuilder(
    column: $table.fastStreak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get burning => $composableBuilder(
    column: $table.burning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WordStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WordStatesTable> {
  $$WordStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get conceptId =>
      $composableBuilder(column: $table.conceptId, builder: (column) => column);

  GeneratedColumn<String> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  GeneratedColumn<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<double> get stability =>
      $composableBuilder(column: $table.stability, builder: (column) => column);

  GeneratedColumn<DateTime> get lastReview => $composableBuilder(
    column: $table.lastReview,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get due =>
      $composableBuilder(column: $table.due, builder: (column) => column);

  GeneratedColumn<int> get lmCached =>
      $composableBuilder(column: $table.lmCached, builder: (column) => column);

  GeneratedColumn<int> get fastStreak => $composableBuilder(
    column: $table.fastStreak,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get burning =>
      $composableBuilder(column: $table.burning, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get lapses =>
      $composableBuilder(column: $table.lapses, builder: (column) => column);
}

class $$WordStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WordStatesTable,
          WordStateRow,
          $$WordStatesTableFilterComposer,
          $$WordStatesTableOrderingComposer,
          $$WordStatesTableAnnotationComposer,
          $$WordStatesTableCreateCompanionBuilder,
          $$WordStatesTableUpdateCompanionBuilder,
          (
            WordStateRow,
            BaseReferences<_$AppDatabase, $WordStatesTable, WordStateRow>,
          ),
          WordStateRow,
          PrefetchHooks Function()
        > {
  $$WordStatesTableTableManager(_$AppDatabase db, $WordStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> conceptId = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<double> difficulty = const Value.absent(),
                Value<double> stability = const Value.absent(),
                Value<DateTime?> lastReview = const Value.absent(),
                Value<DateTime?> due = const Value.absent(),
                Value<int> lmCached = const Value.absent(),
                Value<int> fastStreak = const Value.absent(),
                Value<bool> burning = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordStatesCompanion(
                conceptId: conceptId,
                tier: tier,
                difficulty: difficulty,
                stability: stability,
                lastReview: lastReview,
                due: due,
                lmCached: lmCached,
                fastStreak: fastStreak,
                burning: burning,
                reps: reps,
                lapses: lapses,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String conceptId,
                required String tier,
                required double difficulty,
                required double stability,
                Value<DateTime?> lastReview = const Value.absent(),
                Value<DateTime?> due = const Value.absent(),
                Value<int> lmCached = const Value.absent(),
                Value<int> fastStreak = const Value.absent(),
                Value<bool> burning = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordStatesCompanion.insert(
                conceptId: conceptId,
                tier: tier,
                difficulty: difficulty,
                stability: stability,
                lastReview: lastReview,
                due: due,
                lmCached: lmCached,
                fastStreak: fastStreak,
                burning: burning,
                reps: reps,
                lapses: lapses,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WordStatesTable, WordStateRow>(table),
                  BaseReferences<_$AppDatabase, $WordStatesTable, WordStateRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WordStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WordStatesTable,
      WordStateRow,
      $$WordStatesTableFilterComposer,
      $$WordStatesTableOrderingComposer,
      $$WordStatesTableAnnotationComposer,
      $$WordStatesTableCreateCompanionBuilder,
      $$WordStatesTableUpdateCompanionBuilder,
      (
        WordStateRow,
        BaseReferences<_$AppDatabase, $WordStatesTable, WordStateRow>,
      ),
      WordStateRow,
      PrefetchHooks Function()
    >;
typedef $$ReviewsTableCreateCompanionBuilder = ReviewsCompanion Function({
  Value<int> id,
  required String conceptId,
  required DateTime at,
  required int latencyMs,
  required String mode,
  required bool correct,
  required int grade,
});
typedef $$ReviewsTableUpdateCompanionBuilder = ReviewsCompanion Function({
  Value<int> id,
  Value<String> conceptId,
  Value<DateTime> at,
  Value<int> latencyMs,
  Value<String> mode,
  Value<bool> correct,
  Value<int> grade,
});

class $$ReviewsTableFilterComposer
    extends Composer<_$AppDatabase, $ReviewsTable> {
  $$ReviewsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conceptId => $composableBuilder(
    column: $table.conceptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get latencyMs => $composableBuilder(
    column: $table.latencyMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get grade => $composableBuilder(
    column: $table.grade,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReviewsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReviewsTable> {
  $$ReviewsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conceptId => $composableBuilder(
    column: $table.conceptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get latencyMs => $composableBuilder(
    column: $table.latencyMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get grade => $composableBuilder(
    column: $table.grade,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReviewsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReviewsTable> {
  $$ReviewsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conceptId =>
      $composableBuilder(column: $table.conceptId, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<int> get latencyMs =>
      $composableBuilder(column: $table.latencyMs, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<bool> get correct =>
      $composableBuilder(column: $table.correct, builder: (column) => column);

  GeneratedColumn<int> get grade =>
      $composableBuilder(column: $table.grade, builder: (column) => column);
}

class $$ReviewsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReviewsTable,
          ReviewRow,
          $$ReviewsTableFilterComposer,
          $$ReviewsTableOrderingComposer,
          $$ReviewsTableAnnotationComposer,
          $$ReviewsTableCreateCompanionBuilder,
          $$ReviewsTableUpdateCompanionBuilder,
          (ReviewRow, BaseReferences<_$AppDatabase, $ReviewsTable, ReviewRow>),
          ReviewRow,
          PrefetchHooks Function()
        > {
  $$ReviewsTableTableManager(_$AppDatabase db, $ReviewsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> conceptId = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<int> latencyMs = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<bool> correct = const Value.absent(),
                Value<int> grade = const Value.absent(),
              }) => ReviewsCompanion(
                id: id,
                conceptId: conceptId,
                at: at,
                latencyMs: latencyMs,
                mode: mode,
                correct: correct,
                grade: grade,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String conceptId,
                required DateTime at,
                required int latencyMs,
                required String mode,
                required bool correct,
                required int grade,
              }) => ReviewsCompanion.insert(
                id: id,
                conceptId: conceptId,
                at: at,
                latencyMs: latencyMs,
                mode: mode,
                correct: correct,
                grade: grade,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReviewsTable, ReviewRow>(table),
                  BaseReferences<_$AppDatabase, $ReviewsTable, ReviewRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReviewsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReviewsTable,
      ReviewRow,
      $$ReviewsTableFilterComposer,
      $$ReviewsTableOrderingComposer,
      $$ReviewsTableAnnotationComposer,
      $$ReviewsTableCreateCompanionBuilder,
      $$ReviewsTableUpdateCompanionBuilder,
      (ReviewRow, BaseReferences<_$AppDatabase, $ReviewsTable, ReviewRow>),
      ReviewRow,
      PrefetchHooks Function()
    >;
typedef $$ConstellationProgressTableCreateCompanionBuilder =
    ConstellationProgressCompanion Function({
      required String constellation,
      required String tier,
      Value<bool> unlocked,
      Value<bool> lit,
      Value<int> levelsDone,
      Value<int> rowid,
    });
typedef $$ConstellationProgressTableUpdateCompanionBuilder =
    ConstellationProgressCompanion Function({
      Value<String> constellation,
      Value<String> tier,
      Value<bool> unlocked,
      Value<bool> lit,
      Value<int> levelsDone,
      Value<int> rowid,
    });

class $$ConstellationProgressTableFilterComposer
    extends Composer<_$AppDatabase, $ConstellationProgressTable> {
  $$ConstellationProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get constellation => $composableBuilder(
    column: $table.constellation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get unlocked => $composableBuilder(
    column: $table.unlocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get lit => $composableBuilder(
    column: $table.lit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get levelsDone => $composableBuilder(
    column: $table.levelsDone,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConstellationProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $ConstellationProgressTable> {
  $$ConstellationProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get constellation => $composableBuilder(
    column: $table.constellation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get unlocked => $composableBuilder(
    column: $table.unlocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get lit => $composableBuilder(
    column: $table.lit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get levelsDone => $composableBuilder(
    column: $table.levelsDone,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConstellationProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConstellationProgressTable> {
  $$ConstellationProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get constellation => $composableBuilder(
    column: $table.constellation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  GeneratedColumn<bool> get unlocked =>
      $composableBuilder(column: $table.unlocked, builder: (column) => column);

  GeneratedColumn<bool> get lit =>
      $composableBuilder(column: $table.lit, builder: (column) => column);

  GeneratedColumn<int> get levelsDone => $composableBuilder(
    column: $table.levelsDone,
    builder: (column) => column,
  );
}

class $$ConstellationProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConstellationProgressTable,
          ConstellationProgressRow,
          $$ConstellationProgressTableFilterComposer,
          $$ConstellationProgressTableOrderingComposer,
          $$ConstellationProgressTableAnnotationComposer,
          $$ConstellationProgressTableCreateCompanionBuilder,
          $$ConstellationProgressTableUpdateCompanionBuilder,
          (
            ConstellationProgressRow,
            BaseReferences<
              _$AppDatabase,
              $ConstellationProgressTable,
              ConstellationProgressRow
            >,
          ),
          ConstellationProgressRow,
          PrefetchHooks Function()
        > {
  $$ConstellationProgressTableTableManager(
    _$AppDatabase db,
    $ConstellationProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConstellationProgressTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ConstellationProgressTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConstellationProgressTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> constellation = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<bool> unlocked = const Value.absent(),
                Value<bool> lit = const Value.absent(),
                Value<int> levelsDone = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConstellationProgressCompanion(
                constellation: constellation,
                tier: tier,
                unlocked: unlocked,
                lit: lit,
                levelsDone: levelsDone,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String constellation,
                required String tier,
                Value<bool> unlocked = const Value.absent(),
                Value<bool> lit = const Value.absent(),
                Value<int> levelsDone = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConstellationProgressCompanion.insert(
                constellation: constellation,
                tier: tier,
                unlocked: unlocked,
                lit: lit,
                levelsDone: levelsDone,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ConstellationProgressTable,
                    ConstellationProgressRow
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ConstellationProgressTable,
                    ConstellationProgressRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConstellationProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConstellationProgressTable,
      ConstellationProgressRow,
      $$ConstellationProgressTableFilterComposer,
      $$ConstellationProgressTableOrderingComposer,
      $$ConstellationProgressTableAnnotationComposer,
      $$ConstellationProgressTableCreateCompanionBuilder,
      $$ConstellationProgressTableUpdateCompanionBuilder,
      (
        ConstellationProgressRow,
        BaseReferences<
          _$AppDatabase,
          $ConstellationProgressTable,
          ConstellationProgressRow
        >,
      ),
      ConstellationProgressRow,
      PrefetchHooks Function()
    >;
typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  Value<int> id,
  required DateTime startedAt,
  required int durationMs,
  required int lmGained,
  required int score,
  required int newWords,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<int> id,
  Value<DateTime> startedAt,
  Value<int> durationMs,
  Value<int> lmGained,
  Value<int> score,
  Value<int> newWords,
});

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lmGained => $composableBuilder(
    column: $table.lmGained,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get newWords => $composableBuilder(
    column: $table.newWords,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lmGained => $composableBuilder(
    column: $table.lmGained,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get newWords => $composableBuilder(
    column: $table.newWords,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lmGained =>
      $composableBuilder(column: $table.lmGained, builder: (column) => column);

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get newWords =>
      $composableBuilder(column: $table.newWords, builder: (column) => column);
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          SessionRow,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (
            SessionRow,
            BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>,
          ),
          SessionRow,
          PrefetchHooks Function()
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> lmGained = const Value.absent(),
                Value<int> score = const Value.absent(),
                Value<int> newWords = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                startedAt: startedAt,
                durationMs: durationMs,
                lmGained: lmGained,
                score: score,
                newWords: newWords,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime startedAt,
                required int durationMs,
                required int lmGained,
                required int score,
                required int newWords,
              }) => SessionsCompanion.insert(
                id: id,
                startedAt: startedAt,
                durationMs: durationMs,
                lmGained: lmGained,
                score: score,
                newWords: newWords,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionsTable, SessionRow>(table),
                  BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      SessionRow,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (SessionRow, BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>),
      SessionRow,
      PrefetchHooks Function()
    >;
typedef $$DailyChallengeResultsTableCreateCompanionBuilder =
    DailyChallengeResultsCompanion Function({
      required String day,
      required int correct,
      required int total,
      required int timeMs,
      Value<int> rowid,
    });
typedef $$DailyChallengeResultsTableUpdateCompanionBuilder =
    DailyChallengeResultsCompanion Function({
      Value<String> day,
      Value<int> correct,
      Value<int> total,
      Value<int> timeMs,
      Value<int> rowid,
    });

class $$DailyChallengeResultsTableFilterComposer
    extends Composer<_$AppDatabase, $DailyChallengeResultsTable> {
  $$DailyChallengeResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeMs => $composableBuilder(
    column: $table.timeMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyChallengeResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyChallengeResultsTable> {
  $$DailyChallengeResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeMs => $composableBuilder(
    column: $table.timeMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyChallengeResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyChallengeResultsTable> {
  $$DailyChallengeResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<int> get correct =>
      $composableBuilder(column: $table.correct, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<int> get timeMs =>
      $composableBuilder(column: $table.timeMs, builder: (column) => column);
}

class $$DailyChallengeResultsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyChallengeResultsTable,
          DailyChallengeResultRow,
          $$DailyChallengeResultsTableFilterComposer,
          $$DailyChallengeResultsTableOrderingComposer,
          $$DailyChallengeResultsTableAnnotationComposer,
          $$DailyChallengeResultsTableCreateCompanionBuilder,
          $$DailyChallengeResultsTableUpdateCompanionBuilder,
          (
            DailyChallengeResultRow,
            BaseReferences<
              _$AppDatabase,
              $DailyChallengeResultsTable,
              DailyChallengeResultRow
            >,
          ),
          DailyChallengeResultRow,
          PrefetchHooks Function()
        > {
  $$DailyChallengeResultsTableTableManager(
    _$AppDatabase db,
    $DailyChallengeResultsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyChallengeResultsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DailyChallengeResultsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DailyChallengeResultsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> day = const Value.absent(),
                Value<int> correct = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<int> timeMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyChallengeResultsCompanion(
                day: day,
                correct: correct,
                total: total,
                timeMs: timeMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String day,
                required int correct,
                required int total,
                required int timeMs,
                Value<int> rowid = const Value.absent(),
              }) => DailyChallengeResultsCompanion.insert(
                day: day,
                correct: correct,
                total: total,
                timeMs: timeMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $DailyChallengeResultsTable,
                    DailyChallengeResultRow
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DailyChallengeResultsTable,
                    DailyChallengeResultRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyChallengeResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyChallengeResultsTable,
      DailyChallengeResultRow,
      $$DailyChallengeResultsTableFilterComposer,
      $$DailyChallengeResultsTableOrderingComposer,
      $$DailyChallengeResultsTableAnnotationComposer,
      $$DailyChallengeResultsTableCreateCompanionBuilder,
      $$DailyChallengeResultsTableUpdateCompanionBuilder,
      (
        DailyChallengeResultRow,
        BaseReferences<
          _$AppDatabase,
          $DailyChallengeResultsTable,
          DailyChallengeResultRow
        >,
      ),
      DailyChallengeResultRow,
      PrefetchHooks Function()
    >;
typedef $$CustomConceptsTableCreateCompanionBuilder =
    CustomConceptsCompanion Function({
      required String id,
      required String target,
      required String native,
      required String deck,
      Value<int> rowid,
    });
typedef $$CustomConceptsTableUpdateCompanionBuilder =
    CustomConceptsCompanion Function({
      Value<String> id,
      Value<String> target,
      Value<String> native,
      Value<String> deck,
      Value<int> rowid,
    });

class $$CustomConceptsTableFilterComposer
    extends Composer<_$AppDatabase, $CustomConceptsTable> {
  $$CustomConceptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get native => $composableBuilder(
    column: $table.native,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deck => $composableBuilder(
    column: $table.deck,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomConceptsTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomConceptsTable> {
  $$CustomConceptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get native => $composableBuilder(
    column: $table.native,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deck => $composableBuilder(
    column: $table.deck,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomConceptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomConceptsTable> {
  $$CustomConceptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<String> get native =>
      $composableBuilder(column: $table.native, builder: (column) => column);

  GeneratedColumn<String> get deck =>
      $composableBuilder(column: $table.deck, builder: (column) => column);
}

class $$CustomConceptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomConceptsTable,
          CustomConceptRow,
          $$CustomConceptsTableFilterComposer,
          $$CustomConceptsTableOrderingComposer,
          $$CustomConceptsTableAnnotationComposer,
          $$CustomConceptsTableCreateCompanionBuilder,
          $$CustomConceptsTableUpdateCompanionBuilder,
          (
            CustomConceptRow,
            BaseReferences<
              _$AppDatabase,
              $CustomConceptsTable,
              CustomConceptRow
            >,
          ),
          CustomConceptRow,
          PrefetchHooks Function()
        > {
  $$CustomConceptsTableTableManager(
    _$AppDatabase db,
    $CustomConceptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomConceptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomConceptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomConceptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> target = const Value.absent(),
                Value<String> native = const Value.absent(),
                Value<String> deck = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomConceptsCompanion(
                id: id,
                target: target,
                native: native,
                deck: deck,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String target,
                required String native,
                required String deck,
                Value<int> rowid = const Value.absent(),
              }) => CustomConceptsCompanion.insert(
                id: id,
                target: target,
                native: native,
                deck: deck,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CustomConceptsTable, CustomConceptRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CustomConceptsTable,
                    CustomConceptRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomConceptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomConceptsTable,
      CustomConceptRow,
      $$CustomConceptsTableFilterComposer,
      $$CustomConceptsTableOrderingComposer,
      $$CustomConceptsTableAnnotationComposer,
      $$CustomConceptsTableCreateCompanionBuilder,
      $$CustomConceptsTableUpdateCompanionBuilder,
      (
        CustomConceptRow,
        BaseReferences<_$AppDatabase, $CustomConceptsTable, CustomConceptRow>,
      ),
      CustomConceptRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PlayersTableTableManager get players =>
      $$PlayersTableTableManager(_db, _db.players);
  $$WordStatesTableTableManager get wordStates =>
      $$WordStatesTableTableManager(_db, _db.wordStates);
  $$ReviewsTableTableManager get reviews =>
      $$ReviewsTableTableManager(_db, _db.reviews);
  $$ConstellationProgressTableTableManager get constellationProgress =>
      $$ConstellationProgressTableTableManager(_db, _db.constellationProgress);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$DailyChallengeResultsTableTableManager get dailyChallengeResults =>
      $$DailyChallengeResultsTableTableManager(_db, _db.dailyChallengeResults);
  $$CustomConceptsTableTableManager get customConcepts =>
      $$CustomConceptsTableTableManager(_db, _db.customConcepts);
}
