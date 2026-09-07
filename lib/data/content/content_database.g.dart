// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_database.dart';

// ignore_for_file: type=lint
class $ConceptsTable extends Concepts
    with TableInfo<$ConceptsTable, ConceptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConceptsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _posMeta = const VerificationMeta('pos');
  @override
  late final GeneratedColumn<String> pos = GeneratedColumn<String>(
    'pos',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _freqRankMeta = const VerificationMeta(
    'freqRank',
  );
  @override
  late final GeneratedColumn<int> freqRank = GeneratedColumn<int>(
    'freq_rank',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tier,
    constellation,
    pos,
    freqRank,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'concepts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConceptRow> instance, {
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
    if (data.containsKey('pos')) {
      context.handle(
        _posMeta,
        pos.isAcceptableOrUnknown(data['pos']!, _posMeta),
      );
    } else if (isInserting) {
      context.missing(_posMeta);
    }
    if (data.containsKey('freq_rank')) {
      context.handle(
        _freqRankMeta,
        freqRank.isAcceptableOrUnknown(data['freq_rank']!, _freqRankMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConceptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConceptRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tier'],
      )!,
      constellation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}constellation'],
      )!,
      pos: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pos'],
      )!,
      freqRank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}freq_rank'],
      ),
    );
  }

  @override
  $ConceptsTable createAlias(String alias) {
    return $ConceptsTable(attachedDatabase, alias);
  }
}

class ConceptRow extends DataClass implements Insertable<ConceptRow> {
  final String id;
  final String tier;
  final String constellation;
  final String pos;
  final int? freqRank;
  const ConceptRow({
    required this.id,
    required this.tier,
    required this.constellation,
    required this.pos,
    this.freqRank,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tier'] = Variable<String>(tier);
    map['constellation'] = Variable<String>(constellation);
    map['pos'] = Variable<String>(pos);
    if (!nullToAbsent || freqRank != null) {
      map['freq_rank'] = Variable<int>(freqRank);
    }
    return map;
  }

  ConceptsCompanion toCompanion(bool nullToAbsent) {
    return ConceptsCompanion(
      id: Value(id),
      tier: Value(tier),
      constellation: Value(constellation),
      pos: Value(pos),
      freqRank: freqRank == null && nullToAbsent
          ? const Value.absent()
          : Value(freqRank),
    );
  }

  factory ConceptRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConceptRow(
      id: serializer.fromJson<String>(json['id']),
      tier: serializer.fromJson<String>(json['tier']),
      constellation: serializer.fromJson<String>(json['constellation']),
      pos: serializer.fromJson<String>(json['pos']),
      freqRank: serializer.fromJson<int?>(json['freqRank']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tier': serializer.toJson<String>(tier),
      'constellation': serializer.toJson<String>(constellation),
      'pos': serializer.toJson<String>(pos),
      'freqRank': serializer.toJson<int?>(freqRank),
    };
  }

  ConceptRow copyWith({
    String? id,
    String? tier,
    String? constellation,
    String? pos,
    Value<int?> freqRank = const Value.absent(),
  }) => ConceptRow(
    id: id ?? this.id,
    tier: tier ?? this.tier,
    constellation: constellation ?? this.constellation,
    pos: pos ?? this.pos,
    freqRank: freqRank.present ? freqRank.value : this.freqRank,
  );
  ConceptRow copyWithCompanion(ConceptsCompanion data) {
    return ConceptRow(
      id: data.id.present ? data.id.value : this.id,
      tier: data.tier.present ? data.tier.value : this.tier,
      constellation: data.constellation.present
          ? data.constellation.value
          : this.constellation,
      pos: data.pos.present ? data.pos.value : this.pos,
      freqRank: data.freqRank.present ? data.freqRank.value : this.freqRank,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConceptRow(')
          ..write('id: $id, ')
          ..write('tier: $tier, ')
          ..write('constellation: $constellation, ')
          ..write('pos: $pos, ')
          ..write('freqRank: $freqRank')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tier, constellation, pos, freqRank);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConceptRow &&
          other.id == this.id &&
          other.tier == this.tier &&
          other.constellation == this.constellation &&
          other.pos == this.pos &&
          other.freqRank == this.freqRank);
}

class ConceptsCompanion extends UpdateCompanion<ConceptRow> {
  final Value<String> id;
  final Value<String> tier;
  final Value<String> constellation;
  final Value<String> pos;
  final Value<int?> freqRank;
  final Value<int> rowid;
  const ConceptsCompanion({
    this.id = const Value.absent(),
    this.tier = const Value.absent(),
    this.constellation = const Value.absent(),
    this.pos = const Value.absent(),
    this.freqRank = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConceptsCompanion.insert({
    required String id,
    required String tier,
    required String constellation,
    required String pos,
    this.freqRank = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tier = Value(tier),
       constellation = Value(constellation),
       pos = Value(pos);
  static Insertable<ConceptRow> custom({
    Expression<String>? id,
    Expression<String>? tier,
    Expression<String>? constellation,
    Expression<String>? pos,
    Expression<int>? freqRank,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tier != null) 'tier': tier,
      if (constellation != null) 'constellation': constellation,
      if (pos != null) 'pos': pos,
      if (freqRank != null) 'freq_rank': freqRank,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConceptsCompanion copyWith({
    Value<String>? id,
    Value<String>? tier,
    Value<String>? constellation,
    Value<String>? pos,
    Value<int?>? freqRank,
    Value<int>? rowid,
  }) {
    return ConceptsCompanion(
      id: id ?? this.id,
      tier: tier ?? this.tier,
      constellation: constellation ?? this.constellation,
      pos: pos ?? this.pos,
      freqRank: freqRank ?? this.freqRank,
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
    if (constellation.present) {
      map['constellation'] = Variable<String>(constellation.value);
    }
    if (pos.present) {
      map['pos'] = Variable<String>(pos.value);
    }
    if (freqRank.present) {
      map['freq_rank'] = Variable<int>(freqRank.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConceptsCompanion(')
          ..write('id: $id, ')
          ..write('tier: $tier, ')
          ..write('constellation: $constellation, ')
          ..write('pos: $pos, ')
          ..write('freqRank: $freqRank, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LexemesTable extends Lexemes with TableInfo<$LexemesTable, LexemeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LexemesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _langMeta = const VerificationMeta('lang');
  @override
  late final GeneratedColumn<String> lang = GeneratedColumn<String>(
    'lang',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formMeta = const VerificationMeta('form');
  @override
  late final GeneratedColumn<String> form = GeneratedColumn<String>(
    'form',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _articleMeta = const VerificationMeta(
    'article',
  );
  @override
  late final GeneratedColumn<String> article = GeneratedColumn<String>(
    'article',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
    'gender',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pluralMeta = const VerificationMeta('plural');
  @override
  late final GeneratedColumn<String> plural = GeneratedColumn<String>(
    'plural',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    conceptId,
    lang,
    form,
    article,
    gender,
    plural,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lexemes';
  @override
  VerificationContext validateIntegrity(
    Insertable<LexemeRow> instance, {
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
    if (data.containsKey('lang')) {
      context.handle(
        _langMeta,
        lang.isAcceptableOrUnknown(data['lang']!, _langMeta),
      );
    } else if (isInserting) {
      context.missing(_langMeta);
    }
    if (data.containsKey('form')) {
      context.handle(
        _formMeta,
        form.isAcceptableOrUnknown(data['form']!, _formMeta),
      );
    } else if (isInserting) {
      context.missing(_formMeta);
    }
    if (data.containsKey('article')) {
      context.handle(
        _articleMeta,
        article.isAcceptableOrUnknown(data['article']!, _articleMeta),
      );
    }
    if (data.containsKey('gender')) {
      context.handle(
        _genderMeta,
        gender.isAcceptableOrUnknown(data['gender']!, _genderMeta),
      );
    }
    if (data.containsKey('plural')) {
      context.handle(
        _pluralMeta,
        plural.isAcceptableOrUnknown(data['plural']!, _pluralMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {conceptId, lang};
  @override
  LexemeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LexemeRow(
      conceptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}concept_id'],
      )!,
      lang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lang'],
      )!,
      form: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}form'],
      )!,
      article: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}article'],
      ),
      gender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gender'],
      ),
      plural: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plural'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $LexemesTable createAlias(String alias) {
    return $LexemesTable(attachedDatabase, alias);
  }
}

class LexemeRow extends DataClass implements Insertable<LexemeRow> {
  final String conceptId;
  final String lang;
  final String form;
  final String? article;
  final String? gender;
  final String? plural;
  final String? note;
  const LexemeRow({
    required this.conceptId,
    required this.lang,
    required this.form,
    this.article,
    this.gender,
    this.plural,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['concept_id'] = Variable<String>(conceptId);
    map['lang'] = Variable<String>(lang);
    map['form'] = Variable<String>(form);
    if (!nullToAbsent || article != null) {
      map['article'] = Variable<String>(article);
    }
    if (!nullToAbsent || gender != null) {
      map['gender'] = Variable<String>(gender);
    }
    if (!nullToAbsent || plural != null) {
      map['plural'] = Variable<String>(plural);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  LexemesCompanion toCompanion(bool nullToAbsent) {
    return LexemesCompanion(
      conceptId: Value(conceptId),
      lang: Value(lang),
      form: Value(form),
      article: article == null && nullToAbsent
          ? const Value.absent()
          : Value(article),
      gender: gender == null && nullToAbsent
          ? const Value.absent()
          : Value(gender),
      plural: plural == null && nullToAbsent
          ? const Value.absent()
          : Value(plural),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory LexemeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LexemeRow(
      conceptId: serializer.fromJson<String>(json['conceptId']),
      lang: serializer.fromJson<String>(json['lang']),
      form: serializer.fromJson<String>(json['form']),
      article: serializer.fromJson<String?>(json['article']),
      gender: serializer.fromJson<String?>(json['gender']),
      plural: serializer.fromJson<String?>(json['plural']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conceptId': serializer.toJson<String>(conceptId),
      'lang': serializer.toJson<String>(lang),
      'form': serializer.toJson<String>(form),
      'article': serializer.toJson<String?>(article),
      'gender': serializer.toJson<String?>(gender),
      'plural': serializer.toJson<String?>(plural),
      'note': serializer.toJson<String?>(note),
    };
  }

  LexemeRow copyWith({
    String? conceptId,
    String? lang,
    String? form,
    Value<String?> article = const Value.absent(),
    Value<String?> gender = const Value.absent(),
    Value<String?> plural = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => LexemeRow(
    conceptId: conceptId ?? this.conceptId,
    lang: lang ?? this.lang,
    form: form ?? this.form,
    article: article.present ? article.value : this.article,
    gender: gender.present ? gender.value : this.gender,
    plural: plural.present ? plural.value : this.plural,
    note: note.present ? note.value : this.note,
  );
  LexemeRow copyWithCompanion(LexemesCompanion data) {
    return LexemeRow(
      conceptId: data.conceptId.present ? data.conceptId.value : this.conceptId,
      lang: data.lang.present ? data.lang.value : this.lang,
      form: data.form.present ? data.form.value : this.form,
      article: data.article.present ? data.article.value : this.article,
      gender: data.gender.present ? data.gender.value : this.gender,
      plural: data.plural.present ? data.plural.value : this.plural,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LexemeRow(')
          ..write('conceptId: $conceptId, ')
          ..write('lang: $lang, ')
          ..write('form: $form, ')
          ..write('article: $article, ')
          ..write('gender: $gender, ')
          ..write('plural: $plural, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(conceptId, lang, form, article, gender, plural, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LexemeRow &&
          other.conceptId == this.conceptId &&
          other.lang == this.lang &&
          other.form == this.form &&
          other.article == this.article &&
          other.gender == this.gender &&
          other.plural == this.plural &&
          other.note == this.note);
}

class LexemesCompanion extends UpdateCompanion<LexemeRow> {
  final Value<String> conceptId;
  final Value<String> lang;
  final Value<String> form;
  final Value<String?> article;
  final Value<String?> gender;
  final Value<String?> plural;
  final Value<String?> note;
  final Value<int> rowid;
  const LexemesCompanion({
    this.conceptId = const Value.absent(),
    this.lang = const Value.absent(),
    this.form = const Value.absent(),
    this.article = const Value.absent(),
    this.gender = const Value.absent(),
    this.plural = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LexemesCompanion.insert({
    required String conceptId,
    required String lang,
    required String form,
    this.article = const Value.absent(),
    this.gender = const Value.absent(),
    this.plural = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : conceptId = Value(conceptId),
       lang = Value(lang),
       form = Value(form);
  static Insertable<LexemeRow> custom({
    Expression<String>? conceptId,
    Expression<String>? lang,
    Expression<String>? form,
    Expression<String>? article,
    Expression<String>? gender,
    Expression<String>? plural,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (conceptId != null) 'concept_id': conceptId,
      if (lang != null) 'lang': lang,
      if (form != null) 'form': form,
      if (article != null) 'article': article,
      if (gender != null) 'gender': gender,
      if (plural != null) 'plural': plural,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LexemesCompanion copyWith({
    Value<String>? conceptId,
    Value<String>? lang,
    Value<String>? form,
    Value<String?>? article,
    Value<String?>? gender,
    Value<String?>? plural,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return LexemesCompanion(
      conceptId: conceptId ?? this.conceptId,
      lang: lang ?? this.lang,
      form: form ?? this.form,
      article: article ?? this.article,
      gender: gender ?? this.gender,
      plural: plural ?? this.plural,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conceptId.present) {
      map['concept_id'] = Variable<String>(conceptId.value);
    }
    if (lang.present) {
      map['lang'] = Variable<String>(lang.value);
    }
    if (form.present) {
      map['form'] = Variable<String>(form.value);
    }
    if (article.present) {
      map['article'] = Variable<String>(article.value);
    }
    if (gender.present) {
      map['gender'] = Variable<String>(gender.value);
    }
    if (plural.present) {
      map['plural'] = Variable<String>(plural.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LexemesCompanion(')
          ..write('conceptId: $conceptId, ')
          ..write('lang: $lang, ')
          ..write('form: $form, ')
          ..write('article: $article, ')
          ..write('gender: $gender, ')
          ..write('plural: $plural, ')
          ..write('note: $note, ')
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
  static const VerificationMeta _templateMeta = const VerificationMeta(
    'template',
  );
  @override
  late final GeneratedColumn<String> template = GeneratedColumn<String>(
    'template',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>(
    'answer',
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
    template,
    answer,
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
    if (data.containsKey('template')) {
      context.handle(
        _templateMeta,
        template.isAcceptableOrUnknown(data['template']!, _templateMeta),
      );
    } else if (isInserting) {
      context.missing(_templateMeta);
    }
    if (data.containsKey('answer')) {
      context.handle(
        _answerMeta,
        answer.isAcceptableOrUnknown(data['answer']!, _answerMeta),
      );
    } else if (isInserting) {
      context.missing(_answerMeta);
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
      template: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template'],
      )!,
      answer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer'],
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
  final String lang;
  final String tier;
  final String constellation;
  final String template;
  final String answer;
  final String? register;
  const PhraseRow({
    required this.id,
    required this.lang,
    required this.tier,
    required this.constellation,
    required this.template,
    required this.answer,
    this.register,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['lang'] = Variable<String>(lang);
    map['tier'] = Variable<String>(tier);
    map['constellation'] = Variable<String>(constellation);
    map['template'] = Variable<String>(template);
    map['answer'] = Variable<String>(answer);
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
      template: Value(template),
      answer: Value(answer),
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
      template: serializer.fromJson<String>(json['template']),
      answer: serializer.fromJson<String>(json['answer']),
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
      'template': serializer.toJson<String>(template),
      'answer': serializer.toJson<String>(answer),
      'register': serializer.toJson<String?>(register),
    };
  }

  PhraseRow copyWith({
    String? id,
    String? lang,
    String? tier,
    String? constellation,
    String? template,
    String? answer,
    Value<String?> register = const Value.absent(),
  }) => PhraseRow(
    id: id ?? this.id,
    lang: lang ?? this.lang,
    tier: tier ?? this.tier,
    constellation: constellation ?? this.constellation,
    template: template ?? this.template,
    answer: answer ?? this.answer,
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
      template: data.template.present ? data.template.value : this.template,
      answer: data.answer.present ? data.answer.value : this.answer,
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
          ..write('template: $template, ')
          ..write('answer: $answer, ')
          ..write('register: $register')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, lang, tier, constellation, template, answer, register);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhraseRow &&
          other.id == this.id &&
          other.lang == this.lang &&
          other.tier == this.tier &&
          other.constellation == this.constellation &&
          other.template == this.template &&
          other.answer == this.answer &&
          other.register == this.register);
}

class PhrasesCompanion extends UpdateCompanion<PhraseRow> {
  final Value<String> id;
  final Value<String> lang;
  final Value<String> tier;
  final Value<String> constellation;
  final Value<String> template;
  final Value<String> answer;
  final Value<String?> register;
  final Value<int> rowid;
  const PhrasesCompanion({
    this.id = const Value.absent(),
    this.lang = const Value.absent(),
    this.tier = const Value.absent(),
    this.constellation = const Value.absent(),
    this.template = const Value.absent(),
    this.answer = const Value.absent(),
    this.register = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhrasesCompanion.insert({
    required String id,
    required String lang,
    required String tier,
    required String constellation,
    required String template,
    required String answer,
    this.register = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       lang = Value(lang),
       tier = Value(tier),
       constellation = Value(constellation),
       template = Value(template),
       answer = Value(answer);
  static Insertable<PhraseRow> custom({
    Expression<String>? id,
    Expression<String>? lang,
    Expression<String>? tier,
    Expression<String>? constellation,
    Expression<String>? template,
    Expression<String>? answer,
    Expression<String>? register,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lang != null) 'lang': lang,
      if (tier != null) 'tier': tier,
      if (constellation != null) 'constellation': constellation,
      if (template != null) 'template': template,
      if (answer != null) 'answer': answer,
      if (register != null) 'register': register,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhrasesCompanion copyWith({
    Value<String>? id,
    Value<String>? lang,
    Value<String>? tier,
    Value<String>? constellation,
    Value<String>? template,
    Value<String>? answer,
    Value<String?>? register,
    Value<int>? rowid,
  }) {
    return PhrasesCompanion(
      id: id ?? this.id,
      lang: lang ?? this.lang,
      tier: tier ?? this.tier,
      constellation: constellation ?? this.constellation,
      template: template ?? this.template,
      answer: answer ?? this.answer,
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
    if (template.present) {
      map['template'] = Variable<String>(template.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
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
          ..write('template: $template, ')
          ..write('answer: $answer, ')
          ..write('register: $register, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhraseConceptsTable extends PhraseConcepts
    with TableInfo<$PhraseConceptsTable, PhraseConceptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhraseConceptsTable(this.attachedDatabase, [this._alias]);
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
  @override
  List<GeneratedColumn> get $columns => [phraseId, conceptId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'phrase_concepts';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhraseConceptRow> instance, {
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
    if (data.containsKey('concept_id')) {
      context.handle(
        _conceptIdMeta,
        conceptId.isAcceptableOrUnknown(data['concept_id']!, _conceptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_conceptIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {phraseId, conceptId};
  @override
  PhraseConceptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhraseConceptRow(
      phraseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phrase_id'],
      )!,
      conceptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}concept_id'],
      )!,
    );
  }

  @override
  $PhraseConceptsTable createAlias(String alias) {
    return $PhraseConceptsTable(attachedDatabase, alias);
  }
}

class PhraseConceptRow extends DataClass
    implements Insertable<PhraseConceptRow> {
  final String phraseId;
  final String conceptId;
  const PhraseConceptRow({required this.phraseId, required this.conceptId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['phrase_id'] = Variable<String>(phraseId);
    map['concept_id'] = Variable<String>(conceptId);
    return map;
  }

  PhraseConceptsCompanion toCompanion(bool nullToAbsent) {
    return PhraseConceptsCompanion(
      phraseId: Value(phraseId),
      conceptId: Value(conceptId),
    );
  }

  factory PhraseConceptRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhraseConceptRow(
      phraseId: serializer.fromJson<String>(json['phraseId']),
      conceptId: serializer.fromJson<String>(json['conceptId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'phraseId': serializer.toJson<String>(phraseId),
      'conceptId': serializer.toJson<String>(conceptId),
    };
  }

  PhraseConceptRow copyWith({String? phraseId, String? conceptId}) =>
      PhraseConceptRow(
        phraseId: phraseId ?? this.phraseId,
        conceptId: conceptId ?? this.conceptId,
      );
  PhraseConceptRow copyWithCompanion(PhraseConceptsCompanion data) {
    return PhraseConceptRow(
      phraseId: data.phraseId.present ? data.phraseId.value : this.phraseId,
      conceptId: data.conceptId.present ? data.conceptId.value : this.conceptId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhraseConceptRow(')
          ..write('phraseId: $phraseId, ')
          ..write('conceptId: $conceptId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(phraseId, conceptId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhraseConceptRow &&
          other.phraseId == this.phraseId &&
          other.conceptId == this.conceptId);
}

class PhraseConceptsCompanion extends UpdateCompanion<PhraseConceptRow> {
  final Value<String> phraseId;
  final Value<String> conceptId;
  final Value<int> rowid;
  const PhraseConceptsCompanion({
    this.phraseId = const Value.absent(),
    this.conceptId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhraseConceptsCompanion.insert({
    required String phraseId,
    required String conceptId,
    this.rowid = const Value.absent(),
  }) : phraseId = Value(phraseId),
       conceptId = Value(conceptId);
  static Insertable<PhraseConceptRow> custom({
    Expression<String>? phraseId,
    Expression<String>? conceptId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (phraseId != null) 'phrase_id': phraseId,
      if (conceptId != null) 'concept_id': conceptId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhraseConceptsCompanion copyWith({
    Value<String>? phraseId,
    Value<String>? conceptId,
    Value<int>? rowid,
  }) {
    return PhraseConceptsCompanion(
      phraseId: phraseId ?? this.phraseId,
      conceptId: conceptId ?? this.conceptId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (phraseId.present) {
      map['phrase_id'] = Variable<String>(phraseId.value);
    }
    if (conceptId.present) {
      map['concept_id'] = Variable<String>(conceptId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhraseConceptsCompanion(')
          ..write('phraseId: $phraseId, ')
          ..write('conceptId: $conceptId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DistractorsTable extends Distractors
    with TableInfo<$DistractorsTable, DistractorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DistractorsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _langMeta = const VerificationMeta('lang');
  @override
  late final GeneratedColumn<String> lang = GeneratedColumn<String>(
    'lang',
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
  static const VerificationMeta _formMeta = const VerificationMeta('form');
  @override
  late final GeneratedColumn<String> form = GeneratedColumn<String>(
    'form',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [conceptId, lang, kind, form];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'distractors';
  @override
  VerificationContext validateIntegrity(
    Insertable<DistractorRow> instance, {
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
    if (data.containsKey('lang')) {
      context.handle(
        _langMeta,
        lang.isAcceptableOrUnknown(data['lang']!, _langMeta),
      );
    } else if (isInserting) {
      context.missing(_langMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('form')) {
      context.handle(
        _formMeta,
        form.isAcceptableOrUnknown(data['form']!, _formMeta),
      );
    } else if (isInserting) {
      context.missing(_formMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {conceptId, lang, form};
  @override
  DistractorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DistractorRow(
      conceptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}concept_id'],
      )!,
      lang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lang'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      form: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}form'],
      )!,
    );
  }

  @override
  $DistractorsTable createAlias(String alias) {
    return $DistractorsTable(attachedDatabase, alias);
  }
}

class DistractorRow extends DataClass implements Insertable<DistractorRow> {
  final String conceptId;
  final String lang;
  final String kind;
  final String form;
  const DistractorRow({
    required this.conceptId,
    required this.lang,
    required this.kind,
    required this.form,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['concept_id'] = Variable<String>(conceptId);
    map['lang'] = Variable<String>(lang);
    map['kind'] = Variable<String>(kind);
    map['form'] = Variable<String>(form);
    return map;
  }

  DistractorsCompanion toCompanion(bool nullToAbsent) {
    return DistractorsCompanion(
      conceptId: Value(conceptId),
      lang: Value(lang),
      kind: Value(kind),
      form: Value(form),
    );
  }

  factory DistractorRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DistractorRow(
      conceptId: serializer.fromJson<String>(json['conceptId']),
      lang: serializer.fromJson<String>(json['lang']),
      kind: serializer.fromJson<String>(json['kind']),
      form: serializer.fromJson<String>(json['form']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conceptId': serializer.toJson<String>(conceptId),
      'lang': serializer.toJson<String>(lang),
      'kind': serializer.toJson<String>(kind),
      'form': serializer.toJson<String>(form),
    };
  }

  DistractorRow copyWith({
    String? conceptId,
    String? lang,
    String? kind,
    String? form,
  }) => DistractorRow(
    conceptId: conceptId ?? this.conceptId,
    lang: lang ?? this.lang,
    kind: kind ?? this.kind,
    form: form ?? this.form,
  );
  DistractorRow copyWithCompanion(DistractorsCompanion data) {
    return DistractorRow(
      conceptId: data.conceptId.present ? data.conceptId.value : this.conceptId,
      lang: data.lang.present ? data.lang.value : this.lang,
      kind: data.kind.present ? data.kind.value : this.kind,
      form: data.form.present ? data.form.value : this.form,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DistractorRow(')
          ..write('conceptId: $conceptId, ')
          ..write('lang: $lang, ')
          ..write('kind: $kind, ')
          ..write('form: $form')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(conceptId, lang, kind, form);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DistractorRow &&
          other.conceptId == this.conceptId &&
          other.lang == this.lang &&
          other.kind == this.kind &&
          other.form == this.form);
}

class DistractorsCompanion extends UpdateCompanion<DistractorRow> {
  final Value<String> conceptId;
  final Value<String> lang;
  final Value<String> kind;
  final Value<String> form;
  final Value<int> rowid;
  const DistractorsCompanion({
    this.conceptId = const Value.absent(),
    this.lang = const Value.absent(),
    this.kind = const Value.absent(),
    this.form = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DistractorsCompanion.insert({
    required String conceptId,
    required String lang,
    required String kind,
    required String form,
    this.rowid = const Value.absent(),
  }) : conceptId = Value(conceptId),
       lang = Value(lang),
       kind = Value(kind),
       form = Value(form);
  static Insertable<DistractorRow> custom({
    Expression<String>? conceptId,
    Expression<String>? lang,
    Expression<String>? kind,
    Expression<String>? form,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (conceptId != null) 'concept_id': conceptId,
      if (lang != null) 'lang': lang,
      if (kind != null) 'kind': kind,
      if (form != null) 'form': form,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DistractorsCompanion copyWith({
    Value<String>? conceptId,
    Value<String>? lang,
    Value<String>? kind,
    Value<String>? form,
    Value<int>? rowid,
  }) {
    return DistractorsCompanion(
      conceptId: conceptId ?? this.conceptId,
      lang: lang ?? this.lang,
      kind: kind ?? this.kind,
      form: form ?? this.form,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conceptId.present) {
      map['concept_id'] = Variable<String>(conceptId.value);
    }
    if (lang.present) {
      map['lang'] = Variable<String>(lang.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (form.present) {
      map['form'] = Variable<String>(form.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DistractorsCompanion(')
          ..write('conceptId: $conceptId, ')
          ..write('lang: $lang, ')
          ..write('kind: $kind, ')
          ..write('form: $form, ')
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
  static const VerificationMeta _conceptIdMeta = const VerificationMeta(
    'conceptId',
  );
  @override
  late final GeneratedColumn<String> conceptId = GeneratedColumn<String>(
    'concept_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phraseIdMeta = const VerificationMeta(
    'phraseId',
  );
  @override
  late final GeneratedColumn<String> phraseId = GeneratedColumn<String>(
    'phrase_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  List<GeneratedColumn> get $columns => [id, tier, conceptId, phraseId, kind];
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
    if (data.containsKey('concept_id')) {
      context.handle(
        _conceptIdMeta,
        conceptId.isAcceptableOrUnknown(data['concept_id']!, _conceptIdMeta),
      );
    }
    if (data.containsKey('phrase_id')) {
      context.handle(
        _phraseIdMeta,
        phraseId.isAcceptableOrUnknown(data['phrase_id']!, _phraseIdMeta),
      );
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
      conceptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}concept_id'],
      ),
      phraseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phrase_id'],
      ),
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
  final String? conceptId;
  final String? phraseId;
  final String kind;
  const CalibrationItemRow({
    required this.id,
    required this.tier,
    this.conceptId,
    this.phraseId,
    required this.kind,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tier'] = Variable<String>(tier);
    if (!nullToAbsent || conceptId != null) {
      map['concept_id'] = Variable<String>(conceptId);
    }
    if (!nullToAbsent || phraseId != null) {
      map['phrase_id'] = Variable<String>(phraseId);
    }
    map['kind'] = Variable<String>(kind);
    return map;
  }

  CalibrationItemsCompanion toCompanion(bool nullToAbsent) {
    return CalibrationItemsCompanion(
      id: Value(id),
      tier: Value(tier),
      conceptId: conceptId == null && nullToAbsent
          ? const Value.absent()
          : Value(conceptId),
      phraseId: phraseId == null && nullToAbsent
          ? const Value.absent()
          : Value(phraseId),
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
      conceptId: serializer.fromJson<String?>(json['conceptId']),
      phraseId: serializer.fromJson<String?>(json['phraseId']),
      kind: serializer.fromJson<String>(json['kind']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tier': serializer.toJson<String>(tier),
      'conceptId': serializer.toJson<String?>(conceptId),
      'phraseId': serializer.toJson<String?>(phraseId),
      'kind': serializer.toJson<String>(kind),
    };
  }

  CalibrationItemRow copyWith({
    String? id,
    String? tier,
    Value<String?> conceptId = const Value.absent(),
    Value<String?> phraseId = const Value.absent(),
    String? kind,
  }) => CalibrationItemRow(
    id: id ?? this.id,
    tier: tier ?? this.tier,
    conceptId: conceptId.present ? conceptId.value : this.conceptId,
    phraseId: phraseId.present ? phraseId.value : this.phraseId,
    kind: kind ?? this.kind,
  );
  CalibrationItemRow copyWithCompanion(CalibrationItemsCompanion data) {
    return CalibrationItemRow(
      id: data.id.present ? data.id.value : this.id,
      tier: data.tier.present ? data.tier.value : this.tier,
      conceptId: data.conceptId.present ? data.conceptId.value : this.conceptId,
      phraseId: data.phraseId.present ? data.phraseId.value : this.phraseId,
      kind: data.kind.present ? data.kind.value : this.kind,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalibrationItemRow(')
          ..write('id: $id, ')
          ..write('tier: $tier, ')
          ..write('conceptId: $conceptId, ')
          ..write('phraseId: $phraseId, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tier, conceptId, phraseId, kind);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalibrationItemRow &&
          other.id == this.id &&
          other.tier == this.tier &&
          other.conceptId == this.conceptId &&
          other.phraseId == this.phraseId &&
          other.kind == this.kind);
}

class CalibrationItemsCompanion extends UpdateCompanion<CalibrationItemRow> {
  final Value<String> id;
  final Value<String> tier;
  final Value<String?> conceptId;
  final Value<String?> phraseId;
  final Value<String> kind;
  final Value<int> rowid;
  const CalibrationItemsCompanion({
    this.id = const Value.absent(),
    this.tier = const Value.absent(),
    this.conceptId = const Value.absent(),
    this.phraseId = const Value.absent(),
    this.kind = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalibrationItemsCompanion.insert({
    required String id,
    required String tier,
    this.conceptId = const Value.absent(),
    this.phraseId = const Value.absent(),
    required String kind,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tier = Value(tier),
       kind = Value(kind);
  static Insertable<CalibrationItemRow> custom({
    Expression<String>? id,
    Expression<String>? tier,
    Expression<String>? conceptId,
    Expression<String>? phraseId,
    Expression<String>? kind,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tier != null) 'tier': tier,
      if (conceptId != null) 'concept_id': conceptId,
      if (phraseId != null) 'phrase_id': phraseId,
      if (kind != null) 'kind': kind,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalibrationItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? tier,
    Value<String?>? conceptId,
    Value<String?>? phraseId,
    Value<String>? kind,
    Value<int>? rowid,
  }) {
    return CalibrationItemsCompanion(
      id: id ?? this.id,
      tier: tier ?? this.tier,
      conceptId: conceptId ?? this.conceptId,
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
    if (conceptId.present) {
      map['concept_id'] = Variable<String>(conceptId.value);
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
          ..write('conceptId: $conceptId, ')
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
  late final $ConceptsTable concepts = $ConceptsTable(this);
  late final $LexemesTable lexemes = $LexemesTable(this);
  late final $PhrasesTable phrases = $PhrasesTable(this);
  late final $PhraseConceptsTable phraseConcepts = $PhraseConceptsTable(this);
  late final $DistractorsTable distractors = $DistractorsTable(this);
  late final $CalibrationItemsTable calibrationItems = $CalibrationItemsTable(
    this,
  );
  late final $ContentMetaTable contentMeta = $ContentMetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    concepts,
    lexemes,
    phrases,
    phraseConcepts,
    distractors,
    calibrationItems,
    contentMeta,
  ];
}

typedef $$ConceptsTableCreateCompanionBuilder = ConceptsCompanion Function({
  required String id,
  required String tier,
  required String constellation,
  required String pos,
  Value<int?> freqRank,
  Value<int> rowid,
});
typedef $$ConceptsTableUpdateCompanionBuilder = ConceptsCompanion Function({
  Value<String> id,
  Value<String> tier,
  Value<String> constellation,
  Value<String> pos,
  Value<int?> freqRank,
  Value<int> rowid,
});

class $$ConceptsTableFilterComposer
    extends Composer<_$ContentDatabase, $ConceptsTable> {
  $$ConceptsTableFilterComposer({
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

  ColumnFilters<String> get constellation => $composableBuilder(
    column: $table.constellation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pos => $composableBuilder(
    column: $table.pos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get freqRank => $composableBuilder(
    column: $table.freqRank,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConceptsTableOrderingComposer
    extends Composer<_$ContentDatabase, $ConceptsTable> {
  $$ConceptsTableOrderingComposer({
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

  ColumnOrderings<String> get constellation => $composableBuilder(
    column: $table.constellation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pos => $composableBuilder(
    column: $table.pos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get freqRank => $composableBuilder(
    column: $table.freqRank,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConceptsTableAnnotationComposer
    extends Composer<_$ContentDatabase, $ConceptsTable> {
  $$ConceptsTableAnnotationComposer({
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

  GeneratedColumn<String> get constellation => $composableBuilder(
    column: $table.constellation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pos =>
      $composableBuilder(column: $table.pos, builder: (column) => column);

  GeneratedColumn<int> get freqRank =>
      $composableBuilder(column: $table.freqRank, builder: (column) => column);
}

class $$ConceptsTableTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          $ConceptsTable,
          ConceptRow,
          $$ConceptsTableFilterComposer,
          $$ConceptsTableOrderingComposer,
          $$ConceptsTableAnnotationComposer,
          $$ConceptsTableCreateCompanionBuilder,
          $$ConceptsTableUpdateCompanionBuilder,
          (
            ConceptRow,
            BaseReferences<_$ContentDatabase, $ConceptsTable, ConceptRow>,
          ),
          ConceptRow,
          PrefetchHooks Function()
        > {
  $$ConceptsTableTableManager(_$ContentDatabase db, $ConceptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConceptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConceptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConceptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<String> constellation = const Value.absent(),
                Value<String> pos = const Value.absent(),
                Value<int?> freqRank = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConceptsCompanion(
                id: id,
                tier: tier,
                constellation: constellation,
                pos: pos,
                freqRank: freqRank,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tier,
                required String constellation,
                required String pos,
                Value<int?> freqRank = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConceptsCompanion.insert(
                id: id,
                tier: tier,
                constellation: constellation,
                pos: pos,
                freqRank: freqRank,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ConceptsTable, ConceptRow>(table),
                  BaseReferences<_$ContentDatabase, $ConceptsTable, ConceptRow>(
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

typedef $$ConceptsTableProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      $ConceptsTable,
      ConceptRow,
      $$ConceptsTableFilterComposer,
      $$ConceptsTableOrderingComposer,
      $$ConceptsTableAnnotationComposer,
      $$ConceptsTableCreateCompanionBuilder,
      $$ConceptsTableUpdateCompanionBuilder,
      (
        ConceptRow,
        BaseReferences<_$ContentDatabase, $ConceptsTable, ConceptRow>,
      ),
      ConceptRow,
      PrefetchHooks Function()
    >;
typedef $$LexemesTableCreateCompanionBuilder = LexemesCompanion Function({
  required String conceptId,
  required String lang,
  required String form,
  Value<String?> article,
  Value<String?> gender,
  Value<String?> plural,
  Value<String?> note,
  Value<int> rowid,
});
typedef $$LexemesTableUpdateCompanionBuilder = LexemesCompanion Function({
  Value<String> conceptId,
  Value<String> lang,
  Value<String> form,
  Value<String?> article,
  Value<String?> gender,
  Value<String?> plural,
  Value<String?> note,
  Value<int> rowid,
});

class $$LexemesTableFilterComposer
    extends Composer<_$ContentDatabase, $LexemesTable> {
  $$LexemesTableFilterComposer({
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

  ColumnFilters<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get form => $composableBuilder(
    column: $table.form,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get article => $composableBuilder(
    column: $table.article,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plural => $composableBuilder(
    column: $table.plural,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LexemesTableOrderingComposer
    extends Composer<_$ContentDatabase, $LexemesTable> {
  $$LexemesTableOrderingComposer({
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

  ColumnOrderings<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get form => $composableBuilder(
    column: $table.form,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get article => $composableBuilder(
    column: $table.article,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plural => $composableBuilder(
    column: $table.plural,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LexemesTableAnnotationComposer
    extends Composer<_$ContentDatabase, $LexemesTable> {
  $$LexemesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get conceptId =>
      $composableBuilder(column: $table.conceptId, builder: (column) => column);

  GeneratedColumn<String> get lang =>
      $composableBuilder(column: $table.lang, builder: (column) => column);

  GeneratedColumn<String> get form =>
      $composableBuilder(column: $table.form, builder: (column) => column);

  GeneratedColumn<String> get article =>
      $composableBuilder(column: $table.article, builder: (column) => column);

  GeneratedColumn<String> get gender =>
      $composableBuilder(column: $table.gender, builder: (column) => column);

  GeneratedColumn<String> get plural =>
      $composableBuilder(column: $table.plural, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$LexemesTableTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          $LexemesTable,
          LexemeRow,
          $$LexemesTableFilterComposer,
          $$LexemesTableOrderingComposer,
          $$LexemesTableAnnotationComposer,
          $$LexemesTableCreateCompanionBuilder,
          $$LexemesTableUpdateCompanionBuilder,
          (
            LexemeRow,
            BaseReferences<_$ContentDatabase, $LexemesTable, LexemeRow>,
          ),
          LexemeRow,
          PrefetchHooks Function()
        > {
  $$LexemesTableTableManager(_$ContentDatabase db, $LexemesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LexemesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LexemesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LexemesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> conceptId = const Value.absent(),
                Value<String> lang = const Value.absent(),
                Value<String> form = const Value.absent(),
                Value<String?> article = const Value.absent(),
                Value<String?> gender = const Value.absent(),
                Value<String?> plural = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LexemesCompanion(
                conceptId: conceptId,
                lang: lang,
                form: form,
                article: article,
                gender: gender,
                plural: plural,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String conceptId,
                required String lang,
                required String form,
                Value<String?> article = const Value.absent(),
                Value<String?> gender = const Value.absent(),
                Value<String?> plural = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LexemesCompanion.insert(
                conceptId: conceptId,
                lang: lang,
                form: form,
                article: article,
                gender: gender,
                plural: plural,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LexemesTable, LexemeRow>(table),
                  BaseReferences<_$ContentDatabase, $LexemesTable, LexemeRow>(
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

typedef $$LexemesTableProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      $LexemesTable,
      LexemeRow,
      $$LexemesTableFilterComposer,
      $$LexemesTableOrderingComposer,
      $$LexemesTableAnnotationComposer,
      $$LexemesTableCreateCompanionBuilder,
      $$LexemesTableUpdateCompanionBuilder,
      (LexemeRow, BaseReferences<_$ContentDatabase, $LexemesTable, LexemeRow>),
      LexemeRow,
      PrefetchHooks Function()
    >;
typedef $$PhrasesTableCreateCompanionBuilder = PhrasesCompanion Function({
  required String id,
  required String lang,
  required String tier,
  required String constellation,
  required String template,
  required String answer,
  Value<String?> register,
  Value<int> rowid,
});
typedef $$PhrasesTableUpdateCompanionBuilder = PhrasesCompanion Function({
  Value<String> id,
  Value<String> lang,
  Value<String> tier,
  Value<String> constellation,
  Value<String> template,
  Value<String> answer,
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

  ColumnFilters<String> get template => $composableBuilder(
    column: $table.template,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answer => $composableBuilder(
    column: $table.answer,
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

  ColumnOrderings<String> get template => $composableBuilder(
    column: $table.template,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answer => $composableBuilder(
    column: $table.answer,
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

  GeneratedColumn<String> get template =>
      $composableBuilder(column: $table.template, builder: (column) => column);

  GeneratedColumn<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => column);

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
                Value<String> template = const Value.absent(),
                Value<String> answer = const Value.absent(),
                Value<String?> register = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhrasesCompanion(
                id: id,
                lang: lang,
                tier: tier,
                constellation: constellation,
                template: template,
                answer: answer,
                register: register,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String lang,
                required String tier,
                required String constellation,
                required String template,
                required String answer,
                Value<String?> register = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhrasesCompanion.insert(
                id: id,
                lang: lang,
                tier: tier,
                constellation: constellation,
                template: template,
                answer: answer,
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
typedef $$PhraseConceptsTableCreateCompanionBuilder =
    PhraseConceptsCompanion Function({
      required String phraseId,
      required String conceptId,
      Value<int> rowid,
    });
typedef $$PhraseConceptsTableUpdateCompanionBuilder =
    PhraseConceptsCompanion Function({
      Value<String> phraseId,
      Value<String> conceptId,
      Value<int> rowid,
    });

class $$PhraseConceptsTableFilterComposer
    extends Composer<_$ContentDatabase, $PhraseConceptsTable> {
  $$PhraseConceptsTableFilterComposer({
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

  ColumnFilters<String> get conceptId => $composableBuilder(
    column: $table.conceptId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PhraseConceptsTableOrderingComposer
    extends Composer<_$ContentDatabase, $PhraseConceptsTable> {
  $$PhraseConceptsTableOrderingComposer({
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

  ColumnOrderings<String> get conceptId => $composableBuilder(
    column: $table.conceptId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhraseConceptsTableAnnotationComposer
    extends Composer<_$ContentDatabase, $PhraseConceptsTable> {
  $$PhraseConceptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get phraseId =>
      $composableBuilder(column: $table.phraseId, builder: (column) => column);

  GeneratedColumn<String> get conceptId =>
      $composableBuilder(column: $table.conceptId, builder: (column) => column);
}

class $$PhraseConceptsTableTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          $PhraseConceptsTable,
          PhraseConceptRow,
          $$PhraseConceptsTableFilterComposer,
          $$PhraseConceptsTableOrderingComposer,
          $$PhraseConceptsTableAnnotationComposer,
          $$PhraseConceptsTableCreateCompanionBuilder,
          $$PhraseConceptsTableUpdateCompanionBuilder,
          (
            PhraseConceptRow,
            BaseReferences<
              _$ContentDatabase,
              $PhraseConceptsTable,
              PhraseConceptRow
            >,
          ),
          PhraseConceptRow,
          PrefetchHooks Function()
        > {
  $$PhraseConceptsTableTableManager(
    _$ContentDatabase db,
    $PhraseConceptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhraseConceptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhraseConceptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhraseConceptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> phraseId = const Value.absent(),
                Value<String> conceptId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhraseConceptsCompanion(
                phraseId: phraseId,
                conceptId: conceptId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String phraseId,
                required String conceptId,
                Value<int> rowid = const Value.absent(),
              }) => PhraseConceptsCompanion.insert(
                phraseId: phraseId,
                conceptId: conceptId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PhraseConceptsTable, PhraseConceptRow>(table),
                  BaseReferences<
                    _$ContentDatabase,
                    $PhraseConceptsTable,
                    PhraseConceptRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PhraseConceptsTableProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      $PhraseConceptsTable,
      PhraseConceptRow,
      $$PhraseConceptsTableFilterComposer,
      $$PhraseConceptsTableOrderingComposer,
      $$PhraseConceptsTableAnnotationComposer,
      $$PhraseConceptsTableCreateCompanionBuilder,
      $$PhraseConceptsTableUpdateCompanionBuilder,
      (
        PhraseConceptRow,
        BaseReferences<
          _$ContentDatabase,
          $PhraseConceptsTable,
          PhraseConceptRow
        >,
      ),
      PhraseConceptRow,
      PrefetchHooks Function()
    >;
typedef $$DistractorsTableCreateCompanionBuilder =
    DistractorsCompanion Function({
      required String conceptId,
      required String lang,
      required String kind,
      required String form,
      Value<int> rowid,
    });
typedef $$DistractorsTableUpdateCompanionBuilder =
    DistractorsCompanion Function({
      Value<String> conceptId,
      Value<String> lang,
      Value<String> kind,
      Value<String> form,
      Value<int> rowid,
    });

class $$DistractorsTableFilterComposer
    extends Composer<_$ContentDatabase, $DistractorsTable> {
  $$DistractorsTableFilterComposer({
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

  ColumnFilters<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get form => $composableBuilder(
    column: $table.form,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DistractorsTableOrderingComposer
    extends Composer<_$ContentDatabase, $DistractorsTable> {
  $$DistractorsTableOrderingComposer({
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

  ColumnOrderings<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get form => $composableBuilder(
    column: $table.form,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DistractorsTableAnnotationComposer
    extends Composer<_$ContentDatabase, $DistractorsTable> {
  $$DistractorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get conceptId =>
      $composableBuilder(column: $table.conceptId, builder: (column) => column);

  GeneratedColumn<String> get lang =>
      $composableBuilder(column: $table.lang, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get form =>
      $composableBuilder(column: $table.form, builder: (column) => column);
}

class $$DistractorsTableTableManager
    extends
        RootTableManager<
          _$ContentDatabase,
          $DistractorsTable,
          DistractorRow,
          $$DistractorsTableFilterComposer,
          $$DistractorsTableOrderingComposer,
          $$DistractorsTableAnnotationComposer,
          $$DistractorsTableCreateCompanionBuilder,
          $$DistractorsTableUpdateCompanionBuilder,
          (
            DistractorRow,
            BaseReferences<_$ContentDatabase, $DistractorsTable, DistractorRow>,
          ),
          DistractorRow,
          PrefetchHooks Function()
        > {
  $$DistractorsTableTableManager(_$ContentDatabase db, $DistractorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DistractorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DistractorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DistractorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> conceptId = const Value.absent(),
                Value<String> lang = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> form = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DistractorsCompanion(
                conceptId: conceptId,
                lang: lang,
                kind: kind,
                form: form,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String conceptId,
                required String lang,
                required String kind,
                required String form,
                Value<int> rowid = const Value.absent(),
              }) => DistractorsCompanion.insert(
                conceptId: conceptId,
                lang: lang,
                kind: kind,
                form: form,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DistractorsTable, DistractorRow>(table),
                  BaseReferences<
                    _$ContentDatabase,
                    $DistractorsTable,
                    DistractorRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DistractorsTableProcessedTableManager =
    ProcessedTableManager<
      _$ContentDatabase,
      $DistractorsTable,
      DistractorRow,
      $$DistractorsTableFilterComposer,
      $$DistractorsTableOrderingComposer,
      $$DistractorsTableAnnotationComposer,
      $$DistractorsTableCreateCompanionBuilder,
      $$DistractorsTableUpdateCompanionBuilder,
      (
        DistractorRow,
        BaseReferences<_$ContentDatabase, $DistractorsTable, DistractorRow>,
      ),
      DistractorRow,
      PrefetchHooks Function()
    >;
typedef $$CalibrationItemsTableCreateCompanionBuilder =
    CalibrationItemsCompanion Function({
      required String id,
      required String tier,
      Value<String?> conceptId,
      Value<String?> phraseId,
      required String kind,
      Value<int> rowid,
    });
typedef $$CalibrationItemsTableUpdateCompanionBuilder =
    CalibrationItemsCompanion Function({
      Value<String> id,
      Value<String> tier,
      Value<String?> conceptId,
      Value<String?> phraseId,
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

  ColumnFilters<String> get conceptId => $composableBuilder(
    column: $table.conceptId,
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

  ColumnOrderings<String> get conceptId => $composableBuilder(
    column: $table.conceptId,
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

  GeneratedColumn<String> get conceptId =>
      $composableBuilder(column: $table.conceptId, builder: (column) => column);

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
                Value<String?> conceptId = const Value.absent(),
                Value<String?> phraseId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalibrationItemsCompanion(
                id: id,
                tier: tier,
                conceptId: conceptId,
                phraseId: phraseId,
                kind: kind,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tier,
                Value<String?> conceptId = const Value.absent(),
                Value<String?> phraseId = const Value.absent(),
                required String kind,
                Value<int> rowid = const Value.absent(),
              }) => CalibrationItemsCompanion.insert(
                id: id,
                tier: tier,
                conceptId: conceptId,
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
  $$ConceptsTableTableManager get concepts =>
      $$ConceptsTableTableManager(_db, _db.concepts);
  $$LexemesTableTableManager get lexemes =>
      $$LexemesTableTableManager(_db, _db.lexemes);
  $$PhrasesTableTableManager get phrases =>
      $$PhrasesTableTableManager(_db, _db.phrases);
  $$PhraseConceptsTableTableManager get phraseConcepts =>
      $$PhraseConceptsTableTableManager(_db, _db.phraseConcepts);
  $$DistractorsTableTableManager get distractors =>
      $$DistractorsTableTableManager(_db, _db.distractors);
  $$CalibrationItemsTableTableManager get calibrationItems =>
      $$CalibrationItemsTableTableManager(_db, _db.calibrationItems);
  $$ContentMetaTableTableManager get contentMeta =>
      $$ContentMetaTableTableManager(_db, _db.contentMeta);
}
