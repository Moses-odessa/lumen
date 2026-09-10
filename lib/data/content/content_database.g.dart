// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_database.dart';

// ignore_for_file: type=lint
class $LanguagesTable extends Languages
    with TableInfo<$LanguagesTable, LanguageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LanguagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phrasesMeta = const VerificationMeta(
    'phrases',
  );
  @override
  late final GeneratedColumn<int> phrases = GeneratedColumn<int>(
    'phrases',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [code, role, status, name, phrases];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'languages';
  @override
  VerificationContext validateIntegrity(
    Insertable<LanguageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phrases')) {
      context.handle(
        _phrasesMeta,
        phrases.isAcceptableOrUnknown(data['phrases']!, _phrasesMeta),
      );
    } else if (isInserting) {
      context.missing(_phrasesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {code};
  @override
  LanguageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LanguageRow(
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phrases: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}phrases'],
      )!,
    );
  }

  @override
  $LanguagesTable createAlias(String alias) {
    return $LanguagesTable(attachedDatabase, alias);
  }
}

class LanguageRow extends DataClass implements Insertable<LanguageRow> {
  final String code;

  /// `native` — на нём подсказки, `target` — его учат, `both` — и то и то.
  final String role;

  /// `draft` или `launched`. Черновой язык лежит в репозитории, но игроку
  /// не предлагается.
  final String status;

  /// Самоназвание: «Українська», «Deutsch». На языке самого языка.
  final String name;

  /// Сколько фраз язык покрывает.
  final int phrases;
  const LanguageRow({
    required this.code,
    required this.role,
    required this.status,
    required this.name,
    required this.phrases,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['code'] = Variable<String>(code);
    map['role'] = Variable<String>(role);
    map['status'] = Variable<String>(status);
    map['name'] = Variable<String>(name);
    map['phrases'] = Variable<int>(phrases);
    return map;
  }

  LanguagesCompanion toCompanion(bool nullToAbsent) {
    return LanguagesCompanion(
      code: Value(code),
      role: Value(role),
      status: Value(status),
      name: Value(name),
      phrases: Value(phrases),
    );
  }

  factory LanguageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LanguageRow(
      code: serializer.fromJson<String>(json['code']),
      role: serializer.fromJson<String>(json['role']),
      status: serializer.fromJson<String>(json['status']),
      name: serializer.fromJson<String>(json['name']),
      phrases: serializer.fromJson<int>(json['phrases']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'code': serializer.toJson<String>(code),
      'role': serializer.toJson<String>(role),
      'status': serializer.toJson<String>(status),
      'name': serializer.toJson<String>(name),
      'phrases': serializer.toJson<int>(phrases),
    };
  }

  LanguageRow copyWith({
    String? code,
    String? role,
    String? status,
    String? name,
    int? phrases,
  }) => LanguageRow(
    code: code ?? this.code,
    role: role ?? this.role,
    status: status ?? this.status,
    name: name ?? this.name,
    phrases: phrases ?? this.phrases,
  );
  LanguageRow copyWithCompanion(LanguagesCompanion data) {
    return LanguageRow(
      code: data.code.present ? data.code.value : this.code,
      role: data.role.present ? data.role.value : this.role,
      status: data.status.present ? data.status.value : this.status,
      name: data.name.present ? data.name.value : this.name,
      phrases: data.phrases.present ? data.phrases.value : this.phrases,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LanguageRow(')
          ..write('code: $code, ')
          ..write('role: $role, ')
          ..write('status: $status, ')
          ..write('name: $name, ')
          ..write('phrases: $phrases')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(code, role, status, name, phrases);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LanguageRow &&
          other.code == this.code &&
          other.role == this.role &&
          other.status == this.status &&
          other.name == this.name &&
          other.phrases == this.phrases);
}

class LanguagesCompanion extends UpdateCompanion<LanguageRow> {
  final Value<String> code;
  final Value<String> role;
  final Value<String> status;
  final Value<String> name;
  final Value<int> phrases;
  final Value<int> rowid;
  const LanguagesCompanion({
    this.code = const Value.absent(),
    this.role = const Value.absent(),
    this.status = const Value.absent(),
    this.name = const Value.absent(),
    this.phrases = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LanguagesCompanion.insert({
    required String code,
    required String role,
    required String status,
    required String name,
    required int phrases,
    this.rowid = const Value.absent(),
  }) : code = Value(code),
       role = Value(role),
       status = Value(status),
       name = Value(name),
       phrases = Value(phrases);
  static Insertable<LanguageRow> custom({
    Expression<String>? code,
    Expression<String>? role,
    Expression<String>? status,
    Expression<String>? name,
    Expression<int>? phrases,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (code != null) 'code': code,
      if (role != null) 'role': role,
      if (status != null) 'status': status,
      if (name != null) 'name': name,
      if (phrases != null) 'phrases': phrases,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LanguagesCompanion copyWith({
    Value<String>? code,
    Value<String>? role,
    Value<String>? status,
    Value<String>? name,
    Value<int>? phrases,
    Value<int>? rowid,
  }) {
    return LanguagesCompanion(
      code: code ?? this.code,
      role: role ?? this.role,
      status: status ?? this.status,
      name: name ?? this.name,
      phrases: phrases ?? this.phrases,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phrases.present) {
      map['phrases'] = Variable<int>(phrases.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LanguagesCompanion(')
          ..write('code: $code, ')
          ..write('role: $role, ')
          ..write('status: $status, ')
          ..write('name: $name, ')
          ..write('phrases: $phrases, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhrasesTable extends Phrases with TableInfo<$PhrasesTable, PhraseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhrasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _langMeta = const VerificationMeta('lang');
  @override
  late final GeneratedColumn<String> lang = GeneratedColumn<String>(
    'lang',
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
  static const VerificationMeta _idxMeta = const VerificationMeta('idx');
  @override
  late final GeneratedColumn<int> idx = GeneratedColumn<int>(
    'idx',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sentenceMeta = const VerificationMeta(
    'sentence',
  );
  @override
  late final GeneratedColumn<String> sentence = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _registerMeta = const VerificationMeta(
    'register',
  );
  @override
  late final GeneratedColumn<String> register = GeneratedColumn<String>(
    'register',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lang,
    tier,
    constellation,
    idx,
    sentence,
    kind,
    register,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'phrases';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhraseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('lang')) {
      context.handle(
        _langMeta,
        lang.isAcceptableOrUnknown(data['lang']!, _langMeta),
      );
    } else if (isInserting) {
      context.missing(_langMeta);
    }
    if (data.containsKey('tier')) {
      context.handle(
        _tierMeta,
        tier.isAcceptableOrUnknown(data['tier']!, _tierMeta),
      );
    } else if (isInserting) {
      context.missing(_tierMeta);
    }
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
    if (data.containsKey('idx')) {
      context.handle(
        _idxMeta,
        idx.isAcceptableOrUnknown(data['idx']!, _idxMeta),
      );
    } else if (isInserting) {
      context.missing(_idxMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _sentenceMeta,
        sentence.isAcceptableOrUnknown(data['text']!, _sentenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sentenceMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('register')) {
      context.handle(
        _registerMeta,
        register.isAcceptableOrUnknown(data['register']!, _registerMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PhraseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhraseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      lang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lang'],
      )!,
      tier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tier'],
      )!,
      constellation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}constellation'],
      )!,
      idx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}idx'],
      )!,
      sentence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      register: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}register'],
      ),
    );
  }

  @override
  $PhrasesTable createAlias(String alias) {
    return $PhrasesTable(attachedDatabase, alias);
  }
}

class PhraseRow extends DataClass implements Insertable<PhraseRow> {
  final String id;

  /// Язык изучения, на котором написана фраза.
  final String lang;
  final String tier;
  final String constellation;

  /// Порядок внутри созвездия и яруса, как в файле контента.
  ///
  /// Прежнюю последовательность знакомства задавала частотность слова, а у
  /// фразы частотности нет: порядок решает автор, и он же решает, с чего
  /// начинается тема.
  final int idx;

  /// Готовая к показу фраза.
  ///
  /// Геттер называется не `text`, и это не вкус: `text()` — билдер колонки в
  /// Drift, и `TextColumn get text => text()()` рекурсивно возвращает сам
  /// себя. Имя колонки в SQL при этом остаётся `text`.
  final String sentence;

  /// Вид фразы: `phrase`, `example` или `idiom`. Закрытый набор кодов, как у
  /// [register].
  ///
  /// Зачем он в схеме, если ни одна из трёх механик его не спрашивает.
  /// У идиомы перевод **смысловой**: «Ich habe gerade viel um die Ohren» —
  /// это «у мене зараз багато справ», ни одного общего слова. Проверка
  /// буквальности перевода — а вычитка просит именно её — обязана идиомы
  /// пропускать, и пометка единственный способ их узнать: по тексту идиома от
  /// фразы не отличается ничем. Пример — законченный образец речевой модели,
  /// занявший место прежнего шаблона с многоточием: «Ich heiße Alex.» вместо
  /// «Ich heiße ...».
  ///
  /// В отличие от соседнего [register] колонка не `nullable`, и разница не в
  /// аккуратности: регистр у фразы либо есть, либо нет — 1315 строк корпуса
  /// не несут пометки вовсе, и NULL там правдив, — а чем-то фраза является
  /// всегда. NULL
  /// пришлось бы читать «неизвестно чем», то есть третьим ответом на вопрос
  /// «это идиома?», которого в закрытом наборе нет. Умолчание при этом
  /// существует, но живёт на входе, а не в базе: `kind:` можно не писать в
  /// файле фразы (`defaultPhraseKind` в `tool/content_schema.dart`), а в базу
  /// уезжает явный код у каждой строки — поэтому `DEFAULT` у колонки нет.
  ///
  /// Коллизии имён, как у [sentence], здесь нет: билдера колонки `kind` в
  /// Drift не существует, а [CalibrationItems.kind] в этом же файле живёт с
  /// первых версий схемы. Проверено генерацией, а не рассуждением.
  final String kind;

  /// Регистр: `casual` или `formal`. Код, а не текст — строку даёт
  /// локализация на языке интерфейса.
  final String? register;
  const PhraseRow({
    required this.id,
    required this.lang,
    required this.tier,
    required this.constellation,
    required this.idx,
    required this.sentence,
    required this.kind,
    this.register,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['lang'] = Variable<String>(lang);
    map['tier'] = Variable<String>(tier);
    map['constellation'] = Variable<String>(constellation);
    map['idx'] = Variable<int>(idx);
    map['text'] = Variable<String>(sentence);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || register != null) {
      map['register'] = Variable<String>(register);
    }
    return map;
  }

  PhrasesCompanion toCompanion(bool nullToAbsent) {
    return PhrasesCompanion(
      id: Value(id),
      lang: Value(lang),
      tier: Value(tier),
      constellation: Value(constellation),
      idx: Value(idx),
      sentence: Value(sentence),
      kind: Value(kind),
      register: register == null && nullToAbsent
          ? const Value.absent()
          : Value(register),
    );
  }

  factory PhraseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhraseRow(
      id: serializer.fromJson<String>(json['id']),
      lang: serializer.fromJson<String>(json['lang']),
      tier: serializer.fromJson<String>(json['tier']),
      constellation: serializer.fromJson<String>(json['constellation']),
      idx: serializer.fromJson<int>(json['idx']),
      sentence: serializer.fromJson<String>(json['sentence']),
      kind: serializer.fromJson<String>(json['kind']),
      register: serializer.fromJson<String?>(json['register']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'lang': serializer.toJson<String>(lang),
      'tier': serializer.toJson<String>(tier),
      'constellation': serializer.toJson<String>(constellation),
      'idx': serializer.toJson<int>(idx),
      'sentence': serializer.toJson<String>(sentence),
      'kind': serializer.toJson<String>(kind),
      'register': serializer.toJson<String?>(register),
    };
  }

  PhraseRow copyWith({
    String? id,
    String? lang,
    String? tier,
    String? constellation,
    int? idx,
    String? sentence,
    String? kind,
    Value<String?> register = const Value.absent(),
  }) => PhraseRow(
    id: id ?? this.id,
    lang: lang ?? this.lang,
    tier: tier ?? this.tier,
    constellation: constellation ?? this.constellation,
    idx: idx ?? this.idx,
    sentence: sentence ?? this.sentence,
    kind: kind ?? this.kind,
    register: register.present ? register.value : this.register,
  );
  PhraseRow copyWithCompanion(PhrasesCompanion data) {
    return PhraseRow(
      id: data.id.present ? data.id.value : this.id,
      lang: data.lang.present ? data.lang.value : this.lang,
      tier: data.tier.present ? data.tier.value : this.tier,
      constellation: data.constellation.present
          ? data.constellation.value
          : this.constellation,
      idx: data.idx.present ? data.idx.value : this.idx,
      sentence: data.sentence.present ? data.sentence.value : this.sentence,
      kind: data.kind.present ? data.kind.value : this.kind,
      register: data.register.present ? data.register.value : this.register,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhraseRow(')
          ..write('id: $id, ')
          ..write('lang: $lang, ')
          ..write('tier: $tier, ')
          ..write('constellation: $constellation, ')
          ..write('idx: $idx, ')
          ..write('sentence: $sentence, ')
          ..write('kind: $kind, ')
          ..write('register: $register')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, lang, tier, constellation, idx, sentence, kind, register);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhraseRow &&
          other.id == this.id &&
          other.lang == this.lang &&
          other.tier == this.tier &&
          other.constellation == this.constellation &&
          other.idx == this.idx &&
          other.sentence == this.sentence &&
          other.kind == this.kind &&
          other.register == this.register);
}

class PhrasesCompanion extends UpdateCompanion<PhraseRow> {
  final Value<String> id;
  final Value<String> lang;
  final Value<String> tier;
  final Value<String> constellation;
  final Value<int> idx;
  final Value<String> sentence;
  final Value<String> kind;
  final Value<String?> register;
  final Value<int> rowid;
  const PhrasesCompanion({
    this.id = const Value.absent(),
    this.lang = const Value.absent(),
    this.tier = const Value.absent(),
    this.constellation = const Value.absent(),
    this.idx = const Value.absent(),
    this.sentence = const Value.absent(),
    this.kind = const Value.absent(),
    this.register = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhrasesCompanion.insert({
    required String id,
    required String lang,
    required String tier,
    required String constellation,
    required int idx,
    required String sentence,
    required String kind,
    this.register = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       lang = Value(lang),
       tier = Value(tier),
       constellation = Value(constellation),
       idx = Value(idx),
       sentence = Value(sentence),
       kind = Value(kind);
  static Insertable<PhraseRow> custom({
    Expression<String>? id,
    Expression<String>? lang,
    Expression<String>? tier,
    Expression<String>? constellation,
    Expression<int>? idx,
    Expression<String>? sentence,
    Expression<String>? kind,
    Expression<String>? register,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lang != null) 'lang': lang,
      if (tier != null) 'tier': tier,
      if (constellation != null) 'constellation': constellation,
      if (idx != null) 'idx': idx,
      if (sentence != null) 'text': sentence,
      if (kind != null) 'kind': kind,
      if (register != null) 'register': register,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhrasesCompanion copyWith({
    Value<String>? id,
    Value<String>? lang,
    Value<String>? tier,
    Value<String>? constellation,
    Value<int>? idx,
    Value<String>? sentence,
    Value<String>? kind,
    Value<String?>? register,
    Value<int>? rowid,
  }) {
    return PhrasesCompanion(
      id: id ?? this.id,
      lang: lang ?? this.lang,
      tier: tier ?? this.tier,
      constellation: constellation ?? this.constellation,
      idx: idx ?? this.idx,
      sentence: sentence ?? this.sentence,
      kind: kind ?? this.kind,
      register: register ?? this.register,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (lang.present) {
      map['lang'] = Variable<String>(lang.value);
    }
    if (tier.present) {
      map['tier'] = Variable<String>(tier.value);
    }
    if (constellation.present) {
      map['constellation'] = Variable<String>(constellation.value);
    }
    if (idx.present) {
      map['idx'] = Variable<int>(idx.value);
    }
    if (sentence.present) {
      map['text'] = Variable<String>(sentence.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (register.present) {
      map['register'] = Variable<String>(register.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhrasesCompanion(')
          ..write('id: $id, ')
          ..write('lang: $lang, ')
          ..write('tier: $tier, ')
          ..write('constellation: $constellation, ')
          ..write('idx: $idx, ')
          ..write('sentence: $sentence, ')
          ..write('kind: $kind, ')
          ..write('register: $register, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhraseTranslationsTable extends PhraseTranslations
    with TableInfo<$PhraseTranslationsTable, PhraseTranslationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhraseTranslationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _phraseIdMeta = const VerificationMeta(
    'phraseId',
  );
  @override
  late final GeneratedColumn<String> phraseId = GeneratedColumn<String>(
    'phrase_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _langMeta = const VerificationMeta('lang');
  @override
  late final GeneratedColumn<String> lang = GeneratedColumn<String>(
    'lang',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sentenceMeta = const VerificationMeta(
    'sentence',
  );
  @override
  late final GeneratedColumn<String> sentence = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [phraseId, lang, sentence];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'phrase_translations';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhraseTranslationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('phrase_id')) {
      context.handle(
        _phraseIdMeta,
        phraseId.isAcceptableOrUnknown(data['phrase_id']!, _phraseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_phraseIdMeta);
    }
    if (data.containsKey('lang')) {
      context.handle(
        _langMeta,
        lang.isAcceptableOrUnknown(data['lang']!, _langMeta),
      );
    } else if (isInserting) {
      context.missing(_langMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _sentenceMeta,
        sentence.isAcceptableOrUnknown(data['text']!, _sentenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sentenceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {phraseId, lang};
  @override
  PhraseTranslationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhraseTranslationRow(
      phraseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phrase_id'],
      )!,
      lang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lang'],
      )!,
      sentence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
    );
  }

  @override
  $PhraseTranslationsTable createAlias(String alias) {
    return $PhraseTranslationsTable(attachedDatabase, alias);
  }
}

class PhraseTranslationRow extends DataClass
    implements Insertable<PhraseTranslationRow> {
  final String phraseId;
  final String lang;

  /// Имя колонки в SQL — `text`; геттер другой, потому что `text()` в Drift
  /// это билдер колонки.
  final String sentence;
  const PhraseTranslationRow({
    required this.phraseId,
    required this.lang,
    required this.sentence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['phrase_id'] = Variable<String>(phraseId);
    map['lang'] = Variable<String>(lang);
    map['text'] = Variable<String>(sentence);
    return map;
  }

  PhraseTranslationsCompanion toCompanion(bool nullToAbsent) {
    return PhraseTranslationsCompanion(
      phraseId: Value(phraseId),
      lang: Value(lang),
      sentence: Value(sentence),
    );
  }

  factory PhraseTranslationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhraseTranslationRow(
      phraseId: serializer.fromJson<String>(json['phraseId']),
      lang: serializer.fromJson<String>(json['lang']),
      sentence: serializer.fromJson<String>(json['sentence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'phraseId': serializer.toJson<String>(phraseId),
      'lang': serializer.toJson<String>(lang),
      'sentence': serializer.toJson<String>(sentence),
    };
  }

  PhraseTranslationRow copyWith({
    String? phraseId,
    String? lang,
    String? sentence,
  }) => PhraseTranslationRow(
    phraseId: phraseId ?? this.phraseId,
    lang: lang ?? this.lang,
    sentence: sentence ?? this.sentence,
  );
  PhraseTranslationRow copyWithCompanion(PhraseTranslationsCompanion data) {
    return PhraseTranslationRow(
      phraseId: data.phraseId.present ? data.phraseId.value : this.phraseId,
      lang: data.lang.present ? data.lang.value : this.lang,
      sentence: data.sentence.present ? data.sentence.value : this.sentence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhraseTranslationRow(')
          ..write('phraseId: $phraseId, ')
          ..write('lang: $lang, ')
          ..write('sentence: $sentence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(phraseId, lang, sentence);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhraseTranslationRow &&
          other.phraseId == this.phraseId &&
          other.lang == this.lang &&
          other.sentence == this.sentence);
}

class PhraseTranslationsCompanion
    extends UpdateCompanion<PhraseTranslationRow> {
  final Value<String> phraseId;
  final Value<String> lang;
  final Value<String> sentence;
  final Value<int> rowid;
  const PhraseTranslationsCompanion({
    this.phraseId = const Value.absent(),
    this.lang = const Value.absent(),
    this.sentence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhraseTranslationsCompanion.insert({
    required String phraseId,
    required String lang,
    required String sentence,
    this.rowid = const Value.absent(),
  }) : phraseId = Value(phraseId),
       lang = Value(lang),
       sentence = Value(sentence);
  static Insertable<PhraseTranslationRow> custom({
    Expression<String>? phraseId,
    Expression<String>? lang,
    Expression<String>? sentence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (phraseId != null) 'phrase_id': phraseId,
      if (lang != null) 'lang': lang,
      if (sentence != null) 'text': sentence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhraseTranslationsCompanion copyWith({
    Value<String>? phraseId,
    Value<String>? lang,
    Value<String>? sentence,
    Value<int>? rowid,
  }) {
    return PhraseTranslationsCompanion(
      phraseId: phraseId ?? this.phraseId,
      lang: lang ?? this.lang,
      sentence: sentence ?? this.sentence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (phraseId.present) {
      map['phrase_id'] = Variable<String>(phraseId.value);
    }
    if (lang.present) {
      map['lang'] = Variable<String>(lang.value);
    }
    if (sentence.present) {
      map['text'] = Variable<String>(sentence.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhraseTranslationsCompanion(')
          ..write('phraseId: $phraseId, ')
          ..write('lang: $lang, ')
          ..write('sentence: $sentence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConstellationNamesTable extends ConstellationNames
    with TableInfo<$ConstellationNamesTable, ConstellationNameRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConstellationNamesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _langMeta = const VerificationMeta('lang');
  @override
  late final GeneratedColumn<String> lang = GeneratedColumn<String>(
    'lang',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [constellation, lang, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'constellation_names';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConstellationNameRow> instance, {
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
    if (data.containsKey('lang')) {
      context.handle(
        _langMeta,
        lang.isAcceptableOrUnknown(data['lang']!, _langMeta),
      );
    } else if (isInserting) {
      context.missing(_langMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {constellation, lang};
  @override
  ConstellationNameRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConstellationNameRow(
      constellation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}constellation'],
      )!,
      lang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lang'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $ConstellationNamesTable createAlias(String alias) {
    return $ConstellationNamesTable(attachedDatabase, alias);
  }
}

class ConstellationNameRow extends DataClass
    implements Insertable<ConstellationNameRow> {
  /// Slug созвездия — тот же, что в [Phrases.constellation]. Связь по слагу,
  /// а не по числовому id: созвездие не отдельная сущность контента, а поле
  /// в шапке файла фразы.
  final String constellation;

  /// Код языка: `de` (язык изучения) либо язык подсказок — `uk`, `ru`, `en`,
  /// `it`. Языков интерфейса шесть, а имён пять: французского контента нет,
  /// и правило показа это учитывает.
  final String lang;

  /// Имя темы, готовое к подписи на карте.
  ///
  /// Геттер назван `name`, и это проверено, а не понадеялось. Шрам
  /// [Phrases.sentence] выше — про то, что `text` в Drift это **билдер
  /// колонки**, поэтому `TextColumn get text => text()()` рекурсивно
  /// возвращает сам себя, а генерация на такой файл молча не даёт ничего.
  /// Билдера с именем `name` в Drift нет — переименование колонки делает
  /// `named()` у уже построенной колонки, а не одноимённый геттер таблицы, —
  /// и [Languages.name] тому свидетель: колонка `name` там существует с
  /// первого дня схемы. Переименовывать нечего.
  final String name;
  const ConstellationNameRow({
    required this.constellation,
    required this.lang,
    required this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['constellation'] = Variable<String>(constellation);
    map['lang'] = Variable<String>(lang);
    map['name'] = Variable<String>(name);
    return map;
  }

  ConstellationNamesCompanion toCompanion(bool nullToAbsent) {
    return ConstellationNamesCompanion(
      constellation: Value(constellation),
      lang: Value(lang),
      name: Value(name),
    );
  }

  factory ConstellationNameRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConstellationNameRow(
      constellation: serializer.fromJson<String>(json['constellation']),
      lang: serializer.fromJson<String>(json['lang']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'constellation': serializer.toJson<String>(constellation),
      'lang': serializer.toJson<String>(lang),
      'name': serializer.toJson<String>(name),
    };
  }

  ConstellationNameRow copyWith({
    String? constellation,
    String? lang,
    String? name,
  }) => ConstellationNameRow(
    constellation: constellation ?? this.constellation,
    lang: lang ?? this.lang,
    name: name ?? this.name,
  );
  ConstellationNameRow copyWithCompanion(ConstellationNamesCompanion data) {
    return ConstellationNameRow(
      constellation: data.constellation.present
          ? data.constellation.value
          : this.constellation,
      lang: data.lang.present ? data.lang.value : this.lang,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConstellationNameRow(')
          ..write('constellation: $constellation, ')
          ..write('lang: $lang, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(constellation, lang, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConstellationNameRow &&
          other.constellation == this.constellation &&
          other.lang == this.lang &&
          other.name == this.name);
}

class ConstellationNamesCompanion
    extends UpdateCompanion<ConstellationNameRow> {
  final Value<String> constellation;
  final Value<String> lang;
  final Value<String> name;
  final Value<int> rowid;
  const ConstellationNamesCompanion({
    this.constellation = const Value.absent(),
    this.lang = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConstellationNamesCompanion.insert({
    required String constellation,
    required String lang,
    required String name,
    this.rowid = const Value.absent(),
  }) : constellation = Value(constellation),
       lang = Value(lang),
       name = Value(name);
  static Insertable<ConstellationNameRow> custom({
    Expression<String>? constellation,
    Expression<String>? lang,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (constellation != null) 'constellation': constellation,
      if (lang != null) 'lang': lang,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConstellationNamesCompanion copyWith({
    Value<String>? constellation,
    Value<String>? lang,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return ConstellationNamesCompanion(
      constellation: constellation ?? this.constellation,
      lang: lang ?? this.lang,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (constellation.present) {
      map['constellation'] = Variable<String>(constellation.value);
    }
    if (lang.present) {
      map['lang'] = Variable<String>(lang.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConstellationNamesCompanion(')
          ..write('constellation: $constellation, ')
          ..write('lang: $lang, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalibrationItemsTable extends CalibrationItems
    with TableInfo<$CalibrationItemsTable, CalibrationItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalibrationItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _phraseIdMeta = const VerificationMeta(
    'phraseId',
  );
  @override
  late final GeneratedColumn<String> phraseId = GeneratedColumn<String>(
    'phrase_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, tier, phraseId, kind];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calibration_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalibrationItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tier')) {
      context.handle(
        _tierMeta,
        tier.isAcceptableOrUnknown(data['tier']!, _tierMeta),
      );
    } else if (isInserting) {
      context.missing(_tierMeta);
    }
    if (data.containsKey('phrase_id')) {
      context.handle(
        _phraseIdMeta,
        phraseId.isAcceptableOrUnknown(data['phrase_id']!, _phraseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_phraseIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CalibrationItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalibrationItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tier'],
      )!,
      phraseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phrase_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
    );
  }

  @override
  $CalibrationItemsTable createAlias(String alias) {
    return $CalibrationItemsTable(attachedDatabase, alias);
  }
}

class CalibrationItemRow extends DataClass
    implements Insertable<CalibrationItemRow> {
  final String id;
  final String tier;
  final String phraseId;

  /// Вид шага теста — гребёнка, поиск, подтверждение.
  final String kind;
  const CalibrationItemRow({
    required this.id,
    required this.tier,
    required this.phraseId,
    required this.kind,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tier'] = Variable<String>(tier);
    map['phrase_id'] = Variable<String>(phraseId);
    map['kind'] = Variable<String>(kind);
    return map;
  }

  CalibrationItemsCompanion toCompanion(bool nullToAbsent) {
    return CalibrationItemsCompanion(
      id: Value(id),
      tier: Value(tier),
      phraseId: Value(phraseId),
      kind: Value(kind),
    );
  }

  factory CalibrationItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalibrationItemRow(
      id: serializer.fromJson<String>(json['id']),
      tier: serializer.fromJson<String>(json['tier']),
      phraseId: serializer.fromJson<String>(json['phraseId']),
      kind: serializer.fromJson<String>(json['kind']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tier': serializer.toJson<String>(tier),
      'phraseId': serializer.toJson<String>(phraseId),
      'kind': serializer.toJson<String>(kind),
    };
  }

  CalibrationItemRow copyWith({
    String? id,
    String? tier,
    String? phraseId,
    String? kind,
  }) => CalibrationItemRow(
    id: id ?? this.id,
    tier: tier ?? this.tier,
    phraseId: phraseId ?? this.phraseId,
    kind: kind ?? this.kind,
  );
  CalibrationItemRow copyWithCompanion(CalibrationItemsCompanion data) {
    return CalibrationItemRow(
      id: data.id.present ? data.id.value : this.id,
      tier: data.tier.present ? data.tier.value : this.tier,
      phraseId: data.phraseId.present ? data.phraseId.value : this.phraseId,
      kind: data.kind.present ? data.kind.value : this.kind,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalibrationItemRow(')
          ..write('id: $id, ')
          ..write('tier: $tier, ')
          ..write('phraseId: $phraseId, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tier, phraseId, kind);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalibrationItemRow &&
          other.id == this.id &&
          other.tier == this.tier &&
          other.phraseId == this.phraseId &&
          other.kind == this.kind);
}

class CalibrationItemsCompanion extends UpdateCompanion<CalibrationItemRow> {
  final Value<String> id;
  final Value<String> tier;
  final Value<String> phraseId;
  final Value<String> kind;
  final Value<int> rowid;
  const CalibrationItemsCompanion({
    this.id = const Value.absent(),
    this.tier = const Value.absent(),
    this.phraseId = const Value.absent(),
    this.kind = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalibrationItemsCompanion.insert({
    required String id,
    required String tier,
    required String phraseId,
    required String kind,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tier = Value(tier),
       phraseId = Value(phraseId),
       kind = Value(kind);
  static Insertable<CalibrationItemRow> custom({
    Expression<String>? id,
    Expression<String>? tier,
    Expression<String>? phraseId,
    Expression<String>? kind,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tier != null) 'tier': tier,
      if (phraseId != null) 'phrase_id': phraseId,
      if (kind != null) 'kind': kind,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalibrationItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? tier,
    Value<String>? phraseId,
    Value<String>? kind,
    Value<int>? rowid,
  }) {
    return CalibrationItemsCompanion(
      id: id ?? this.id,
      tier: tier ?? this.tier,
      phraseId: phraseId ?? this.phraseId,
      kind: kind ?? this.kind,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tier.present) {
      map['tier'] = Variable<String>(tier.value);
    }
    if (phraseId.present) {
      map['phrase_id'] = Variable<String>(phraseId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalibrationItemsCompanion(')
          ..write('id: $id, ')
          ..write('tier: $tier, ')
          ..write('phraseId: $phraseId, ')
          ..write('kind: $kind, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentMetaTable extends ContentMeta
    with TableInfo<$ContentMetaTable, ContentMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  ContentMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentMetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $ContentMetaTable createAlias(String alias) {
    return $ContentMetaTable(attachedDatabase, alias);
  }
}

class ContentMetaRow extends DataClass implements Insertable<ContentMetaRow> {
  final String key;
  final String value;
  const ContentMetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  ContentMetaCompanion toCompanion(bool nullToAbsent) {
    return ContentMetaCompanion(key: Value(key), value: Value(value));
  }

  factory ContentMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentMetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  ContentMetaRow copyWith({String? key, String? value}) =>
      ContentMetaRow(key: key ?? this.key, value: value ?? this.value);
  ContentMetaRow copyWithCompanion(ContentMetaCompanion data) {
    return ContentMetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentMetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentMetaRow &&
          other.key == this.key &&
          other.value == this.value);
}

class ContentMetaCompanion extends UpdateCompanion<ContentMetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const ContentMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<ContentMetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentMetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return ContentMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ContentDatabase extends GeneratedDatabase {
  _$ContentDatabase(QueryExecutor e) : super(e);
  $ContentDatabaseManager get managers => $ContentDatabaseManager(this);
  late final $LanguagesTable languages = $LanguagesTable(this);
  late final $PhrasesTable phrases = $PhrasesTable(this);
  late final $PhraseTranslationsTable phraseTranslations =
      $PhraseTranslationsTable(this);
  late final $ConstellationNamesTable constellationNames =
      $ConstellationNamesTable(this);
  late final $CalibrationItemsTable calibrationItems = $CalibrationItemsTable(
    this,
  );
  late final $ContentMetaTable contentMeta = $ContentMetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    languages,
    phrases,
    phraseTranslations,
    constellationNames,
    calibrationItems,
    contentMeta,
  ];
}

typedef $$LanguagesTableCreateCompanionBuilder = LanguagesCompanion Function({
  required String code,
  required String role,
  required String status,
  required String name,
  required int phrases,
  Value<int> rowid,
});
typedef $$LanguagesTableUpdateCompanionBuilder = LanguagesCompanion Function({
  Value<String> code,
  Value<String> role,
  Value<String> status,
  Value<String> name,
  Value<int> phrases,
  Value<int> rowid,
});

class $$LanguagesTableFilterComposer
    extends Composer<_$ContentDatabase, $LanguagesTable> {
  $$LanguagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get phrases => $composableBuilder(
    column: $table.phrases,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LanguagesTableOrderingComposer
    extends Composer<_$ContentDatabase, $LanguagesTable> {
  $$LanguagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get phrases => $composableBuilder(
    column: $table.phrases,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LanguagesTableAnnotationComposer
    extends Composer<_$ContentDatabase, $LanguagesTable> {
  $$LanguagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get phrases =>
      $composableBuilder(column: $table.phrases, builder: (column) => column);
}

class $$LanguagesTableTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          $LanguagesTable,
          LanguageRow,
          $$LanguagesTableFilterComposer,
          $$LanguagesTableOrderingComposer,
          $$LanguagesTableAnnotationComposer,
          $$LanguagesTableCreateCompanionBuilder,
          $$LanguagesTableUpdateCompanionBuilder,
          (
            LanguageRow,
            BaseReferences<_$ContentDatabase, $LanguagesTable, LanguageRow>,
          ),
          LanguageRow,
          PrefetchHooks Function()
        > {
  $$LanguagesTableTableManager(_$ContentDatabase db, $LanguagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LanguagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LanguagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LanguagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> code = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> phrases = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LanguagesCompanion(
                code: code,
                role: role,
                status: status,
                name: name,
                phrases: phrases,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String code,
                required String role,
                required String status,
                required String name,
                required int phrases,
                Value<int> rowid = const Value.absent(),
              }) => LanguagesCompanion.insert(
                code: code,
                role: role,
                status: status,
                name: name,
                phrases: phrases,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LanguagesTable, LanguageRow>(table),
                  BaseReferences<
                    _$ContentDatabase,
                    $LanguagesTable,
                    LanguageRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LanguagesTableProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      $LanguagesTable,
      LanguageRow,
      $$LanguagesTableFilterComposer,
      $$LanguagesTableOrderingComposer,
      $$LanguagesTableAnnotationComposer,
      $$LanguagesTableCreateCompanionBuilder,
      $$LanguagesTableUpdateCompanionBuilder,
      (
        LanguageRow,
        BaseReferences<_$ContentDatabase, $LanguagesTable, LanguageRow>,
      ),
      LanguageRow,
      PrefetchHooks Function()
    >;
typedef $$PhrasesTableCreateCompanionBuilder = PhrasesCompanion Function({
  required String id,
  required String lang,
  required String tier,
  required String constellation,
  required int idx,
  required String sentence,
  required String kind,
  Value<String?> register,
  Value<int> rowid,
});
typedef $$PhrasesTableUpdateCompanionBuilder = PhrasesCompanion Function({
  Value<String> id,
  Value<String> lang,
  Value<String> tier,
  Value<String> constellation,
  Value<int> idx,
  Value<String> sentence,
  Value<String> kind,
  Value<String?> register,
  Value<int> rowid,
});

class $$PhrasesTableFilterComposer
    extends Composer<_$ContentDatabase, $PhrasesTable> {
  $$PhrasesTableFilterComposer({
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

  ColumnFilters<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get constellation => $composableBuilder(
    column: $table.constellation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get idx => $composableBuilder(
    column: $table.idx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sentence => $composableBuilder(
    column: $table.sentence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get register => $composableBuilder(
    column: $table.register,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PhrasesTableOrderingComposer
    extends Composer<_$ContentDatabase, $PhrasesTable> {
  $$PhrasesTableOrderingComposer({
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

  ColumnOrderings<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get constellation => $composableBuilder(
    column: $table.constellation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get idx => $composableBuilder(
    column: $table.idx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentence => $composableBuilder(
    column: $table.sentence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get register => $composableBuilder(
    column: $table.register,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhrasesTableAnnotationComposer
    extends Composer<_$ContentDatabase, $PhrasesTable> {
  $$PhrasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get lang =>
      $composableBuilder(column: $table.lang, builder: (column) => column);

  GeneratedColumn<String> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  GeneratedColumn<String> get constellation => $composableBuilder(
    column: $table.constellation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get idx =>
      $composableBuilder(column: $table.idx, builder: (column) => column);

  GeneratedColumn<String> get sentence =>
      $composableBuilder(column: $table.sentence, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get register =>
      $composableBuilder(column: $table.register, builder: (column) => column);
}

class $$PhrasesTableTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          $PhrasesTable,
          PhraseRow,
          $$PhrasesTableFilterComposer,
          $$PhrasesTableOrderingComposer,
          $$PhrasesTableAnnotationComposer,
          $$PhrasesTableCreateCompanionBuilder,
          $$PhrasesTableUpdateCompanionBuilder,
          (
            PhraseRow,
            BaseReferences<_$ContentDatabase, $PhrasesTable, PhraseRow>,
          ),
          PhraseRow,
          PrefetchHooks Function()
        > {
  $$PhrasesTableTableManager(_$ContentDatabase db, $PhrasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhrasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhrasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhrasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> lang = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<String> constellation = const Value.absent(),
                Value<int> idx = const Value.absent(),
                Value<String> sentence = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> register = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhrasesCompanion(
                id: id,
                lang: lang,
                tier: tier,
                constellation: constellation,
                idx: idx,
                sentence: sentence,
                kind: kind,
                register: register,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String lang,
                required String tier,
                required String constellation,
                required int idx,
                required String sentence,
                required String kind,
                Value<String?> register = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhrasesCompanion.insert(
                id: id,
                lang: lang,
                tier: tier,
                constellation: constellation,
                idx: idx,
                sentence: sentence,
                kind: kind,
                register: register,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PhrasesTable, PhraseRow>(table),
                  BaseReferences<_$ContentDatabase, $PhrasesTable, PhraseRow>(
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

typedef $$PhrasesTableProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      $PhrasesTable,
      PhraseRow,
      $$PhrasesTableFilterComposer,
      $$PhrasesTableOrderingComposer,
      $$PhrasesTableAnnotationComposer,
      $$PhrasesTableCreateCompanionBuilder,
      $$PhrasesTableUpdateCompanionBuilder,
      (PhraseRow, BaseReferences<_$ContentDatabase, $PhrasesTable, PhraseRow>),
      PhraseRow,
      PrefetchHooks Function()
    >;
typedef $$PhraseTranslationsTableCreateCompanionBuilder =
    PhraseTranslationsCompanion Function({
      required String phraseId,
      required String lang,
      required String sentence,
      Value<int> rowid,
    });
typedef $$PhraseTranslationsTableUpdateCompanionBuilder =
    PhraseTranslationsCompanion Function({
      Value<String> phraseId,
      Value<String> lang,
      Value<String> sentence,
      Value<int> rowid,
    });

class $$PhraseTranslationsTableFilterComposer
    extends Composer<_$ContentDatabase, $PhraseTranslationsTable> {
  $$PhraseTranslationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get phraseId => $composableBuilder(
    column: $table.phraseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sentence => $composableBuilder(
    column: $table.sentence,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PhraseTranslationsTableOrderingComposer
    extends Composer<_$ContentDatabase, $PhraseTranslationsTable> {
  $$PhraseTranslationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get phraseId => $composableBuilder(
    column: $table.phraseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentence => $composableBuilder(
    column: $table.sentence,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhraseTranslationsTableAnnotationComposer
    extends Composer<_$ContentDatabase, $PhraseTranslationsTable> {
  $$PhraseTranslationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get phraseId =>
      $composableBuilder(column: $table.phraseId, builder: (column) => column);

  GeneratedColumn<String> get lang =>
      $composableBuilder(column: $table.lang, builder: (column) => column);

  GeneratedColumn<String> get sentence =>
      $composableBuilder(column: $table.sentence, builder: (column) => column);
}

class $$PhraseTranslationsTableTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          $PhraseTranslationsTable,
          PhraseTranslationRow,
          $$PhraseTranslationsTableFilterComposer,
          $$PhraseTranslationsTableOrderingComposer,
          $$PhraseTranslationsTableAnnotationComposer,
          $$PhraseTranslationsTableCreateCompanionBuilder,
          $$PhraseTranslationsTableUpdateCompanionBuilder,
          (
            PhraseTranslationRow,
            BaseReferences<
              _$ContentDatabase,
              $PhraseTranslationsTable,
              PhraseTranslationRow
            >,
          ),
          PhraseTranslationRow,
          PrefetchHooks Function()
        > {
  $$PhraseTranslationsTableTableManager(
    _$ContentDatabase db,
    $PhraseTranslationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhraseTranslationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhraseTranslationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhraseTranslationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> phraseId = const Value.absent(),
                Value<String> lang = const Value.absent(),
                Value<String> sentence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhraseTranslationsCompanion(
                phraseId: phraseId,
                lang: lang,
                sentence: sentence,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String phraseId,
                required String lang,
                required String sentence,
                Value<int> rowid = const Value.absent(),
              }) => PhraseTranslationsCompanion.insert(
                phraseId: phraseId,
                lang: lang,
                sentence: sentence,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PhraseTranslationsTable, PhraseTranslationRow>(
                    table,
                  ),
                  BaseReferences<
                    _$ContentDatabase,
                    $PhraseTranslationsTable,
                    PhraseTranslationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PhraseTranslationsTableProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      $PhraseTranslationsTable,
      PhraseTranslationRow,
      $$PhraseTranslationsTableFilterComposer,
      $$PhraseTranslationsTableOrderingComposer,
      $$PhraseTranslationsTableAnnotationComposer,
      $$PhraseTranslationsTableCreateCompanionBuilder,
      $$PhraseTranslationsTableUpdateCompanionBuilder,
      (
        PhraseTranslationRow,
        BaseReferences<
          _$ContentDatabase,
          $PhraseTranslationsTable,
          PhraseTranslationRow
        >,
      ),
      PhraseTranslationRow,
      PrefetchHooks Function()
    >;
typedef $$ConstellationNamesTableCreateCompanionBuilder =
    ConstellationNamesCompanion Function({
      required String constellation,
      required String lang,
      required String name,
      Value<int> rowid,
    });
typedef $$ConstellationNamesTableUpdateCompanionBuilder =
    ConstellationNamesCompanion Function({
      Value<String> constellation,
      Value<String> lang,
      Value<String> name,
      Value<int> rowid,
    });

class $$ConstellationNamesTableFilterComposer
    extends Composer<_$ContentDatabase, $ConstellationNamesTable> {
  $$ConstellationNamesTableFilterComposer({
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

  ColumnFilters<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConstellationNamesTableOrderingComposer
    extends Composer<_$ContentDatabase, $ConstellationNamesTable> {
  $$ConstellationNamesTableOrderingComposer({
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

  ColumnOrderings<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConstellationNamesTableAnnotationComposer
    extends Composer<_$ContentDatabase, $ConstellationNamesTable> {
  $$ConstellationNamesTableAnnotationComposer({
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

  GeneratedColumn<String> get lang =>
      $composableBuilder(column: $table.lang, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$ConstellationNamesTableTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          $ConstellationNamesTable,
          ConstellationNameRow,
          $$ConstellationNamesTableFilterComposer,
          $$ConstellationNamesTableOrderingComposer,
          $$ConstellationNamesTableAnnotationComposer,
          $$ConstellationNamesTableCreateCompanionBuilder,
          $$ConstellationNamesTableUpdateCompanionBuilder,
          (
            ConstellationNameRow,
            BaseReferences<
              _$ContentDatabase,
              $ConstellationNamesTable,
              ConstellationNameRow
            >,
          ),
          ConstellationNameRow,
          PrefetchHooks Function()
        > {
  $$ConstellationNamesTableTableManager(
    _$ContentDatabase db,
    $ConstellationNamesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConstellationNamesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConstellationNamesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConstellationNamesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> constellation = const Value.absent(),
                Value<String> lang = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConstellationNamesCompanion(
                constellation: constellation,
                lang: lang,
                name: name,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String constellation,
                required String lang,
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => ConstellationNamesCompanion.insert(
                constellation: constellation,
                lang: lang,
                name: name,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ConstellationNamesTable, ConstellationNameRow>(
                    table,
                  ),
                  BaseReferences<
                    _$ContentDatabase,
                    $ConstellationNamesTable,
                    ConstellationNameRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConstellationNamesTableProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      $ConstellationNamesTable,
      ConstellationNameRow,
      $$ConstellationNamesTableFilterComposer,
      $$ConstellationNamesTableOrderingComposer,
      $$ConstellationNamesTableAnnotationComposer,
      $$ConstellationNamesTableCreateCompanionBuilder,
      $$ConstellationNamesTableUpdateCompanionBuilder,
      (
        ConstellationNameRow,
        BaseReferences<
          _$ContentDatabase,
          $ConstellationNamesTable,
          ConstellationNameRow
        >,
      ),
      ConstellationNameRow,
      PrefetchHooks Function()
    >;
typedef $$CalibrationItemsTableCreateCompanionBuilder =
    CalibrationItemsCompanion Function({
      required String id,
      required String tier,
      required String phraseId,
      required String kind,
      Value<int> rowid,
    });
typedef $$CalibrationItemsTableUpdateCompanionBuilder =
    CalibrationItemsCompanion Function({
      Value<String> id,
      Value<String> tier,
      Value<String> phraseId,
      Value<String> kind,
      Value<int> rowid,
    });

class $$CalibrationItemsTableFilterComposer
    extends Composer<_$ContentDatabase, $CalibrationItemsTable> {
  $$CalibrationItemsTableFilterComposer({
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

  ColumnFilters<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phraseId => $composableBuilder(
    column: $table.phraseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CalibrationItemsTableOrderingComposer
    extends Composer<_$ContentDatabase, $CalibrationItemsTable> {
  $$CalibrationItemsTableOrderingComposer({
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

  ColumnOrderings<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phraseId => $composableBuilder(
    column: $table.phraseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CalibrationItemsTableAnnotationComposer
    extends Composer<_$ContentDatabase, $CalibrationItemsTable> {
  $$CalibrationItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  GeneratedColumn<String> get phraseId =>
      $composableBuilder(column: $table.phraseId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);
}

class $$CalibrationItemsTableTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          $CalibrationItemsTable,
          CalibrationItemRow,
          $$CalibrationItemsTableFilterComposer,
          $$CalibrationItemsTableOrderingComposer,
          $$CalibrationItemsTableAnnotationComposer,
          $$CalibrationItemsTableCreateCompanionBuilder,
          $$CalibrationItemsTableUpdateCompanionBuilder,
          (
            CalibrationItemRow,
            BaseReferences<
              _$ContentDatabase,
              $CalibrationItemsTable,
              CalibrationItemRow
            >,
          ),
          CalibrationItemRow,
          PrefetchHooks Function()
        > {
  $$CalibrationItemsTableTableManager(
    _$ContentDatabase db,
    $CalibrationItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalibrationItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalibrationItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalibrationItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<String> phraseId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalibrationItemsCompanion(
                id: id,
                tier: tier,
                phraseId: phraseId,
                kind: kind,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tier,
                required String phraseId,
                required String kind,
                Value<int> rowid = const Value.absent(),
              }) => CalibrationItemsCompanion.insert(
                id: id,
                tier: tier,
                phraseId: phraseId,
                kind: kind,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CalibrationItemsTable, CalibrationItemRow>(
                    table,
                  ),
                  BaseReferences<
                    _$ContentDatabase,
                    $CalibrationItemsTable,
                    CalibrationItemRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CalibrationItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      $CalibrationItemsTable,
      CalibrationItemRow,
      $$CalibrationItemsTableFilterComposer,
      $$CalibrationItemsTableOrderingComposer,
      $$CalibrationItemsTableAnnotationComposer,
      $$CalibrationItemsTableCreateCompanionBuilder,
      $$CalibrationItemsTableUpdateCompanionBuilder,
      (
        CalibrationItemRow,
        BaseReferences<
          _$ContentDatabase,
          $CalibrationItemsTable,
          CalibrationItemRow
        >,
      ),
      CalibrationItemRow,
      PrefetchHooks Function()
    >;
typedef $$ContentMetaTableCreateCompanionBuilder =
    ContentMetaCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$ContentMetaTableUpdateCompanionBuilder =
    ContentMetaCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$ContentMetaTableFilterComposer
    extends Composer<_$ContentDatabase, $ContentMetaTable> {
  $$ContentMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentMetaTableOrderingComposer
    extends Composer<_$ContentDatabase, $ContentMetaTable> {
  $$ContentMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentMetaTableAnnotationComposer
    extends Composer<_$ContentDatabase, $ContentMetaTable> {
  $$ContentMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$ContentMetaTableTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          $ContentMetaTable,
          ContentMetaRow,
          $$ContentMetaTableFilterComposer,
          $$ContentMetaTableOrderingComposer,
          $$ContentMetaTableAnnotationComposer,
          $$ContentMetaTableCreateCompanionBuilder,
          $$ContentMetaTableUpdateCompanionBuilder,
          (
            ContentMetaRow,
            BaseReferences<
              _$ContentDatabase,
              $ContentMetaTable,
              ContentMetaRow
            >,
          ),
          ContentMetaRow,
          PrefetchHooks Function()
        > {
  $$ContentMetaTableTableManager(_$ContentDatabase db, $ContentMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => ContentMetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => ContentMetaCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ContentMetaTable, ContentMetaRow>(table),
                  BaseReferences<
                    _$ContentDatabase,
                    $ContentMetaTable,
                    ContentMetaRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      $ContentMetaTable,
      ContentMetaRow,
      $$ContentMetaTableFilterComposer,
      $$ContentMetaTableOrderingComposer,
      $$ContentMetaTableAnnotationComposer,
      $$ContentMetaTableCreateCompanionBuilder,
      $$ContentMetaTableUpdateCompanionBuilder,
      (
        ContentMetaRow,
        BaseReferences<_$ContentDatabase, $ContentMetaTable, ContentMetaRow>,
      ),
      ContentMetaRow,
      PrefetchHooks Function()
    >;

class $ContentDatabaseManager {
  final _$ContentDatabase _db;
  $ContentDatabaseManager(this._db);
  $$LanguagesTableTableManager get languages =>
      $$LanguagesTableTableManager(_db, _db.languages);
  $$PhrasesTableTableManager get phrases =>
      $$PhrasesTableTableManager(_db, _db.phrases);
  $$PhraseTranslationsTableTableManager get phraseTranslations =>
      $$PhraseTranslationsTableTableManager(_db, _db.phraseTranslations);
  $$ConstellationNamesTableTableManager get constellationNames =>
      $$ConstellationNamesTableTableManager(_db, _db.constellationNames);
  $$CalibrationItemsTableTableManager get calibrationItems =>
      $$CalibrationItemsTableTableManager(_db, _db.calibrationItems);
  $$ContentMetaTableTableManager get contentMeta =>
      $$ContentMetaTableTableManager(_db, _db.contentMeta);
}
