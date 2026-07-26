// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $LedgersTable extends Ledgers with TableInfo<$LedgersTable, Ledger> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('CNY'));
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('personal'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
      'sync_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, currency, type, createdAt, syncId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledgers';
  @override
  VerificationContext validateIntegrity(Insertable<Ledger> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('sync_id')) {
      context.handle(_syncIdMeta,
          syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Ledger map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Ledger(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      syncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_id']),
    );
  }

  @override
  $LedgersTable createAlias(String alias) {
    return $LedgersTable(attachedDatabase, alias);
  }
}

class Ledger extends DataClass implements Insertable<Ledger> {
  final int id;
  final String name;
  final String currency;
  final String type;
  final DateTime createdAt;
  final String? syncId;
  const Ledger(
      {required this.id,
      required this.name,
      required this.currency,
      required this.type,
      required this.createdAt,
      this.syncId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['currency'] = Variable<String>(currency);
    map['type'] = Variable<String>(type);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    return map;
  }

  LedgersCompanion toCompanion(bool nullToAbsent) {
    return LedgersCompanion(
      id: Value(id),
      name: Value(name),
      currency: Value(currency),
      type: Value(type),
      createdAt: Value(createdAt),
      syncId:
          syncId == null && nullToAbsent ? const Value.absent() : Value(syncId),
    );
  }

  factory Ledger.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Ledger(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      currency: serializer.fromJson<String>(json['currency']),
      type: serializer.fromJson<String>(json['type']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncId: serializer.fromJson<String?>(json['syncId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'currency': serializer.toJson<String>(currency),
      'type': serializer.toJson<String>(type),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncId': serializer.toJson<String?>(syncId),
    };
  }

  Ledger copyWith(
          {int? id,
          String? name,
          String? currency,
          String? type,
          DateTime? createdAt,
          Value<String?> syncId = const Value.absent()}) =>
      Ledger(
        id: id ?? this.id,
        name: name ?? this.name,
        currency: currency ?? this.currency,
        type: type ?? this.type,
        createdAt: createdAt ?? this.createdAt,
        syncId: syncId.present ? syncId.value : this.syncId,
      );
  Ledger copyWithCompanion(LedgersCompanion data) {
    return Ledger(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      currency: data.currency.present ? data.currency.value : this.currency,
      type: data.type.present ? data.type.value : this.type,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Ledger(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('currency: $currency, ')
          ..write('type: $type, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncId: $syncId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, currency, type, createdAt, syncId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Ledger &&
          other.id == this.id &&
          other.name == this.name &&
          other.currency == this.currency &&
          other.type == this.type &&
          other.createdAt == this.createdAt &&
          other.syncId == this.syncId);
}

class LedgersCompanion extends UpdateCompanion<Ledger> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> currency;
  final Value<String> type;
  final Value<DateTime> createdAt;
  final Value<String?> syncId;
  const LedgersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.currency = const Value.absent(),
    this.type = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncId = const Value.absent(),
  });
  LedgersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.currency = const Value.absent(),
    this.type = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncId = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Ledger> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? currency,
    Expression<String>? type,
    Expression<DateTime>? createdAt,
    Expression<String>? syncId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (currency != null) 'currency': currency,
      if (type != null) 'type': type,
      if (createdAt != null) 'created_at': createdAt,
      if (syncId != null) 'sync_id': syncId,
    });
  }

  LedgersCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String>? currency,
      Value<String>? type,
      Value<DateTime>? createdAt,
      Value<String?>? syncId}) {
    return LedgersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      syncId: syncId ?? this.syncId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('currency: $currency, ')
          ..write('type: $type, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncId: $syncId')
          ..write(')'))
        .toString();
  }
}

class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _ledgerIdMeta =
      const VerificationMeta('ledgerId');
  @override
  late final GeneratedColumn<int> ledgerId = GeneratedColumn<int>(
      'ledger_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('cash'));
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('CNY'));
  static const VerificationMeta _initialBalanceMeta =
      const VerificationMeta('initialBalance');
  @override
  late final GeneratedColumn<double> initialBalance = GeneratedColumn<double>(
      'initial_balance', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _creditLimitMeta =
      const VerificationMeta('creditLimit');
  @override
  late final GeneratedColumn<double> creditLimit = GeneratedColumn<double>(
      'credit_limit', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _billingDayMeta =
      const VerificationMeta('billingDay');
  @override
  late final GeneratedColumn<int> billingDay = GeneratedColumn<int>(
      'billing_day', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _paymentDueDayMeta =
      const VerificationMeta('paymentDueDay');
  @override
  late final GeneratedColumn<int> paymentDueDay = GeneratedColumn<int>(
      'payment_due_day', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _bankNameMeta =
      const VerificationMeta('bankName');
  @override
  late final GeneratedColumn<String> bankName = GeneratedColumn<String>(
      'bank_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cardLastFourMeta =
      const VerificationMeta('cardLastFour');
  @override
  late final GeneratedColumn<String> cardLastFour = GeneratedColumn<String>(
      'card_last_four', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
      'sync_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        ledgerId,
        name,
        type,
        currency,
        initialBalance,
        createdAt,
        updatedAt,
        sortOrder,
        creditLimit,
        billingDay,
        paymentDueDay,
        bankName,
        cardLastFour,
        note,
        syncId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(Insertable<Account> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ledger_id')) {
      context.handle(_ledgerIdMeta,
          ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta));
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('initial_balance')) {
      context.handle(
          _initialBalanceMeta,
          initialBalance.isAcceptableOrUnknown(
              data['initial_balance']!, _initialBalanceMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('credit_limit')) {
      context.handle(
          _creditLimitMeta,
          creditLimit.isAcceptableOrUnknown(
              data['credit_limit']!, _creditLimitMeta));
    }
    if (data.containsKey('billing_day')) {
      context.handle(
          _billingDayMeta,
          billingDay.isAcceptableOrUnknown(
              data['billing_day']!, _billingDayMeta));
    }
    if (data.containsKey('payment_due_day')) {
      context.handle(
          _paymentDueDayMeta,
          paymentDueDay.isAcceptableOrUnknown(
              data['payment_due_day']!, _paymentDueDayMeta));
    }
    if (data.containsKey('bank_name')) {
      context.handle(_bankNameMeta,
          bankName.isAcceptableOrUnknown(data['bank_name']!, _bankNameMeta));
    }
    if (data.containsKey('card_last_four')) {
      context.handle(
          _cardLastFourMeta,
          cardLastFour.isAcceptableOrUnknown(
              data['card_last_four']!, _cardLastFourMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('sync_id')) {
      context.handle(_syncIdMeta,
          syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      ledgerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ledger_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      initialBalance: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}initial_balance'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      creditLimit: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}credit_limit']),
      billingDay: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}billing_day']),
      paymentDueDay: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}payment_due_day']),
      bankName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bank_name']),
      cardLastFour: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}card_last_four']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      syncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_id']),
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class Account extends DataClass implements Insertable<Account> {
  final int id;
  final int ledgerId;
  final String name;
  final String type;
  final String currency;
  final double initialBalance;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int sortOrder;
  final double? creditLimit;
  final int? billingDay;
  final int? paymentDueDay;
  final String? bankName;
  final String? cardLastFour;
  final String? note;
  final String? syncId;
  const Account(
      {required this.id,
      required this.ledgerId,
      required this.name,
      required this.type,
      required this.currency,
      required this.initialBalance,
      this.createdAt,
      this.updatedAt,
      required this.sortOrder,
      this.creditLimit,
      this.billingDay,
      this.paymentDueDay,
      this.bankName,
      this.cardLastFour,
      this.note,
      this.syncId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ledger_id'] = Variable<int>(ledgerId);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['currency'] = Variable<String>(currency);
    map['initial_balance'] = Variable<double>(initialBalance);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || creditLimit != null) {
      map['credit_limit'] = Variable<double>(creditLimit);
    }
    if (!nullToAbsent || billingDay != null) {
      map['billing_day'] = Variable<int>(billingDay);
    }
    if (!nullToAbsent || paymentDueDay != null) {
      map['payment_due_day'] = Variable<int>(paymentDueDay);
    }
    if (!nullToAbsent || bankName != null) {
      map['bank_name'] = Variable<String>(bankName);
    }
    if (!nullToAbsent || cardLastFour != null) {
      map['card_last_four'] = Variable<String>(cardLastFour);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      ledgerId: Value(ledgerId),
      name: Value(name),
      type: Value(type),
      currency: Value(currency),
      initialBalance: Value(initialBalance),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      sortOrder: Value(sortOrder),
      creditLimit: creditLimit == null && nullToAbsent
          ? const Value.absent()
          : Value(creditLimit),
      billingDay: billingDay == null && nullToAbsent
          ? const Value.absent()
          : Value(billingDay),
      paymentDueDay: paymentDueDay == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentDueDay),
      bankName: bankName == null && nullToAbsent
          ? const Value.absent()
          : Value(bankName),
      cardLastFour: cardLastFour == null && nullToAbsent
          ? const Value.absent()
          : Value(cardLastFour),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      syncId:
          syncId == null && nullToAbsent ? const Value.absent() : Value(syncId),
    );
  }

  factory Account.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<int>(json['id']),
      ledgerId: serializer.fromJson<int>(json['ledgerId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      currency: serializer.fromJson<String>(json['currency']),
      initialBalance: serializer.fromJson<double>(json['initialBalance']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      creditLimit: serializer.fromJson<double?>(json['creditLimit']),
      billingDay: serializer.fromJson<int?>(json['billingDay']),
      paymentDueDay: serializer.fromJson<int?>(json['paymentDueDay']),
      bankName: serializer.fromJson<String?>(json['bankName']),
      cardLastFour: serializer.fromJson<String?>(json['cardLastFour']),
      note: serializer.fromJson<String?>(json['note']),
      syncId: serializer.fromJson<String?>(json['syncId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ledgerId': serializer.toJson<int>(ledgerId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'currency': serializer.toJson<String>(currency),
      'initialBalance': serializer.toJson<double>(initialBalance),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'creditLimit': serializer.toJson<double?>(creditLimit),
      'billingDay': serializer.toJson<int?>(billingDay),
      'paymentDueDay': serializer.toJson<int?>(paymentDueDay),
      'bankName': serializer.toJson<String?>(bankName),
      'cardLastFour': serializer.toJson<String?>(cardLastFour),
      'note': serializer.toJson<String?>(note),
      'syncId': serializer.toJson<String?>(syncId),
    };
  }

  Account copyWith(
          {int? id,
          int? ledgerId,
          String? name,
          String? type,
          String? currency,
          double? initialBalance,
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent(),
          int? sortOrder,
          Value<double?> creditLimit = const Value.absent(),
          Value<int?> billingDay = const Value.absent(),
          Value<int?> paymentDueDay = const Value.absent(),
          Value<String?> bankName = const Value.absent(),
          Value<String?> cardLastFour = const Value.absent(),
          Value<String?> note = const Value.absent(),
          Value<String?> syncId = const Value.absent()}) =>
      Account(
        id: id ?? this.id,
        ledgerId: ledgerId ?? this.ledgerId,
        name: name ?? this.name,
        type: type ?? this.type,
        currency: currency ?? this.currency,
        initialBalance: initialBalance ?? this.initialBalance,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
        sortOrder: sortOrder ?? this.sortOrder,
        creditLimit: creditLimit.present ? creditLimit.value : this.creditLimit,
        billingDay: billingDay.present ? billingDay.value : this.billingDay,
        paymentDueDay:
            paymentDueDay.present ? paymentDueDay.value : this.paymentDueDay,
        bankName: bankName.present ? bankName.value : this.bankName,
        cardLastFour:
            cardLastFour.present ? cardLastFour.value : this.cardLastFour,
        note: note.present ? note.value : this.note,
        syncId: syncId.present ? syncId.value : this.syncId,
      );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      currency: data.currency.present ? data.currency.value : this.currency,
      initialBalance: data.initialBalance.present
          ? data.initialBalance.value
          : this.initialBalance,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      creditLimit:
          data.creditLimit.present ? data.creditLimit.value : this.creditLimit,
      billingDay:
          data.billingDay.present ? data.billingDay.value : this.billingDay,
      paymentDueDay: data.paymentDueDay.present
          ? data.paymentDueDay.value
          : this.paymentDueDay,
      bankName: data.bankName.present ? data.bankName.value : this.bankName,
      cardLastFour: data.cardLastFour.present
          ? data.cardLastFour.value
          : this.cardLastFour,
      note: data.note.present ? data.note.value : this.note,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('currency: $currency, ')
          ..write('initialBalance: $initialBalance, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('creditLimit: $creditLimit, ')
          ..write('billingDay: $billingDay, ')
          ..write('paymentDueDay: $paymentDueDay, ')
          ..write('bankName: $bankName, ')
          ..write('cardLastFour: $cardLastFour, ')
          ..write('note: $note, ')
          ..write('syncId: $syncId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      ledgerId,
      name,
      type,
      currency,
      initialBalance,
      createdAt,
      updatedAt,
      sortOrder,
      creditLimit,
      billingDay,
      paymentDueDay,
      bankName,
      cardLastFour,
      note,
      syncId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.ledgerId == this.ledgerId &&
          other.name == this.name &&
          other.type == this.type &&
          other.currency == this.currency &&
          other.initialBalance == this.initialBalance &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.sortOrder == this.sortOrder &&
          other.creditLimit == this.creditLimit &&
          other.billingDay == this.billingDay &&
          other.paymentDueDay == this.paymentDueDay &&
          other.bankName == this.bankName &&
          other.cardLastFour == this.cardLastFour &&
          other.note == this.note &&
          other.syncId == this.syncId);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<int> id;
  final Value<int> ledgerId;
  final Value<String> name;
  final Value<String> type;
  final Value<String> currency;
  final Value<double> initialBalance;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> sortOrder;
  final Value<double?> creditLimit;
  final Value<int?> billingDay;
  final Value<int?> paymentDueDay;
  final Value<String?> bankName;
  final Value<String?> cardLastFour;
  final Value<String?> note;
  final Value<String?> syncId;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.currency = const Value.absent(),
    this.initialBalance = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.creditLimit = const Value.absent(),
    this.billingDay = const Value.absent(),
    this.paymentDueDay = const Value.absent(),
    this.bankName = const Value.absent(),
    this.cardLastFour = const Value.absent(),
    this.note = const Value.absent(),
    this.syncId = const Value.absent(),
  });
  AccountsCompanion.insert({
    this.id = const Value.absent(),
    required int ledgerId,
    required String name,
    this.type = const Value.absent(),
    this.currency = const Value.absent(),
    this.initialBalance = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.creditLimit = const Value.absent(),
    this.billingDay = const Value.absent(),
    this.paymentDueDay = const Value.absent(),
    this.bankName = const Value.absent(),
    this.cardLastFour = const Value.absent(),
    this.note = const Value.absent(),
    this.syncId = const Value.absent(),
  })  : ledgerId = Value(ledgerId),
        name = Value(name);
  static Insertable<Account> custom({
    Expression<int>? id,
    Expression<int>? ledgerId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? currency,
    Expression<double>? initialBalance,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? sortOrder,
    Expression<double>? creditLimit,
    Expression<int>? billingDay,
    Expression<int>? paymentDueDay,
    Expression<String>? bankName,
    Expression<String>? cardLastFour,
    Expression<String>? note,
    Expression<String>? syncId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (currency != null) 'currency': currency,
      if (initialBalance != null) 'initial_balance': initialBalance,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (creditLimit != null) 'credit_limit': creditLimit,
      if (billingDay != null) 'billing_day': billingDay,
      if (paymentDueDay != null) 'payment_due_day': paymentDueDay,
      if (bankName != null) 'bank_name': bankName,
      if (cardLastFour != null) 'card_last_four': cardLastFour,
      if (note != null) 'note': note,
      if (syncId != null) 'sync_id': syncId,
    });
  }

  AccountsCompanion copyWith(
      {Value<int>? id,
      Value<int>? ledgerId,
      Value<String>? name,
      Value<String>? type,
      Value<String>? currency,
      Value<double>? initialBalance,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt,
      Value<int>? sortOrder,
      Value<double?>? creditLimit,
      Value<int?>? billingDay,
      Value<int?>? paymentDueDay,
      Value<String?>? bankName,
      Value<String?>? cardLastFour,
      Value<String?>? note,
      Value<String?>? syncId}) {
    return AccountsCompanion(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      name: name ?? this.name,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      initialBalance: initialBalance ?? this.initialBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      creditLimit: creditLimit ?? this.creditLimit,
      billingDay: billingDay ?? this.billingDay,
      paymentDueDay: paymentDueDay ?? this.paymentDueDay,
      bankName: bankName ?? this.bankName,
      cardLastFour: cardLastFour ?? this.cardLastFour,
      note: note ?? this.note,
      syncId: syncId ?? this.syncId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<int>(ledgerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (initialBalance.present) {
      map['initial_balance'] = Variable<double>(initialBalance.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (creditLimit.present) {
      map['credit_limit'] = Variable<double>(creditLimit.value);
    }
    if (billingDay.present) {
      map['billing_day'] = Variable<int>(billingDay.value);
    }
    if (paymentDueDay.present) {
      map['payment_due_day'] = Variable<int>(paymentDueDay.value);
    }
    if (bankName.present) {
      map['bank_name'] = Variable<String>(bankName.value);
    }
    if (cardLastFour.present) {
      map['card_last_four'] = Variable<String>(cardLastFour.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('currency: $currency, ')
          ..write('initialBalance: $initialBalance, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('creditLimit: $creditLimit, ')
          ..write('billingDay: $billingDay, ')
          ..write('paymentDueDay: $paymentDueDay, ')
          ..write('bankName: $bankName, ')
          ..write('cardLastFour: $cardLastFour, ')
          ..write('note: $note, ')
          ..write('syncId: $syncId')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
      'icon', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<int> parentId = GeneratedColumn<int>(
      'parent_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
      'level', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _iconTypeMeta =
      const VerificationMeta('iconType');
  @override
  late final GeneratedColumn<String> iconType = GeneratedColumn<String>(
      'icon_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('material'));
  static const VerificationMeta _customIconPathMeta =
      const VerificationMeta('customIconPath');
  @override
  late final GeneratedColumn<String> customIconPath = GeneratedColumn<String>(
      'custom_icon_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _communityIconIdMeta =
      const VerificationMeta('communityIconId');
  @override
  late final GeneratedColumn<String> communityIconId = GeneratedColumn<String>(
      'community_icon_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
      'sync_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        kind,
        icon,
        sortOrder,
        parentId,
        level,
        iconType,
        customIconPath,
        communityIconId,
        syncId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(Insertable<Category> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
          _iconMeta, icon.isAcceptableOrUnknown(data['icon']!, _iconMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    }
    if (data.containsKey('level')) {
      context.handle(
          _levelMeta, level.isAcceptableOrUnknown(data['level']!, _levelMeta));
    }
    if (data.containsKey('icon_type')) {
      context.handle(_iconTypeMeta,
          iconType.isAcceptableOrUnknown(data['icon_type']!, _iconTypeMeta));
    }
    if (data.containsKey('custom_icon_path')) {
      context.handle(
          _customIconPathMeta,
          customIconPath.isAcceptableOrUnknown(
              data['custom_icon_path']!, _customIconPathMeta));
    }
    if (data.containsKey('community_icon_id')) {
      context.handle(
          _communityIconIdMeta,
          communityIconId.isAcceptableOrUnknown(
              data['community_icon_id']!, _communityIconIdMeta));
    }
    if (data.containsKey('sync_id')) {
      context.handle(_syncIdMeta,
          syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      icon: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}parent_id']),
      level: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}level'])!,
      iconType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_type'])!,
      customIconPath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}custom_icon_path']),
      communityIconId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}community_icon_id']),
      syncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_id']),
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final int id;
  final String name;
  final String kind;
  final String? icon;
  final int sortOrder;
  final int? parentId;
  final int level;
  final String iconType;
  final String? customIconPath;
  final String? communityIconId;
  final String? syncId;
  const Category(
      {required this.id,
      required this.name,
      required this.kind,
      this.icon,
      required this.sortOrder,
      this.parentId,
      required this.level,
      required this.iconType,
      this.customIconPath,
      this.communityIconId,
      this.syncId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<int>(parentId);
    }
    map['level'] = Variable<int>(level);
    map['icon_type'] = Variable<String>(iconType);
    if (!nullToAbsent || customIconPath != null) {
      map['custom_icon_path'] = Variable<String>(customIconPath);
    }
    if (!nullToAbsent || communityIconId != null) {
      map['community_icon_id'] = Variable<String>(communityIconId);
    }
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      sortOrder: Value(sortOrder),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      level: Value(level),
      iconType: Value(iconType),
      customIconPath: customIconPath == null && nullToAbsent
          ? const Value.absent()
          : Value(customIconPath),
      communityIconId: communityIconId == null && nullToAbsent
          ? const Value.absent()
          : Value(communityIconId),
      syncId:
          syncId == null && nullToAbsent ? const Value.absent() : Value(syncId),
    );
  }

  factory Category.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      icon: serializer.fromJson<String?>(json['icon']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      parentId: serializer.fromJson<int?>(json['parentId']),
      level: serializer.fromJson<int>(json['level']),
      iconType: serializer.fromJson<String>(json['iconType']),
      customIconPath: serializer.fromJson<String?>(json['customIconPath']),
      communityIconId: serializer.fromJson<String?>(json['communityIconId']),
      syncId: serializer.fromJson<String?>(json['syncId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'icon': serializer.toJson<String?>(icon),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'parentId': serializer.toJson<int?>(parentId),
      'level': serializer.toJson<int>(level),
      'iconType': serializer.toJson<String>(iconType),
      'customIconPath': serializer.toJson<String?>(customIconPath),
      'communityIconId': serializer.toJson<String?>(communityIconId),
      'syncId': serializer.toJson<String?>(syncId),
    };
  }

  Category copyWith(
          {int? id,
          String? name,
          String? kind,
          Value<String?> icon = const Value.absent(),
          int? sortOrder,
          Value<int?> parentId = const Value.absent(),
          int? level,
          String? iconType,
          Value<String?> customIconPath = const Value.absent(),
          Value<String?> communityIconId = const Value.absent(),
          Value<String?> syncId = const Value.absent()}) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        icon: icon.present ? icon.value : this.icon,
        sortOrder: sortOrder ?? this.sortOrder,
        parentId: parentId.present ? parentId.value : this.parentId,
        level: level ?? this.level,
        iconType: iconType ?? this.iconType,
        customIconPath:
            customIconPath.present ? customIconPath.value : this.customIconPath,
        communityIconId: communityIconId.present
            ? communityIconId.value
            : this.communityIconId,
        syncId: syncId.present ? syncId.value : this.syncId,
      );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      icon: data.icon.present ? data.icon.value : this.icon,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      level: data.level.present ? data.level.value : this.level,
      iconType: data.iconType.present ? data.iconType.value : this.iconType,
      customIconPath: data.customIconPath.present
          ? data.customIconPath.value
          : this.customIconPath,
      communityIconId: data.communityIconId.present
          ? data.communityIconId.value
          : this.communityIconId,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('parentId: $parentId, ')
          ..write('level: $level, ')
          ..write('iconType: $iconType, ')
          ..write('customIconPath: $customIconPath, ')
          ..write('communityIconId: $communityIconId, ')
          ..write('syncId: $syncId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, kind, icon, sortOrder, parentId,
      level, iconType, customIconPath, communityIconId, syncId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.icon == this.icon &&
          other.sortOrder == this.sortOrder &&
          other.parentId == this.parentId &&
          other.level == this.level &&
          other.iconType == this.iconType &&
          other.customIconPath == this.customIconPath &&
          other.communityIconId == this.communityIconId &&
          other.syncId == this.syncId);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> kind;
  final Value<String?> icon;
  final Value<int> sortOrder;
  final Value<int?> parentId;
  final Value<int> level;
  final Value<String> iconType;
  final Value<String?> customIconPath;
  final Value<String?> communityIconId;
  final Value<String?> syncId;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.icon = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.parentId = const Value.absent(),
    this.level = const Value.absent(),
    this.iconType = const Value.absent(),
    this.customIconPath = const Value.absent(),
    this.communityIconId = const Value.absent(),
    this.syncId = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String kind,
    this.icon = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.parentId = const Value.absent(),
    this.level = const Value.absent(),
    this.iconType = const Value.absent(),
    this.customIconPath = const Value.absent(),
    this.communityIconId = const Value.absent(),
    this.syncId = const Value.absent(),
  })  : name = Value(name),
        kind = Value(kind);
  static Insertable<Category> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? icon,
    Expression<int>? sortOrder,
    Expression<int>? parentId,
    Expression<int>? level,
    Expression<String>? iconType,
    Expression<String>? customIconPath,
    Expression<String>? communityIconId,
    Expression<String>? syncId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (icon != null) 'icon': icon,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (parentId != null) 'parent_id': parentId,
      if (level != null) 'level': level,
      if (iconType != null) 'icon_type': iconType,
      if (customIconPath != null) 'custom_icon_path': customIconPath,
      if (communityIconId != null) 'community_icon_id': communityIconId,
      if (syncId != null) 'sync_id': syncId,
    });
  }

  CategoriesCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String>? kind,
      Value<String?>? icon,
      Value<int>? sortOrder,
      Value<int?>? parentId,
      Value<int>? level,
      Value<String>? iconType,
      Value<String?>? customIconPath,
      Value<String?>? communityIconId,
      Value<String?>? syncId}) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      parentId: parentId ?? this.parentId,
      level: level ?? this.level,
      iconType: iconType ?? this.iconType,
      customIconPath: customIconPath ?? this.customIconPath,
      communityIconId: communityIconId ?? this.communityIconId,
      syncId: syncId ?? this.syncId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<int>(parentId.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (iconType.present) {
      map['icon_type'] = Variable<String>(iconType.value);
    }
    if (customIconPath.present) {
      map['custom_icon_path'] = Variable<String>(customIconPath.value);
    }
    if (communityIconId.present) {
      map['community_icon_id'] = Variable<String>(communityIconId.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('parentId: $parentId, ')
          ..write('level: $level, ')
          ..write('iconType: $iconType, ')
          ..write('customIconPath: $customIconPath, ')
          ..write('communityIconId: $communityIconId, ')
          ..write('syncId: $syncId')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _ledgerIdMeta =
      const VerificationMeta('ledgerId');
  @override
  late final GeneratedColumn<int> ledgerId = GeneratedColumn<int>(
      'ledger_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
      'category_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
      'account_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _toAccountIdMeta =
      const VerificationMeta('toAccountId');
  @override
  late final GeneratedColumn<int> toAccountId = GeneratedColumn<int>(
      'to_account_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _happenedAtMeta =
      const VerificationMeta('happenedAt');
  @override
  late final GeneratedColumn<DateTime> happenedAt = GeneratedColumn<DateTime>(
      'happened_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _paymentMethodMeta =
      const VerificationMeta('paymentMethod');
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
      'payment_method', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _counterpartyMeta =
      const VerificationMeta('counterparty');
  @override
  late final GeneratedColumn<String> counterparty = GeneratedColumn<String>(
      'counterparty', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _paymentChannelMeta =
      const VerificationMeta('paymentChannel');
  @override
  late final GeneratedColumn<String> paymentChannel = GeneratedColumn<String>(
      'payment_channel', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _merchantFullNameMeta =
      const VerificationMeta('merchantFullName');
  @override
  late final GeneratedColumn<String> merchantFullName = GeneratedColumn<String>(
      'merchant_full_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _acquirerMeta =
      const VerificationMeta('acquirer');
  @override
  late final GeneratedColumn<String> acquirer = GeneratedColumn<String>(
      'acquirer', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _detailsTextMeta =
      const VerificationMeta('detailsText');
  @override
  late final GeneratedColumn<String> detailsText = GeneratedColumn<String>(
      'details_text', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _discountAmountMeta =
      const VerificationMeta('discountAmount');
  @override
  late final GeneratedColumn<double> discountAmount = GeneratedColumn<double>(
      'discount_amount', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _needsClassificationMeta =
      const VerificationMeta('needsClassification');
  @override
  late final GeneratedColumn<bool> needsClassification = GeneratedColumn<bool>(
      'needs_classification', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("needs_classification" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _recurringIdMeta =
      const VerificationMeta('recurringId');
  @override
  late final GeneratedColumn<int> recurringId = GeneratedColumn<int>(
      'recurring_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
      'sync_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        ledgerId,
        type,
        amount,
        categoryId,
        accountId,
        toAccountId,
        happenedAt,
        note,
        paymentMethod,
        counterparty,
        paymentChannel,
        merchantFullName,
        acquirer,
        detailsText,
        discountAmount,
        needsClassification,
        recurringId,
        syncId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(Insertable<Transaction> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ledger_id')) {
      context.handle(_ledgerIdMeta,
          ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta));
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    }
    if (data.containsKey('to_account_id')) {
      context.handle(
          _toAccountIdMeta,
          toAccountId.isAcceptableOrUnknown(
              data['to_account_id']!, _toAccountIdMeta));
    }
    if (data.containsKey('happened_at')) {
      context.handle(
          _happenedAtMeta,
          happenedAt.isAcceptableOrUnknown(
              data['happened_at']!, _happenedAtMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('payment_method')) {
      context.handle(
          _paymentMethodMeta,
          paymentMethod.isAcceptableOrUnknown(
              data['payment_method']!, _paymentMethodMeta));
    }
    if (data.containsKey('counterparty')) {
      context.handle(
          _counterpartyMeta,
          counterparty.isAcceptableOrUnknown(
              data['counterparty']!, _counterpartyMeta));
    }
    if (data.containsKey('payment_channel')) {
      context.handle(
          _paymentChannelMeta,
          paymentChannel.isAcceptableOrUnknown(
              data['payment_channel']!, _paymentChannelMeta));
    }
    if (data.containsKey('merchant_full_name')) {
      context.handle(
          _merchantFullNameMeta,
          merchantFullName.isAcceptableOrUnknown(
              data['merchant_full_name']!, _merchantFullNameMeta));
    }
    if (data.containsKey('acquirer')) {
      context.handle(_acquirerMeta,
          acquirer.isAcceptableOrUnknown(data['acquirer']!, _acquirerMeta));
    }
    if (data.containsKey('details_text')) {
      context.handle(
          _detailsTextMeta,
          detailsText.isAcceptableOrUnknown(
              data['details_text']!, _detailsTextMeta));
    }
    if (data.containsKey('discount_amount')) {
      context.handle(
          _discountAmountMeta,
          discountAmount.isAcceptableOrUnknown(
              data['discount_amount']!, _discountAmountMeta));
    }
    if (data.containsKey('needs_classification')) {
      context.handle(
          _needsClassificationMeta,
          needsClassification.isAcceptableOrUnknown(
              data['needs_classification']!, _needsClassificationMeta));
    }
    if (data.containsKey('recurring_id')) {
      context.handle(
          _recurringIdMeta,
          recurringId.isAcceptableOrUnknown(
              data['recurring_id']!, _recurringIdMeta));
    }
    if (data.containsKey('sync_id')) {
      context.handle(_syncIdMeta,
          syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      ledgerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ledger_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category_id']),
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}account_id']),
      toAccountId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}to_account_id']),
      happenedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}happened_at'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      paymentMethod: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payment_method']),
      counterparty: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}counterparty']),
      paymentChannel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payment_channel']),
      merchantFullName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}merchant_full_name']),
      acquirer: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}acquirer']),
      detailsText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}details_text']),
      discountAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}discount_amount']),
      needsClassification: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}needs_classification'])!,
      recurringId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}recurring_id']),
      syncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_id']),
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final int id;
  final int ledgerId;
  final String type;
  final double amount;
  final int? categoryId;
  final int? accountId;
  final int? toAccountId;
  final DateTime happenedAt;
  final String? note;
  final String? paymentMethod;
  final String? counterparty;
  final String? paymentChannel;
  final String? merchantFullName;
  final String? acquirer;
  final String? detailsText;
  final double? discountAmount;
  final bool needsClassification;
  final int? recurringId;
  final String? syncId;
  const Transaction(
      {required this.id,
      required this.ledgerId,
      required this.type,
      required this.amount,
      this.categoryId,
      this.accountId,
      this.toAccountId,
      required this.happenedAt,
      this.note,
      this.paymentMethod,
      this.counterparty,
      this.paymentChannel,
      this.merchantFullName,
      this.acquirer,
      this.detailsText,
      this.discountAmount,
      required this.needsClassification,
      this.recurringId,
      this.syncId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ledger_id'] = Variable<int>(ledgerId);
    map['type'] = Variable<String>(type);
    map['amount'] = Variable<double>(amount);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<int>(accountId);
    }
    if (!nullToAbsent || toAccountId != null) {
      map['to_account_id'] = Variable<int>(toAccountId);
    }
    map['happened_at'] = Variable<DateTime>(happenedAt);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || paymentMethod != null) {
      map['payment_method'] = Variable<String>(paymentMethod);
    }
    if (!nullToAbsent || counterparty != null) {
      map['counterparty'] = Variable<String>(counterparty);
    }
    if (!nullToAbsent || paymentChannel != null) {
      map['payment_channel'] = Variable<String>(paymentChannel);
    }
    if (!nullToAbsent || merchantFullName != null) {
      map['merchant_full_name'] = Variable<String>(merchantFullName);
    }
    if (!nullToAbsent || acquirer != null) {
      map['acquirer'] = Variable<String>(acquirer);
    }
    if (!nullToAbsent || detailsText != null) {
      map['details_text'] = Variable<String>(detailsText);
    }
    if (!nullToAbsent || discountAmount != null) {
      map['discount_amount'] = Variable<double>(discountAmount);
    }
    map['needs_classification'] = Variable<bool>(needsClassification);
    if (!nullToAbsent || recurringId != null) {
      map['recurring_id'] = Variable<int>(recurringId);
    }
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      ledgerId: Value(ledgerId),
      type: Value(type),
      amount: Value(amount),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      toAccountId: toAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(toAccountId),
      happenedAt: Value(happenedAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      paymentMethod: paymentMethod == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentMethod),
      counterparty: counterparty == null && nullToAbsent
          ? const Value.absent()
          : Value(counterparty),
      paymentChannel: paymentChannel == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentChannel),
      merchantFullName: merchantFullName == null && nullToAbsent
          ? const Value.absent()
          : Value(merchantFullName),
      acquirer: acquirer == null && nullToAbsent
          ? const Value.absent()
          : Value(acquirer),
      detailsText: detailsText == null && nullToAbsent
          ? const Value.absent()
          : Value(detailsText),
      discountAmount: discountAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(discountAmount),
      needsClassification: Value(needsClassification),
      recurringId: recurringId == null && nullToAbsent
          ? const Value.absent()
          : Value(recurringId),
      syncId:
          syncId == null && nullToAbsent ? const Value.absent() : Value(syncId),
    );
  }

  factory Transaction.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<int>(json['id']),
      ledgerId: serializer.fromJson<int>(json['ledgerId']),
      type: serializer.fromJson<String>(json['type']),
      amount: serializer.fromJson<double>(json['amount']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      accountId: serializer.fromJson<int?>(json['accountId']),
      toAccountId: serializer.fromJson<int?>(json['toAccountId']),
      happenedAt: serializer.fromJson<DateTime>(json['happenedAt']),
      note: serializer.fromJson<String?>(json['note']),
      paymentMethod: serializer.fromJson<String?>(json['paymentMethod']),
      counterparty: serializer.fromJson<String?>(json['counterparty']),
      paymentChannel: serializer.fromJson<String?>(json['paymentChannel']),
      merchantFullName: serializer.fromJson<String?>(json['merchantFullName']),
      acquirer: serializer.fromJson<String?>(json['acquirer']),
      detailsText: serializer.fromJson<String?>(json['detailsText']),
      discountAmount: serializer.fromJson<double?>(json['discountAmount']),
      needsClassification:
          serializer.fromJson<bool>(json['needsClassification']),
      recurringId: serializer.fromJson<int?>(json['recurringId']),
      syncId: serializer.fromJson<String?>(json['syncId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ledgerId': serializer.toJson<int>(ledgerId),
      'type': serializer.toJson<String>(type),
      'amount': serializer.toJson<double>(amount),
      'categoryId': serializer.toJson<int?>(categoryId),
      'accountId': serializer.toJson<int?>(accountId),
      'toAccountId': serializer.toJson<int?>(toAccountId),
      'happenedAt': serializer.toJson<DateTime>(happenedAt),
      'note': serializer.toJson<String?>(note),
      'paymentMethod': serializer.toJson<String?>(paymentMethod),
      'counterparty': serializer.toJson<String?>(counterparty),
      'paymentChannel': serializer.toJson<String?>(paymentChannel),
      'merchantFullName': serializer.toJson<String?>(merchantFullName),
      'acquirer': serializer.toJson<String?>(acquirer),
      'detailsText': serializer.toJson<String?>(detailsText),
      'discountAmount': serializer.toJson<double?>(discountAmount),
      'needsClassification': serializer.toJson<bool>(needsClassification),
      'recurringId': serializer.toJson<int?>(recurringId),
      'syncId': serializer.toJson<String?>(syncId),
    };
  }

  Transaction copyWith(
          {int? id,
          int? ledgerId,
          String? type,
          double? amount,
          Value<int?> categoryId = const Value.absent(),
          Value<int?> accountId = const Value.absent(),
          Value<int?> toAccountId = const Value.absent(),
          DateTime? happenedAt,
          Value<String?> note = const Value.absent(),
          Value<String?> paymentMethod = const Value.absent(),
          Value<String?> counterparty = const Value.absent(),
          Value<String?> paymentChannel = const Value.absent(),
          Value<String?> merchantFullName = const Value.absent(),
          Value<String?> acquirer = const Value.absent(),
          Value<String?> detailsText = const Value.absent(),
          Value<double?> discountAmount = const Value.absent(),
          bool? needsClassification,
          Value<int?> recurringId = const Value.absent(),
          Value<String?> syncId = const Value.absent()}) =>
      Transaction(
        id: id ?? this.id,
        ledgerId: ledgerId ?? this.ledgerId,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        categoryId: categoryId.present ? categoryId.value : this.categoryId,
        accountId: accountId.present ? accountId.value : this.accountId,
        toAccountId: toAccountId.present ? toAccountId.value : this.toAccountId,
        happenedAt: happenedAt ?? this.happenedAt,
        note: note.present ? note.value : this.note,
        paymentMethod:
            paymentMethod.present ? paymentMethod.value : this.paymentMethod,
        counterparty:
            counterparty.present ? counterparty.value : this.counterparty,
        paymentChannel:
            paymentChannel.present ? paymentChannel.value : this.paymentChannel,
        merchantFullName: merchantFullName.present
            ? merchantFullName.value
            : this.merchantFullName,
        acquirer: acquirer.present ? acquirer.value : this.acquirer,
        detailsText: detailsText.present ? detailsText.value : this.detailsText,
        discountAmount:
            discountAmount.present ? discountAmount.value : this.discountAmount,
        needsClassification: needsClassification ?? this.needsClassification,
        recurringId: recurringId.present ? recurringId.value : this.recurringId,
        syncId: syncId.present ? syncId.value : this.syncId,
      );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      type: data.type.present ? data.type.value : this.type,
      amount: data.amount.present ? data.amount.value : this.amount,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      toAccountId:
          data.toAccountId.present ? data.toAccountId.value : this.toAccountId,
      happenedAt:
          data.happenedAt.present ? data.happenedAt.value : this.happenedAt,
      note: data.note.present ? data.note.value : this.note,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      counterparty: data.counterparty.present
          ? data.counterparty.value
          : this.counterparty,
      paymentChannel: data.paymentChannel.present
          ? data.paymentChannel.value
          : this.paymentChannel,
      merchantFullName: data.merchantFullName.present
          ? data.merchantFullName.value
          : this.merchantFullName,
      acquirer: data.acquirer.present ? data.acquirer.value : this.acquirer,
      detailsText:
          data.detailsText.present ? data.detailsText.value : this.detailsText,
      discountAmount: data.discountAmount.present
          ? data.discountAmount.value
          : this.discountAmount,
      needsClassification: data.needsClassification.present
          ? data.needsClassification.value
          : this.needsClassification,
      recurringId:
          data.recurringId.present ? data.recurringId.value : this.recurringId,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('happenedAt: $happenedAt, ')
          ..write('note: $note, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('counterparty: $counterparty, ')
          ..write('paymentChannel: $paymentChannel, ')
          ..write('merchantFullName: $merchantFullName, ')
          ..write('acquirer: $acquirer, ')
          ..write('detailsText: $detailsText, ')
          ..write('discountAmount: $discountAmount, ')
          ..write('needsClassification: $needsClassification, ')
          ..write('recurringId: $recurringId, ')
          ..write('syncId: $syncId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      ledgerId,
      type,
      amount,
      categoryId,
      accountId,
      toAccountId,
      happenedAt,
      note,
      paymentMethod,
      counterparty,
      paymentChannel,
      merchantFullName,
      acquirer,
      detailsText,
      discountAmount,
      needsClassification,
      recurringId,
      syncId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.ledgerId == this.ledgerId &&
          other.type == this.type &&
          other.amount == this.amount &&
          other.categoryId == this.categoryId &&
          other.accountId == this.accountId &&
          other.toAccountId == this.toAccountId &&
          other.happenedAt == this.happenedAt &&
          other.note == this.note &&
          other.paymentMethod == this.paymentMethod &&
          other.counterparty == this.counterparty &&
          other.paymentChannel == this.paymentChannel &&
          other.merchantFullName == this.merchantFullName &&
          other.acquirer == this.acquirer &&
          other.detailsText == this.detailsText &&
          other.discountAmount == this.discountAmount &&
          other.needsClassification == this.needsClassification &&
          other.recurringId == this.recurringId &&
          other.syncId == this.syncId);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<int> id;
  final Value<int> ledgerId;
  final Value<String> type;
  final Value<double> amount;
  final Value<int?> categoryId;
  final Value<int?> accountId;
  final Value<int?> toAccountId;
  final Value<DateTime> happenedAt;
  final Value<String?> note;
  final Value<String?> paymentMethod;
  final Value<String?> counterparty;
  final Value<String?> paymentChannel;
  final Value<String?> merchantFullName;
  final Value<String?> acquirer;
  final Value<String?> detailsText;
  final Value<double?> discountAmount;
  final Value<bool> needsClassification;
  final Value<int?> recurringId;
  final Value<String?> syncId;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.type = const Value.absent(),
    this.amount = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    this.happenedAt = const Value.absent(),
    this.note = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.counterparty = const Value.absent(),
    this.paymentChannel = const Value.absent(),
    this.merchantFullName = const Value.absent(),
    this.acquirer = const Value.absent(),
    this.detailsText = const Value.absent(),
    this.discountAmount = const Value.absent(),
    this.needsClassification = const Value.absent(),
    this.recurringId = const Value.absent(),
    this.syncId = const Value.absent(),
  });
  TransactionsCompanion.insert({
    this.id = const Value.absent(),
    required int ledgerId,
    required String type,
    required double amount,
    this.categoryId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    this.happenedAt = const Value.absent(),
    this.note = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.counterparty = const Value.absent(),
    this.paymentChannel = const Value.absent(),
    this.merchantFullName = const Value.absent(),
    this.acquirer = const Value.absent(),
    this.detailsText = const Value.absent(),
    this.discountAmount = const Value.absent(),
    this.needsClassification = const Value.absent(),
    this.recurringId = const Value.absent(),
    this.syncId = const Value.absent(),
  })  : ledgerId = Value(ledgerId),
        type = Value(type),
        amount = Value(amount);
  static Insertable<Transaction> custom({
    Expression<int>? id,
    Expression<int>? ledgerId,
    Expression<String>? type,
    Expression<double>? amount,
    Expression<int>? categoryId,
    Expression<int>? accountId,
    Expression<int>? toAccountId,
    Expression<DateTime>? happenedAt,
    Expression<String>? note,
    Expression<String>? paymentMethod,
    Expression<String>? counterparty,
    Expression<String>? paymentChannel,
    Expression<String>? merchantFullName,
    Expression<String>? acquirer,
    Expression<String>? detailsText,
    Expression<double>? discountAmount,
    Expression<bool>? needsClassification,
    Expression<int>? recurringId,
    Expression<String>? syncId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (categoryId != null) 'category_id': categoryId,
      if (accountId != null) 'account_id': accountId,
      if (toAccountId != null) 'to_account_id': toAccountId,
      if (happenedAt != null) 'happened_at': happenedAt,
      if (note != null) 'note': note,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (counterparty != null) 'counterparty': counterparty,
      if (paymentChannel != null) 'payment_channel': paymentChannel,
      if (merchantFullName != null) 'merchant_full_name': merchantFullName,
      if (acquirer != null) 'acquirer': acquirer,
      if (detailsText != null) 'details_text': detailsText,
      if (discountAmount != null) 'discount_amount': discountAmount,
      if (needsClassification != null)
        'needs_classification': needsClassification,
      if (recurringId != null) 'recurring_id': recurringId,
      if (syncId != null) 'sync_id': syncId,
    });
  }

  TransactionsCompanion copyWith(
      {Value<int>? id,
      Value<int>? ledgerId,
      Value<String>? type,
      Value<double>? amount,
      Value<int?>? categoryId,
      Value<int?>? accountId,
      Value<int?>? toAccountId,
      Value<DateTime>? happenedAt,
      Value<String?>? note,
      Value<String?>? paymentMethod,
      Value<String?>? counterparty,
      Value<String?>? paymentChannel,
      Value<String?>? merchantFullName,
      Value<String?>? acquirer,
      Value<String?>? detailsText,
      Value<double?>? discountAmount,
      Value<bool>? needsClassification,
      Value<int?>? recurringId,
      Value<String?>? syncId}) {
    return TransactionsCompanion(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      happenedAt: happenedAt ?? this.happenedAt,
      note: note ?? this.note,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      counterparty: counterparty ?? this.counterparty,
      paymentChannel: paymentChannel ?? this.paymentChannel,
      merchantFullName: merchantFullName ?? this.merchantFullName,
      acquirer: acquirer ?? this.acquirer,
      detailsText: detailsText ?? this.detailsText,
      discountAmount: discountAmount ?? this.discountAmount,
      needsClassification: needsClassification ?? this.needsClassification,
      recurringId: recurringId ?? this.recurringId,
      syncId: syncId ?? this.syncId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<int>(ledgerId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (toAccountId.present) {
      map['to_account_id'] = Variable<int>(toAccountId.value);
    }
    if (happenedAt.present) {
      map['happened_at'] = Variable<DateTime>(happenedAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (counterparty.present) {
      map['counterparty'] = Variable<String>(counterparty.value);
    }
    if (paymentChannel.present) {
      map['payment_channel'] = Variable<String>(paymentChannel.value);
    }
    if (merchantFullName.present) {
      map['merchant_full_name'] = Variable<String>(merchantFullName.value);
    }
    if (acquirer.present) {
      map['acquirer'] = Variable<String>(acquirer.value);
    }
    if (detailsText.present) {
      map['details_text'] = Variable<String>(detailsText.value);
    }
    if (discountAmount.present) {
      map['discount_amount'] = Variable<double>(discountAmount.value);
    }
    if (needsClassification.present) {
      map['needs_classification'] = Variable<bool>(needsClassification.value);
    }
    if (recurringId.present) {
      map['recurring_id'] = Variable<int>(recurringId.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('happenedAt: $happenedAt, ')
          ..write('note: $note, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('counterparty: $counterparty, ')
          ..write('paymentChannel: $paymentChannel, ')
          ..write('merchantFullName: $merchantFullName, ')
          ..write('acquirer: $acquirer, ')
          ..write('detailsText: $detailsText, ')
          ..write('discountAmount: $discountAmount, ')
          ..write('needsClassification: $needsClassification, ')
          ..write('recurringId: $recurringId, ')
          ..write('syncId: $syncId')
          ..write(')'))
        .toString();
  }
}

class $RecurringTransactionsTable extends RecurringTransactions
    with TableInfo<$RecurringTransactionsTable, RecurringTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecurringTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _ledgerIdMeta =
      const VerificationMeta('ledgerId');
  @override
  late final GeneratedColumn<int> ledgerId = GeneratedColumn<int>(
      'ledger_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
      'category_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
      'account_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _toAccountIdMeta =
      const VerificationMeta('toAccountId');
  @override
  late final GeneratedColumn<int> toAccountId = GeneratedColumn<int>(
      'to_account_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _frequencyMeta =
      const VerificationMeta('frequency');
  @override
  late final GeneratedColumn<String> frequency = GeneratedColumn<String>(
      'frequency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _intervalMeta =
      const VerificationMeta('interval');
  @override
  late final GeneratedColumn<int> interval = GeneratedColumn<int>(
      'interval', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _dayOfMonthMeta =
      const VerificationMeta('dayOfMonth');
  @override
  late final GeneratedColumn<int> dayOfMonth = GeneratedColumn<int>(
      'day_of_month', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _dayOfWeekMeta =
      const VerificationMeta('dayOfWeek');
  @override
  late final GeneratedColumn<int> dayOfWeek = GeneratedColumn<int>(
      'day_of_week', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _monthOfYearMeta =
      const VerificationMeta('monthOfYear');
  @override
  late final GeneratedColumn<int> monthOfYear = GeneratedColumn<int>(
      'month_of_year', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _startDateMeta =
      const VerificationMeta('startDate');
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
      'start_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endDateMeta =
      const VerificationMeta('endDate');
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
      'end_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastGeneratedDateMeta =
      const VerificationMeta('lastGeneratedDate');
  @override
  late final GeneratedColumn<DateTime> lastGeneratedDate =
      GeneratedColumn<DateTime>('last_generated_date', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _enabledMeta =
      const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
      'enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        ledgerId,
        type,
        amount,
        categoryId,
        accountId,
        toAccountId,
        note,
        frequency,
        interval,
        dayOfMonth,
        dayOfWeek,
        monthOfYear,
        startDate,
        endDate,
        lastGeneratedDate,
        enabled,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recurring_transactions';
  @override
  VerificationContext validateIntegrity(
      Insertable<RecurringTransaction> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ledger_id')) {
      context.handle(_ledgerIdMeta,
          ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta));
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    }
    if (data.containsKey('to_account_id')) {
      context.handle(
          _toAccountIdMeta,
          toAccountId.isAcceptableOrUnknown(
              data['to_account_id']!, _toAccountIdMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('frequency')) {
      context.handle(_frequencyMeta,
          frequency.isAcceptableOrUnknown(data['frequency']!, _frequencyMeta));
    } else if (isInserting) {
      context.missing(_frequencyMeta);
    }
    if (data.containsKey('interval')) {
      context.handle(_intervalMeta,
          interval.isAcceptableOrUnknown(data['interval']!, _intervalMeta));
    }
    if (data.containsKey('day_of_month')) {
      context.handle(
          _dayOfMonthMeta,
          dayOfMonth.isAcceptableOrUnknown(
              data['day_of_month']!, _dayOfMonthMeta));
    }
    if (data.containsKey('day_of_week')) {
      context.handle(
          _dayOfWeekMeta,
          dayOfWeek.isAcceptableOrUnknown(
              data['day_of_week']!, _dayOfWeekMeta));
    }
    if (data.containsKey('month_of_year')) {
      context.handle(
          _monthOfYearMeta,
          monthOfYear.isAcceptableOrUnknown(
              data['month_of_year']!, _monthOfYearMeta));
    }
    if (data.containsKey('start_date')) {
      context.handle(_startDateMeta,
          startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta));
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(_endDateMeta,
          endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta));
    }
    if (data.containsKey('last_generated_date')) {
      context.handle(
          _lastGeneratedDateMeta,
          lastGeneratedDate.isAcceptableOrUnknown(
              data['last_generated_date']!, _lastGeneratedDateMeta));
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta,
          enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecurringTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecurringTransaction(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      ledgerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ledger_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category_id']),
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}account_id']),
      toAccountId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}to_account_id']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      frequency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}frequency'])!,
      interval: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}interval'])!,
      dayOfMonth: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day_of_month']),
      dayOfWeek: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day_of_week']),
      monthOfYear: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}month_of_year']),
      startDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_date'])!,
      endDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end_date']),
      lastGeneratedDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_generated_date']),
      enabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $RecurringTransactionsTable createAlias(String alias) {
    return $RecurringTransactionsTable(attachedDatabase, alias);
  }
}

class RecurringTransaction extends DataClass
    implements Insertable<RecurringTransaction> {
  final int id;
  final int ledgerId;
  final String type;
  final double amount;
  final int? categoryId;
  final int? accountId;
  final int? toAccountId;
  final String? note;
  final String frequency;
  final int interval;
  final int? dayOfMonth;
  final int? dayOfWeek;
  final int? monthOfYear;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? lastGeneratedDate;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  const RecurringTransaction(
      {required this.id,
      required this.ledgerId,
      required this.type,
      required this.amount,
      this.categoryId,
      this.accountId,
      this.toAccountId,
      this.note,
      required this.frequency,
      required this.interval,
      this.dayOfMonth,
      this.dayOfWeek,
      this.monthOfYear,
      required this.startDate,
      this.endDate,
      this.lastGeneratedDate,
      required this.enabled,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ledger_id'] = Variable<int>(ledgerId);
    map['type'] = Variable<String>(type);
    map['amount'] = Variable<double>(amount);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<int>(accountId);
    }
    if (!nullToAbsent || toAccountId != null) {
      map['to_account_id'] = Variable<int>(toAccountId);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['frequency'] = Variable<String>(frequency);
    map['interval'] = Variable<int>(interval);
    if (!nullToAbsent || dayOfMonth != null) {
      map['day_of_month'] = Variable<int>(dayOfMonth);
    }
    if (!nullToAbsent || dayOfWeek != null) {
      map['day_of_week'] = Variable<int>(dayOfWeek);
    }
    if (!nullToAbsent || monthOfYear != null) {
      map['month_of_year'] = Variable<int>(monthOfYear);
    }
    map['start_date'] = Variable<DateTime>(startDate);
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    if (!nullToAbsent || lastGeneratedDate != null) {
      map['last_generated_date'] = Variable<DateTime>(lastGeneratedDate);
    }
    map['enabled'] = Variable<bool>(enabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RecurringTransactionsCompanion toCompanion(bool nullToAbsent) {
    return RecurringTransactionsCompanion(
      id: Value(id),
      ledgerId: Value(ledgerId),
      type: Value(type),
      amount: Value(amount),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      toAccountId: toAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(toAccountId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      frequency: Value(frequency),
      interval: Value(interval),
      dayOfMonth: dayOfMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(dayOfMonth),
      dayOfWeek: dayOfWeek == null && nullToAbsent
          ? const Value.absent()
          : Value(dayOfWeek),
      monthOfYear: monthOfYear == null && nullToAbsent
          ? const Value.absent()
          : Value(monthOfYear),
      startDate: Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      lastGeneratedDate: lastGeneratedDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastGeneratedDate),
      enabled: Value(enabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory RecurringTransaction.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecurringTransaction(
      id: serializer.fromJson<int>(json['id']),
      ledgerId: serializer.fromJson<int>(json['ledgerId']),
      type: serializer.fromJson<String>(json['type']),
      amount: serializer.fromJson<double>(json['amount']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      accountId: serializer.fromJson<int?>(json['accountId']),
      toAccountId: serializer.fromJson<int?>(json['toAccountId']),
      note: serializer.fromJson<String?>(json['note']),
      frequency: serializer.fromJson<String>(json['frequency']),
      interval: serializer.fromJson<int>(json['interval']),
      dayOfMonth: serializer.fromJson<int?>(json['dayOfMonth']),
      dayOfWeek: serializer.fromJson<int?>(json['dayOfWeek']),
      monthOfYear: serializer.fromJson<int?>(json['monthOfYear']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      lastGeneratedDate:
          serializer.fromJson<DateTime?>(json['lastGeneratedDate']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ledgerId': serializer.toJson<int>(ledgerId),
      'type': serializer.toJson<String>(type),
      'amount': serializer.toJson<double>(amount),
      'categoryId': serializer.toJson<int?>(categoryId),
      'accountId': serializer.toJson<int?>(accountId),
      'toAccountId': serializer.toJson<int?>(toAccountId),
      'note': serializer.toJson<String?>(note),
      'frequency': serializer.toJson<String>(frequency),
      'interval': serializer.toJson<int>(interval),
      'dayOfMonth': serializer.toJson<int?>(dayOfMonth),
      'dayOfWeek': serializer.toJson<int?>(dayOfWeek),
      'monthOfYear': serializer.toJson<int?>(monthOfYear),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'lastGeneratedDate': serializer.toJson<DateTime?>(lastGeneratedDate),
      'enabled': serializer.toJson<bool>(enabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RecurringTransaction copyWith(
          {int? id,
          int? ledgerId,
          String? type,
          double? amount,
          Value<int?> categoryId = const Value.absent(),
          Value<int?> accountId = const Value.absent(),
          Value<int?> toAccountId = const Value.absent(),
          Value<String?> note = const Value.absent(),
          String? frequency,
          int? interval,
          Value<int?> dayOfMonth = const Value.absent(),
          Value<int?> dayOfWeek = const Value.absent(),
          Value<int?> monthOfYear = const Value.absent(),
          DateTime? startDate,
          Value<DateTime?> endDate = const Value.absent(),
          Value<DateTime?> lastGeneratedDate = const Value.absent(),
          bool? enabled,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      RecurringTransaction(
        id: id ?? this.id,
        ledgerId: ledgerId ?? this.ledgerId,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        categoryId: categoryId.present ? categoryId.value : this.categoryId,
        accountId: accountId.present ? accountId.value : this.accountId,
        toAccountId: toAccountId.present ? toAccountId.value : this.toAccountId,
        note: note.present ? note.value : this.note,
        frequency: frequency ?? this.frequency,
        interval: interval ?? this.interval,
        dayOfMonth: dayOfMonth.present ? dayOfMonth.value : this.dayOfMonth,
        dayOfWeek: dayOfWeek.present ? dayOfWeek.value : this.dayOfWeek,
        monthOfYear: monthOfYear.present ? monthOfYear.value : this.monthOfYear,
        startDate: startDate ?? this.startDate,
        endDate: endDate.present ? endDate.value : this.endDate,
        lastGeneratedDate: lastGeneratedDate.present
            ? lastGeneratedDate.value
            : this.lastGeneratedDate,
        enabled: enabled ?? this.enabled,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  RecurringTransaction copyWithCompanion(RecurringTransactionsCompanion data) {
    return RecurringTransaction(
      id: data.id.present ? data.id.value : this.id,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      type: data.type.present ? data.type.value : this.type,
      amount: data.amount.present ? data.amount.value : this.amount,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      toAccountId:
          data.toAccountId.present ? data.toAccountId.value : this.toAccountId,
      note: data.note.present ? data.note.value : this.note,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      interval: data.interval.present ? data.interval.value : this.interval,
      dayOfMonth:
          data.dayOfMonth.present ? data.dayOfMonth.value : this.dayOfMonth,
      dayOfWeek: data.dayOfWeek.present ? data.dayOfWeek.value : this.dayOfWeek,
      monthOfYear:
          data.monthOfYear.present ? data.monthOfYear.value : this.monthOfYear,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      lastGeneratedDate: data.lastGeneratedDate.present
          ? data.lastGeneratedDate.value
          : this.lastGeneratedDate,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecurringTransaction(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('note: $note, ')
          ..write('frequency: $frequency, ')
          ..write('interval: $interval, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('monthOfYear: $monthOfYear, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('lastGeneratedDate: $lastGeneratedDate, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      ledgerId,
      type,
      amount,
      categoryId,
      accountId,
      toAccountId,
      note,
      frequency,
      interval,
      dayOfMonth,
      dayOfWeek,
      monthOfYear,
      startDate,
      endDate,
      lastGeneratedDate,
      enabled,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecurringTransaction &&
          other.id == this.id &&
          other.ledgerId == this.ledgerId &&
          other.type == this.type &&
          other.amount == this.amount &&
          other.categoryId == this.categoryId &&
          other.accountId == this.accountId &&
          other.toAccountId == this.toAccountId &&
          other.note == this.note &&
          other.frequency == this.frequency &&
          other.interval == this.interval &&
          other.dayOfMonth == this.dayOfMonth &&
          other.dayOfWeek == this.dayOfWeek &&
          other.monthOfYear == this.monthOfYear &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.lastGeneratedDate == this.lastGeneratedDate &&
          other.enabled == this.enabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RecurringTransactionsCompanion
    extends UpdateCompanion<RecurringTransaction> {
  final Value<int> id;
  final Value<int> ledgerId;
  final Value<String> type;
  final Value<double> amount;
  final Value<int?> categoryId;
  final Value<int?> accountId;
  final Value<int?> toAccountId;
  final Value<String?> note;
  final Value<String> frequency;
  final Value<int> interval;
  final Value<int?> dayOfMonth;
  final Value<int?> dayOfWeek;
  final Value<int?> monthOfYear;
  final Value<DateTime> startDate;
  final Value<DateTime?> endDate;
  final Value<DateTime?> lastGeneratedDate;
  final Value<bool> enabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const RecurringTransactionsCompanion({
    this.id = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.type = const Value.absent(),
    this.amount = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    this.note = const Value.absent(),
    this.frequency = const Value.absent(),
    this.interval = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.dayOfWeek = const Value.absent(),
    this.monthOfYear = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.lastGeneratedDate = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  RecurringTransactionsCompanion.insert({
    this.id = const Value.absent(),
    required int ledgerId,
    required String type,
    required double amount,
    this.categoryId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    this.note = const Value.absent(),
    required String frequency,
    this.interval = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.dayOfWeek = const Value.absent(),
    this.monthOfYear = const Value.absent(),
    required DateTime startDate,
    this.endDate = const Value.absent(),
    this.lastGeneratedDate = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : ledgerId = Value(ledgerId),
        type = Value(type),
        amount = Value(amount),
        frequency = Value(frequency),
        startDate = Value(startDate);
  static Insertable<RecurringTransaction> custom({
    Expression<int>? id,
    Expression<int>? ledgerId,
    Expression<String>? type,
    Expression<double>? amount,
    Expression<int>? categoryId,
    Expression<int>? accountId,
    Expression<int>? toAccountId,
    Expression<String>? note,
    Expression<String>? frequency,
    Expression<int>? interval,
    Expression<int>? dayOfMonth,
    Expression<int>? dayOfWeek,
    Expression<int>? monthOfYear,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<DateTime>? lastGeneratedDate,
    Expression<bool>? enabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (categoryId != null) 'category_id': categoryId,
      if (accountId != null) 'account_id': accountId,
      if (toAccountId != null) 'to_account_id': toAccountId,
      if (note != null) 'note': note,
      if (frequency != null) 'frequency': frequency,
      if (interval != null) 'interval': interval,
      if (dayOfMonth != null) 'day_of_month': dayOfMonth,
      if (dayOfWeek != null) 'day_of_week': dayOfWeek,
      if (monthOfYear != null) 'month_of_year': monthOfYear,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (lastGeneratedDate != null) 'last_generated_date': lastGeneratedDate,
      if (enabled != null) 'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  RecurringTransactionsCompanion copyWith(
      {Value<int>? id,
      Value<int>? ledgerId,
      Value<String>? type,
      Value<double>? amount,
      Value<int?>? categoryId,
      Value<int?>? accountId,
      Value<int?>? toAccountId,
      Value<String?>? note,
      Value<String>? frequency,
      Value<int>? interval,
      Value<int?>? dayOfMonth,
      Value<int?>? dayOfWeek,
      Value<int?>? monthOfYear,
      Value<DateTime>? startDate,
      Value<DateTime?>? endDate,
      Value<DateTime?>? lastGeneratedDate,
      Value<bool>? enabled,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return RecurringTransactionsCompanion(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      note: note ?? this.note,
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      monthOfYear: monthOfYear ?? this.monthOfYear,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      lastGeneratedDate: lastGeneratedDate ?? this.lastGeneratedDate,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<int>(ledgerId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (toAccountId.present) {
      map['to_account_id'] = Variable<int>(toAccountId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<String>(frequency.value);
    }
    if (interval.present) {
      map['interval'] = Variable<int>(interval.value);
    }
    if (dayOfMonth.present) {
      map['day_of_month'] = Variable<int>(dayOfMonth.value);
    }
    if (dayOfWeek.present) {
      map['day_of_week'] = Variable<int>(dayOfWeek.value);
    }
    if (monthOfYear.present) {
      map['month_of_year'] = Variable<int>(monthOfYear.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (lastGeneratedDate.present) {
      map['last_generated_date'] = Variable<DateTime>(lastGeneratedDate.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecurringTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('note: $note, ')
          ..write('frequency: $frequency, ')
          ..write('interval: $interval, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('monthOfYear: $monthOfYear, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('lastGeneratedDate: $lastGeneratedDate, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, Conversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _ledgerIdMeta =
      const VerificationMeta('ledgerId');
  @override
  late final GeneratedColumn<int> ledgerId = GeneratedColumn<int>(
      'ledger_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('AI对话'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, ledgerId, title, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(Insertable<Conversation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ledger_id')) {
      context.handle(_ledgerIdMeta,
          ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Conversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conversation(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      ledgerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ledger_id']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class Conversation extends DataClass implements Insertable<Conversation> {
  final int id;
  final int? ledgerId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Conversation(
      {required this.id,
      this.ledgerId,
      required this.title,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || ledgerId != null) {
      map['ledger_id'] = Variable<int>(ledgerId);
    }
    map['title'] = Variable<String>(title);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      ledgerId: ledgerId == null && nullToAbsent
          ? const Value.absent()
          : Value(ledgerId),
      title: Value(title),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Conversation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conversation(
      id: serializer.fromJson<int>(json['id']),
      ledgerId: serializer.fromJson<int?>(json['ledgerId']),
      title: serializer.fromJson<String>(json['title']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ledgerId': serializer.toJson<int?>(ledgerId),
      'title': serializer.toJson<String>(title),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Conversation copyWith(
          {int? id,
          Value<int?> ledgerId = const Value.absent(),
          String? title,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Conversation(
        id: id ?? this.id,
        ledgerId: ledgerId.present ? ledgerId.value : this.ledgerId,
        title: title ?? this.title,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Conversation copyWithCompanion(ConversationsCompanion data) {
    return Conversation(
      id: data.id.present ? data.id.value : this.id,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conversation(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ledgerId, title, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conversation &&
          other.id == this.id &&
          other.ledgerId == this.ledgerId &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ConversationsCompanion extends UpdateCompanion<Conversation> {
  final Value<int> id;
  final Value<int?> ledgerId;
  final Value<String> title;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ConversationsCompanion.insert({
    this.id = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<Conversation> custom({
    Expression<int>? id,
    Expression<int>? ledgerId,
    Expression<String>? title,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ConversationsCompanion copyWith(
      {Value<int>? id,
      Value<int?>? ledgerId,
      Value<String>? title,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return ConversationsCompanion(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<int>(ledgerId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<int> conversationId = GeneratedColumn<int>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
      'role', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _messageTypeMeta =
      const VerificationMeta('messageType');
  @override
  late final GeneratedColumn<String> messageType = GeneratedColumn<String>(
      'message_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _metadataMeta =
      const VerificationMeta('metadata');
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
      'metadata', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _transactionIdMeta =
      const VerificationMeta('transactionId');
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
      'transaction_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        conversationId,
        role,
        content,
        messageType,
        metadata,
        transactionId,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(Insertable<Message> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
          _roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('message_type')) {
      context.handle(
          _messageTypeMeta,
          messageType.isAcceptableOrUnknown(
              data['message_type']!, _messageTypeMeta));
    } else if (isInserting) {
      context.missing(_messageTypeMeta);
    }
    if (data.containsKey('metadata')) {
      context.handle(_metadataMeta,
          metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta));
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
          _transactionIdMeta,
          transactionId.isAcceptableOrUnknown(
              data['transaction_id']!, _transactionIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      conversationId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}conversation_id'])!,
      role: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      messageType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_type'])!,
      metadata: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}metadata']),
      transactionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}transaction_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final int id;
  final int conversationId;
  final String role;
  final String content;
  final String messageType;
  final String? metadata;
  final int? transactionId;
  final DateTime createdAt;
  const Message(
      {required this.id,
      required this.conversationId,
      required this.role,
      required this.content,
      required this.messageType,
      this.metadata,
      this.transactionId,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['conversation_id'] = Variable<int>(conversationId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    map['message_type'] = Variable<String>(messageType);
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<int>(transactionId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      role: Value(role),
      content: Value(content),
      messageType: Value(messageType),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
      createdAt: Value(createdAt),
    );
  }

  factory Message.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<int>(json['id']),
      conversationId: serializer.fromJson<int>(json['conversationId']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      messageType: serializer.fromJson<String>(json['messageType']),
      metadata: serializer.fromJson<String?>(json['metadata']),
      transactionId: serializer.fromJson<int?>(json['transactionId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'conversationId': serializer.toJson<int>(conversationId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'messageType': serializer.toJson<String>(messageType),
      'metadata': serializer.toJson<String?>(metadata),
      'transactionId': serializer.toJson<int?>(transactionId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Message copyWith(
          {int? id,
          int? conversationId,
          String? role,
          String? content,
          String? messageType,
          Value<String?> metadata = const Value.absent(),
          Value<int?> transactionId = const Value.absent(),
          DateTime? createdAt}) =>
      Message(
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        role: role ?? this.role,
        content: content ?? this.content,
        messageType: messageType ?? this.messageType,
        metadata: metadata.present ? metadata.value : this.metadata,
        transactionId:
            transactionId.present ? transactionId.value : this.transactionId,
        createdAt: createdAt ?? this.createdAt,
      );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      messageType:
          data.messageType.present ? data.messageType.value : this.messageType,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('messageType: $messageType, ')
          ..write('metadata: $metadata, ')
          ..write('transactionId: $transactionId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, conversationId, role, content,
      messageType, metadata, transactionId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.role == this.role &&
          other.content == this.content &&
          other.messageType == this.messageType &&
          other.metadata == this.metadata &&
          other.transactionId == this.transactionId &&
          other.createdAt == this.createdAt);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<int> id;
  final Value<int> conversationId;
  final Value<String> role;
  final Value<String> content;
  final Value<String> messageType;
  final Value<String?> metadata;
  final Value<int?> transactionId;
  final Value<DateTime> createdAt;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.messageType = const Value.absent(),
    this.metadata = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  MessagesCompanion.insert({
    this.id = const Value.absent(),
    required int conversationId,
    required String role,
    required String content,
    required String messageType,
    this.metadata = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : conversationId = Value(conversationId),
        role = Value(role),
        content = Value(content),
        messageType = Value(messageType);
  static Insertable<Message> custom({
    Expression<int>? id,
    Expression<int>? conversationId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<String>? messageType,
    Expression<String>? metadata,
    Expression<int>? transactionId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (messageType != null) 'message_type': messageType,
      if (metadata != null) 'metadata': metadata,
      if (transactionId != null) 'transaction_id': transactionId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  MessagesCompanion copyWith(
      {Value<int>? id,
      Value<int>? conversationId,
      Value<String>? role,
      Value<String>? content,
      Value<String>? messageType,
      Value<String?>? metadata,
      Value<int?>? transactionId,
      Value<DateTime>? createdAt}) {
    return MessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      metadata: metadata ?? this.metadata,
      transactionId: transactionId ?? this.transactionId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<int>(conversationId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (messageType.present) {
      map['message_type'] = Variable<String>(messageType.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('messageType: $messageType, ')
          ..write('metadata: $metadata, ')
          ..write('transactionId: $transactionId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
      'sync_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, color, sortOrder, createdAt, syncId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(Insertable<Tag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('sync_id')) {
      context.handle(_syncIdMeta,
          syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      syncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_id']),
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final int id;
  final String name;
  final String? color;
  final int sortOrder;
  final DateTime createdAt;
  final String? syncId;
  const Tag(
      {required this.id,
      required this.name,
      this.color,
      required this.sortOrder,
      required this.createdAt,
      this.syncId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      color:
          color == null && nullToAbsent ? const Value.absent() : Value(color),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      syncId:
          syncId == null && nullToAbsent ? const Value.absent() : Value(syncId),
    );
  }

  factory Tag.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String?>(json['color']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncId: serializer.fromJson<String?>(json['syncId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String?>(color),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncId': serializer.toJson<String?>(syncId),
    };
  }

  Tag copyWith(
          {int? id,
          String? name,
          Value<String?> color = const Value.absent(),
          int? sortOrder,
          DateTime? createdAt,
          Value<String?> syncId = const Value.absent()}) =>
      Tag(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color.present ? color.value : this.color,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
        syncId: syncId.present ? syncId.value : this.syncId,
      );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncId: $syncId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, color, sortOrder, createdAt, syncId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.syncId == this.syncId);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> color;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<String?> syncId;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncId = const Value.absent(),
  });
  TagsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncId = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Tag> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? color,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<String>? syncId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (syncId != null) 'sync_id': syncId,
    });
  }

  TagsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String?>? color,
      Value<int>? sortOrder,
      Value<DateTime>? createdAt,
      Value<String?>? syncId}) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      syncId: syncId ?? this.syncId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncId: $syncId')
          ..write(')'))
        .toString();
  }
}

class $TransactionTagsTable extends TransactionTags
    with TableInfo<$TransactionTagsTable, TransactionTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _transactionIdMeta =
      const VerificationMeta('transactionId');
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
      'transaction_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
      'tag_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, transactionId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transaction_tags';
  @override
  VerificationContext validateIntegrity(Insertable<TransactionTag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
          _transactionIdMeta,
          transactionId.isAcceptableOrUnknown(
              data['transaction_id']!, _transactionIdMeta));
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
          _tagIdMeta, tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta));
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionTag(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      transactionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}transaction_id'])!,
      tagId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tag_id'])!,
    );
  }

  @override
  $TransactionTagsTable createAlias(String alias) {
    return $TransactionTagsTable(attachedDatabase, alias);
  }
}

class TransactionTag extends DataClass implements Insertable<TransactionTag> {
  final int id;
  final int transactionId;
  final int tagId;
  const TransactionTag(
      {required this.id, required this.transactionId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['transaction_id'] = Variable<int>(transactionId);
    map['tag_id'] = Variable<int>(tagId);
    return map;
  }

  TransactionTagsCompanion toCompanion(bool nullToAbsent) {
    return TransactionTagsCompanion(
      id: Value(id),
      transactionId: Value(transactionId),
      tagId: Value(tagId),
    );
  }

  factory TransactionTag.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionTag(
      id: serializer.fromJson<int>(json['id']),
      transactionId: serializer.fromJson<int>(json['transactionId']),
      tagId: serializer.fromJson<int>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'transactionId': serializer.toJson<int>(transactionId),
      'tagId': serializer.toJson<int>(tagId),
    };
  }

  TransactionTag copyWith({int? id, int? transactionId, int? tagId}) =>
      TransactionTag(
        id: id ?? this.id,
        transactionId: transactionId ?? this.transactionId,
        tagId: tagId ?? this.tagId,
      );
  TransactionTag copyWithCompanion(TransactionTagsCompanion data) {
    return TransactionTag(
      id: data.id.present ? data.id.value : this.id,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionTag(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, transactionId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionTag &&
          other.id == this.id &&
          other.transactionId == this.transactionId &&
          other.tagId == this.tagId);
}

class TransactionTagsCompanion extends UpdateCompanion<TransactionTag> {
  final Value<int> id;
  final Value<int> transactionId;
  final Value<int> tagId;
  const TransactionTagsCompanion({
    this.id = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.tagId = const Value.absent(),
  });
  TransactionTagsCompanion.insert({
    this.id = const Value.absent(),
    required int transactionId,
    required int tagId,
  })  : transactionId = Value(transactionId),
        tagId = Value(tagId);
  static Insertable<TransactionTag> custom({
    Expression<int>? id,
    Expression<int>? transactionId,
    Expression<int>? tagId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transactionId != null) 'transaction_id': transactionId,
      if (tagId != null) 'tag_id': tagId,
    });
  }

  TransactionTagsCompanion copyWith(
      {Value<int>? id, Value<int>? transactionId, Value<int>? tagId}) {
    return TransactionTagsCompanion(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      tagId: tagId ?? this.tagId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionTagsCompanion(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }
}

class $BudgetsTable extends Budgets with TableInfo<$BudgetsTable, Budget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
      'sync_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _ledgerIdMeta =
      const VerificationMeta('ledgerId');
  @override
  late final GeneratedColumn<int> ledgerId = GeneratedColumn<int>(
      'ledger_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('total'));
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
      'category_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _periodMeta = const VerificationMeta('period');
  @override
  late final GeneratedColumn<String> period = GeneratedColumn<String>(
      'period', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('monthly'));
  static const VerificationMeta _startDayMeta =
      const VerificationMeta('startDay');
  @override
  late final GeneratedColumn<int> startDay = GeneratedColumn<int>(
      'start_day', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _enabledMeta =
      const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
      'enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        syncId,
        ledgerId,
        type,
        categoryId,
        amount,
        period,
        startDay,
        enabled,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budgets';
  @override
  VerificationContext validateIntegrity(Insertable<Budget> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sync_id')) {
      context.handle(_syncIdMeta,
          syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta));
    }
    if (data.containsKey('ledger_id')) {
      context.handle(_ledgerIdMeta,
          ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta));
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('period')) {
      context.handle(_periodMeta,
          period.isAcceptableOrUnknown(data['period']!, _periodMeta));
    }
    if (data.containsKey('start_day')) {
      context.handle(_startDayMeta,
          startDay.isAcceptableOrUnknown(data['start_day']!, _startDayMeta));
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta,
          enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Budget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Budget(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      syncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_id']),
      ledgerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ledger_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category_id']),
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      period: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}period'])!,
      startDay: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}start_day'])!,
      enabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $BudgetsTable createAlias(String alias) {
    return $BudgetsTable(attachedDatabase, alias);
  }
}

class Budget extends DataClass implements Insertable<Budget> {
  final int id;

  /// 跨设备同步 syncId(UUID)。v22 新增,migration 给老行补 UUID;之后每次 create
  /// 都必须填。server 端按此做 entity_sync_id,跨设备 LWW 合并。
  final String? syncId;

  /// 关联账本ID
  final int ledgerId;

  /// 预算类型：total-总预算, category-分类预算
  final String type;

  /// 关联分类ID（仅分类预算有值）
  final int? categoryId;

  /// 预算金额
  final double amount;

  /// 预算周期：monthly-月度, weekly-周度, yearly-年度
  final String period;

  /// 周期起始日（1-31，月度预算；1-7，周度预算）
  final int startDay;

  /// 是否启用
  final bool enabled;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;
  const Budget(
      {required this.id,
      this.syncId,
      required this.ledgerId,
      required this.type,
      this.categoryId,
      required this.amount,
      required this.period,
      required this.startDay,
      required this.enabled,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    map['ledger_id'] = Variable<int>(ledgerId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    map['amount'] = Variable<double>(amount);
    map['period'] = Variable<String>(period);
    map['start_day'] = Variable<int>(startDay);
    map['enabled'] = Variable<bool>(enabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BudgetsCompanion toCompanion(bool nullToAbsent) {
    return BudgetsCompanion(
      id: Value(id),
      syncId:
          syncId == null && nullToAbsent ? const Value.absent() : Value(syncId),
      ledgerId: Value(ledgerId),
      type: Value(type),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      amount: Value(amount),
      period: Value(period),
      startDay: Value(startDay),
      enabled: Value(enabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Budget.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Budget(
      id: serializer.fromJson<int>(json['id']),
      syncId: serializer.fromJson<String?>(json['syncId']),
      ledgerId: serializer.fromJson<int>(json['ledgerId']),
      type: serializer.fromJson<String>(json['type']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      amount: serializer.fromJson<double>(json['amount']),
      period: serializer.fromJson<String>(json['period']),
      startDay: serializer.fromJson<int>(json['startDay']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'syncId': serializer.toJson<String?>(syncId),
      'ledgerId': serializer.toJson<int>(ledgerId),
      'type': serializer.toJson<String>(type),
      'categoryId': serializer.toJson<int?>(categoryId),
      'amount': serializer.toJson<double>(amount),
      'period': serializer.toJson<String>(period),
      'startDay': serializer.toJson<int>(startDay),
      'enabled': serializer.toJson<bool>(enabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Budget copyWith(
          {int? id,
          Value<String?> syncId = const Value.absent(),
          int? ledgerId,
          String? type,
          Value<int?> categoryId = const Value.absent(),
          double? amount,
          String? period,
          int? startDay,
          bool? enabled,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Budget(
        id: id ?? this.id,
        syncId: syncId.present ? syncId.value : this.syncId,
        ledgerId: ledgerId ?? this.ledgerId,
        type: type ?? this.type,
        categoryId: categoryId.present ? categoryId.value : this.categoryId,
        amount: amount ?? this.amount,
        period: period ?? this.period,
        startDay: startDay ?? this.startDay,
        enabled: enabled ?? this.enabled,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Budget copyWithCompanion(BudgetsCompanion data) {
    return Budget(
      id: data.id.present ? data.id.value : this.id,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      type: data.type.present ? data.type.value : this.type,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      amount: data.amount.present ? data.amount.value : this.amount,
      period: data.period.present ? data.period.value : this.period,
      startDay: data.startDay.present ? data.startDay.value : this.startDay,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Budget(')
          ..write('id: $id, ')
          ..write('syncId: $syncId, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('type: $type, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('period: $period, ')
          ..write('startDay: $startDay, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, syncId, ledgerId, type, categoryId,
      amount, period, startDay, enabled, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Budget &&
          other.id == this.id &&
          other.syncId == this.syncId &&
          other.ledgerId == this.ledgerId &&
          other.type == this.type &&
          other.categoryId == this.categoryId &&
          other.amount == this.amount &&
          other.period == this.period &&
          other.startDay == this.startDay &&
          other.enabled == this.enabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BudgetsCompanion extends UpdateCompanion<Budget> {
  final Value<int> id;
  final Value<String?> syncId;
  final Value<int> ledgerId;
  final Value<String> type;
  final Value<int?> categoryId;
  final Value<double> amount;
  final Value<String> period;
  final Value<int> startDay;
  final Value<bool> enabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const BudgetsCompanion({
    this.id = const Value.absent(),
    this.syncId = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.type = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amount = const Value.absent(),
    this.period = const Value.absent(),
    this.startDay = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BudgetsCompanion.insert({
    this.id = const Value.absent(),
    this.syncId = const Value.absent(),
    required int ledgerId,
    this.type = const Value.absent(),
    this.categoryId = const Value.absent(),
    required double amount,
    this.period = const Value.absent(),
    this.startDay = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : ledgerId = Value(ledgerId),
        amount = Value(amount);
  static Insertable<Budget> custom({
    Expression<int>? id,
    Expression<String>? syncId,
    Expression<int>? ledgerId,
    Expression<String>? type,
    Expression<int>? categoryId,
    Expression<double>? amount,
    Expression<String>? period,
    Expression<int>? startDay,
    Expression<bool>? enabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (syncId != null) 'sync_id': syncId,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (type != null) 'type': type,
      if (categoryId != null) 'category_id': categoryId,
      if (amount != null) 'amount': amount,
      if (period != null) 'period': period,
      if (startDay != null) 'start_day': startDay,
      if (enabled != null) 'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BudgetsCompanion copyWith(
      {Value<int>? id,
      Value<String?>? syncId,
      Value<int>? ledgerId,
      Value<String>? type,
      Value<int?>? categoryId,
      Value<double>? amount,
      Value<String>? period,
      Value<int>? startDay,
      Value<bool>? enabled,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return BudgetsCompanion(
      id: id ?? this.id,
      syncId: syncId ?? this.syncId,
      ledgerId: ledgerId ?? this.ledgerId,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      startDay: startDay ?? this.startDay,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<int>(ledgerId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (period.present) {
      map['period'] = Variable<String>(period.value);
    }
    if (startDay.present) {
      map['start_day'] = Variable<int>(startDay.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetsCompanion(')
          ..write('id: $id, ')
          ..write('syncId: $syncId, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('type: $type, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('period: $period, ')
          ..write('startDay: $startDay, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TransactionAttachmentsTable extends TransactionAttachments
    with TableInfo<$TransactionAttachmentsTable, TransactionAttachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionAttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _transactionIdMeta =
      const VerificationMeta('transactionId');
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
      'transaction_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _fileNameMeta =
      const VerificationMeta('fileName');
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
      'file_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _originKeyMeta =
      const VerificationMeta('originKey');
  @override
  late final GeneratedColumn<String> originKey = GeneratedColumn<String>(
      'origin_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _originalNameMeta =
      const VerificationMeta('originalName');
  @override
  late final GeneratedColumn<String> originalName = GeneratedColumn<String>(
      'original_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fileSizeMeta =
      const VerificationMeta('fileSize');
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
      'file_size', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
      'width', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
      'height', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _cloudFileIdMeta =
      const VerificationMeta('cloudFileId');
  @override
  late final GeneratedColumn<String> cloudFileId = GeneratedColumn<String>(
      'cloud_file_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cloudSha256Meta =
      const VerificationMeta('cloudSha256');
  @override
  late final GeneratedColumn<String> cloudSha256 = GeneratedColumn<String>(
      'cloud_sha256', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        transactionId,
        fileName,
        originKey,
        originalName,
        fileSize,
        width,
        height,
        sortOrder,
        cloudFileId,
        cloudSha256,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transaction_attachments';
  @override
  VerificationContext validateIntegrity(
      Insertable<TransactionAttachment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
          _transactionIdMeta,
          transactionId.isAcceptableOrUnknown(
              data['transaction_id']!, _transactionIdMeta));
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(_fileNameMeta,
          fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta));
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('origin_key')) {
      context.handle(_originKeyMeta,
          originKey.isAcceptableOrUnknown(data['origin_key']!, _originKeyMeta));
    }
    if (data.containsKey('original_name')) {
      context.handle(
          _originalNameMeta,
          originalName.isAcceptableOrUnknown(
              data['original_name']!, _originalNameMeta));
    }
    if (data.containsKey('file_size')) {
      context.handle(_fileSizeMeta,
          fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta));
    }
    if (data.containsKey('width')) {
      context.handle(
          _widthMeta, width.isAcceptableOrUnknown(data['width']!, _widthMeta));
    }
    if (data.containsKey('height')) {
      context.handle(_heightMeta,
          height.isAcceptableOrUnknown(data['height']!, _heightMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('cloud_file_id')) {
      context.handle(
          _cloudFileIdMeta,
          cloudFileId.isAcceptableOrUnknown(
              data['cloud_file_id']!, _cloudFileIdMeta));
    }
    if (data.containsKey('cloud_sha256')) {
      context.handle(
          _cloudSha256Meta,
          cloudSha256.isAcceptableOrUnknown(
              data['cloud_sha256']!, _cloudSha256Meta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionAttachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionAttachment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      transactionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}transaction_id'])!,
      fileName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_name'])!,
      originKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}origin_key']),
      originalName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}original_name']),
      fileSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}file_size']),
      width: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}width']),
      height: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}height']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      cloudFileId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cloud_file_id']),
      cloudSha256: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cloud_sha256']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $TransactionAttachmentsTable createAlias(String alias) {
    return $TransactionAttachmentsTable(attachedDatabase, alias);
  }
}

class TransactionAttachment extends DataClass
    implements Insertable<TransactionAttachment> {
  final int id;
  final int transactionId;
  final String fileName;
  final String? originKey;
  final String? originalName;
  final int? fileSize;
  final int? width;
  final int? height;
  final int sortOrder;
  final String? cloudFileId;
  final String? cloudSha256;
  final DateTime createdAt;
  const TransactionAttachment(
      {required this.id,
      required this.transactionId,
      required this.fileName,
      this.originKey,
      this.originalName,
      this.fileSize,
      this.width,
      this.height,
      required this.sortOrder,
      this.cloudFileId,
      this.cloudSha256,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['transaction_id'] = Variable<int>(transactionId);
    map['file_name'] = Variable<String>(fileName);
    if (!nullToAbsent || originKey != null) {
      map['origin_key'] = Variable<String>(originKey);
    }
    if (!nullToAbsent || originalName != null) {
      map['original_name'] = Variable<String>(originalName);
    }
    if (!nullToAbsent || fileSize != null) {
      map['file_size'] = Variable<int>(fileSize);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || cloudFileId != null) {
      map['cloud_file_id'] = Variable<String>(cloudFileId);
    }
    if (!nullToAbsent || cloudSha256 != null) {
      map['cloud_sha256'] = Variable<String>(cloudSha256);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TransactionAttachmentsCompanion toCompanion(bool nullToAbsent) {
    return TransactionAttachmentsCompanion(
      id: Value(id),
      transactionId: Value(transactionId),
      fileName: Value(fileName),
      originKey: originKey == null && nullToAbsent
          ? const Value.absent()
          : Value(originKey),
      originalName: originalName == null && nullToAbsent
          ? const Value.absent()
          : Value(originalName),
      fileSize: fileSize == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSize),
      width:
          width == null && nullToAbsent ? const Value.absent() : Value(width),
      height:
          height == null && nullToAbsent ? const Value.absent() : Value(height),
      sortOrder: Value(sortOrder),
      cloudFileId: cloudFileId == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudFileId),
      cloudSha256: cloudSha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudSha256),
      createdAt: Value(createdAt),
    );
  }

  factory TransactionAttachment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionAttachment(
      id: serializer.fromJson<int>(json['id']),
      transactionId: serializer.fromJson<int>(json['transactionId']),
      fileName: serializer.fromJson<String>(json['fileName']),
      originKey: serializer.fromJson<String?>(json['originKey']),
      originalName: serializer.fromJson<String?>(json['originalName']),
      fileSize: serializer.fromJson<int?>(json['fileSize']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      cloudFileId: serializer.fromJson<String?>(json['cloudFileId']),
      cloudSha256: serializer.fromJson<String?>(json['cloudSha256']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'transactionId': serializer.toJson<int>(transactionId),
      'fileName': serializer.toJson<String>(fileName),
      'originKey': serializer.toJson<String?>(originKey),
      'originalName': serializer.toJson<String?>(originalName),
      'fileSize': serializer.toJson<int?>(fileSize),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'cloudFileId': serializer.toJson<String?>(cloudFileId),
      'cloudSha256': serializer.toJson<String?>(cloudSha256),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TransactionAttachment copyWith(
          {int? id,
          int? transactionId,
          String? fileName,
          Value<String?> originKey = const Value.absent(),
          Value<String?> originalName = const Value.absent(),
          Value<int?> fileSize = const Value.absent(),
          Value<int?> width = const Value.absent(),
          Value<int?> height = const Value.absent(),
          int? sortOrder,
          Value<String?> cloudFileId = const Value.absent(),
          Value<String?> cloudSha256 = const Value.absent(),
          DateTime? createdAt}) =>
      TransactionAttachment(
        id: id ?? this.id,
        transactionId: transactionId ?? this.transactionId,
        fileName: fileName ?? this.fileName,
        originKey: originKey.present ? originKey.value : this.originKey,
        originalName:
            originalName.present ? originalName.value : this.originalName,
        fileSize: fileSize.present ? fileSize.value : this.fileSize,
        width: width.present ? width.value : this.width,
        height: height.present ? height.value : this.height,
        sortOrder: sortOrder ?? this.sortOrder,
        cloudFileId: cloudFileId.present ? cloudFileId.value : this.cloudFileId,
        cloudSha256: cloudSha256.present ? cloudSha256.value : this.cloudSha256,
        createdAt: createdAt ?? this.createdAt,
      );
  TransactionAttachment copyWithCompanion(
      TransactionAttachmentsCompanion data) {
    return TransactionAttachment(
      id: data.id.present ? data.id.value : this.id,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      originKey: data.originKey.present ? data.originKey.value : this.originKey,
      originalName: data.originalName.present
          ? data.originalName.value
          : this.originalName,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      cloudFileId:
          data.cloudFileId.present ? data.cloudFileId.value : this.cloudFileId,
      cloudSha256:
          data.cloudSha256.present ? data.cloudSha256.value : this.cloudSha256,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionAttachment(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('fileName: $fileName, ')
          ..write('originKey: $originKey, ')
          ..write('originalName: $originalName, ')
          ..write('fileSize: $fileSize, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('cloudFileId: $cloudFileId, ')
          ..write('cloudSha256: $cloudSha256, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      transactionId,
      fileName,
      originKey,
      originalName,
      fileSize,
      width,
      height,
      sortOrder,
      cloudFileId,
      cloudSha256,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionAttachment &&
          other.id == this.id &&
          other.transactionId == this.transactionId &&
          other.fileName == this.fileName &&
          other.originKey == this.originKey &&
          other.originalName == this.originalName &&
          other.fileSize == this.fileSize &&
          other.width == this.width &&
          other.height == this.height &&
          other.sortOrder == this.sortOrder &&
          other.cloudFileId == this.cloudFileId &&
          other.cloudSha256 == this.cloudSha256 &&
          other.createdAt == this.createdAt);
}

class TransactionAttachmentsCompanion
    extends UpdateCompanion<TransactionAttachment> {
  final Value<int> id;
  final Value<int> transactionId;
  final Value<String> fileName;
  final Value<String?> originKey;
  final Value<String?> originalName;
  final Value<int?> fileSize;
  final Value<int?> width;
  final Value<int?> height;
  final Value<int> sortOrder;
  final Value<String?> cloudFileId;
  final Value<String?> cloudSha256;
  final Value<DateTime> createdAt;
  const TransactionAttachmentsCompanion({
    this.id = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.fileName = const Value.absent(),
    this.originKey = const Value.absent(),
    this.originalName = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.cloudFileId = const Value.absent(),
    this.cloudSha256 = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TransactionAttachmentsCompanion.insert({
    this.id = const Value.absent(),
    required int transactionId,
    required String fileName,
    this.originKey = const Value.absent(),
    this.originalName = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.cloudFileId = const Value.absent(),
    this.cloudSha256 = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : transactionId = Value(transactionId),
        fileName = Value(fileName);
  static Insertable<TransactionAttachment> custom({
    Expression<int>? id,
    Expression<int>? transactionId,
    Expression<String>? fileName,
    Expression<String>? originKey,
    Expression<String>? originalName,
    Expression<int>? fileSize,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? sortOrder,
    Expression<String>? cloudFileId,
    Expression<String>? cloudSha256,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transactionId != null) 'transaction_id': transactionId,
      if (fileName != null) 'file_name': fileName,
      if (originKey != null) 'origin_key': originKey,
      if (originalName != null) 'original_name': originalName,
      if (fileSize != null) 'file_size': fileSize,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (cloudFileId != null) 'cloud_file_id': cloudFileId,
      if (cloudSha256 != null) 'cloud_sha256': cloudSha256,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TransactionAttachmentsCompanion copyWith(
      {Value<int>? id,
      Value<int>? transactionId,
      Value<String>? fileName,
      Value<String?>? originKey,
      Value<String?>? originalName,
      Value<int?>? fileSize,
      Value<int?>? width,
      Value<int?>? height,
      Value<int>? sortOrder,
      Value<String?>? cloudFileId,
      Value<String?>? cloudSha256,
      Value<DateTime>? createdAt}) {
    return TransactionAttachmentsCompanion(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      fileName: fileName ?? this.fileName,
      originKey: originKey ?? this.originKey,
      originalName: originalName ?? this.originalName,
      fileSize: fileSize ?? this.fileSize,
      width: width ?? this.width,
      height: height ?? this.height,
      sortOrder: sortOrder ?? this.sortOrder,
      cloudFileId: cloudFileId ?? this.cloudFileId,
      cloudSha256: cloudSha256 ?? this.cloudSha256,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (originKey.present) {
      map['origin_key'] = Variable<String>(originKey.value);
    }
    if (originalName.present) {
      map['original_name'] = Variable<String>(originalName.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (cloudFileId.present) {
      map['cloud_file_id'] = Variable<String>(cloudFileId.value);
    }
    if (cloudSha256.present) {
      map['cloud_sha256'] = Variable<String>(cloudSha256.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionAttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('fileName: $fileName, ')
          ..write('originKey: $originKey, ')
          ..write('originalName: $originalName, ')
          ..write('fileSize: $fileSize, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('cloudFileId: $cloudFileId, ')
          ..write('cloudSha256: $cloudSha256, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $LocalChangesTable extends LocalChanges
    with TableInfo<$LocalChangesTable, LocalChange> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalChangesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<int> entityId = GeneratedColumn<int>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _entitySyncIdMeta =
      const VerificationMeta('entitySyncId');
  @override
  late final GeneratedColumn<String> entitySyncId = GeneratedColumn<String>(
      'entity_sync_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ledgerIdMeta =
      const VerificationMeta('ledgerId');
  @override
  late final GeneratedColumn<int> ledgerId = GeneratedColumn<int>(
      'ledger_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
      'action', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _pushedAtMeta =
      const VerificationMeta('pushedAt');
  @override
  late final GeneratedColumn<DateTime> pushedAt = GeneratedColumn<DateTime>(
      'pushed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        entityType,
        entityId,
        entitySyncId,
        ledgerId,
        action,
        payloadJson,
        createdAt,
        pushedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_changes';
  @override
  VerificationContext validateIntegrity(Insertable<LocalChange> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('entity_sync_id')) {
      context.handle(
          _entitySyncIdMeta,
          entitySyncId.isAcceptableOrUnknown(
              data['entity_sync_id']!, _entitySyncIdMeta));
    } else if (isInserting) {
      context.missing(_entitySyncIdMeta);
    }
    if (data.containsKey('ledger_id')) {
      context.handle(_ledgerIdMeta,
          ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta));
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(_actionMeta,
          action.isAcceptableOrUnknown(data['action']!, _actionMeta));
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('pushed_at')) {
      context.handle(_pushedAtMeta,
          pushedAt.isAcceptableOrUnknown(data['pushed_at']!, _pushedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalChange map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalChange(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}entity_id'])!,
      entitySyncId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_sync_id'])!,
      ledgerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ledger_id'])!,
      action: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      pushedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}pushed_at']),
    );
  }

  @override
  $LocalChangesTable createAlias(String alias) {
    return $LocalChangesTable(attachedDatabase, alias);
  }
}

class LocalChange extends DataClass implements Insertable<LocalChange> {
  final int id;
  final String entityType;
  final int entityId;
  final String entitySyncId;
  final int ledgerId;
  final String action;
  final String? payloadJson;
  final DateTime createdAt;
  final DateTime? pushedAt;
  const LocalChange(
      {required this.id,
      required this.entityType,
      required this.entityId,
      required this.entitySyncId,
      required this.ledgerId,
      required this.action,
      this.payloadJson,
      required this.createdAt,
      this.pushedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<int>(entityId);
    map['entity_sync_id'] = Variable<String>(entitySyncId);
    map['ledger_id'] = Variable<int>(ledgerId);
    map['action'] = Variable<String>(action);
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || pushedAt != null) {
      map['pushed_at'] = Variable<DateTime>(pushedAt);
    }
    return map;
  }

  LocalChangesCompanion toCompanion(bool nullToAbsent) {
    return LocalChangesCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      entitySyncId: Value(entitySyncId),
      ledgerId: Value(ledgerId),
      action: Value(action),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
      createdAt: Value(createdAt),
      pushedAt: pushedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(pushedAt),
    );
  }

  factory LocalChange.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalChange(
      id: serializer.fromJson<int>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<int>(json['entityId']),
      entitySyncId: serializer.fromJson<String>(json['entitySyncId']),
      ledgerId: serializer.fromJson<int>(json['ledgerId']),
      action: serializer.fromJson<String>(json['action']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      pushedAt: serializer.fromJson<DateTime?>(json['pushedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<int>(entityId),
      'entitySyncId': serializer.toJson<String>(entitySyncId),
      'ledgerId': serializer.toJson<int>(ledgerId),
      'action': serializer.toJson<String>(action),
      'payloadJson': serializer.toJson<String?>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'pushedAt': serializer.toJson<DateTime?>(pushedAt),
    };
  }

  LocalChange copyWith(
          {int? id,
          String? entityType,
          int? entityId,
          String? entitySyncId,
          int? ledgerId,
          String? action,
          Value<String?> payloadJson = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> pushedAt = const Value.absent()}) =>
      LocalChange(
        id: id ?? this.id,
        entityType: entityType ?? this.entityType,
        entityId: entityId ?? this.entityId,
        entitySyncId: entitySyncId ?? this.entitySyncId,
        ledgerId: ledgerId ?? this.ledgerId,
        action: action ?? this.action,
        payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
        createdAt: createdAt ?? this.createdAt,
        pushedAt: pushedAt.present ? pushedAt.value : this.pushedAt,
      );
  LocalChange copyWithCompanion(LocalChangesCompanion data) {
    return LocalChange(
      id: data.id.present ? data.id.value : this.id,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      entitySyncId: data.entitySyncId.present
          ? data.entitySyncId.value
          : this.entitySyncId,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      action: data.action.present ? data.action.value : this.action,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      pushedAt: data.pushedAt.present ? data.pushedAt.value : this.pushedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalChange(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('entitySyncId: $entitySyncId, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('action: $action, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('pushedAt: $pushedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, entityType, entityId, entitySyncId,
      ledgerId, action, payloadJson, createdAt, pushedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalChange &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.entitySyncId == this.entitySyncId &&
          other.ledgerId == this.ledgerId &&
          other.action == this.action &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt &&
          other.pushedAt == this.pushedAt);
}

class LocalChangesCompanion extends UpdateCompanion<LocalChange> {
  final Value<int> id;
  final Value<String> entityType;
  final Value<int> entityId;
  final Value<String> entitySyncId;
  final Value<int> ledgerId;
  final Value<String> action;
  final Value<String?> payloadJson;
  final Value<DateTime> createdAt;
  final Value<DateTime?> pushedAt;
  const LocalChangesCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.entitySyncId = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.action = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.pushedAt = const Value.absent(),
  });
  LocalChangesCompanion.insert({
    this.id = const Value.absent(),
    required String entityType,
    required int entityId,
    required String entitySyncId,
    required int ledgerId,
    required String action,
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.pushedAt = const Value.absent(),
  })  : entityType = Value(entityType),
        entityId = Value(entityId),
        entitySyncId = Value(entitySyncId),
        ledgerId = Value(ledgerId),
        action = Value(action);
  static Insertable<LocalChange> custom({
    Expression<int>? id,
    Expression<String>? entityType,
    Expression<int>? entityId,
    Expression<String>? entitySyncId,
    Expression<int>? ledgerId,
    Expression<String>? action,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? pushedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (entitySyncId != null) 'entity_sync_id': entitySyncId,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (action != null) 'action': action,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (pushedAt != null) 'pushed_at': pushedAt,
    });
  }

  LocalChangesCompanion copyWith(
      {Value<int>? id,
      Value<String>? entityType,
      Value<int>? entityId,
      Value<String>? entitySyncId,
      Value<int>? ledgerId,
      Value<String>? action,
      Value<String?>? payloadJson,
      Value<DateTime>? createdAt,
      Value<DateTime?>? pushedAt}) {
    return LocalChangesCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      entitySyncId: entitySyncId ?? this.entitySyncId,
      ledgerId: ledgerId ?? this.ledgerId,
      action: action ?? this.action,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      pushedAt: pushedAt ?? this.pushedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<int>(entityId.value);
    }
    if (entitySyncId.present) {
      map['entity_sync_id'] = Variable<String>(entitySyncId.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<int>(ledgerId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (pushedAt.present) {
      map['pushed_at'] = Variable<DateTime>(pushedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalChangesCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('entitySyncId: $entitySyncId, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('action: $action, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('pushedAt: $pushedAt')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _providerTypeMeta =
      const VerificationMeta('providerType');
  @override
  late final GeneratedColumn<String> providerType = GeneratedColumn<String>(
      'provider_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('beecount_cloud'));
  static const VerificationMeta _serverCursorMeta =
      const VerificationMeta('serverCursor');
  @override
  late final GeneratedColumn<int> serverCursor = GeneratedColumn<int>(
      'server_cursor', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastPushAtMeta =
      const VerificationMeta('lastPushAt');
  @override
  late final GeneratedColumn<DateTime> lastPushAt = GeneratedColumn<DateTime>(
      'last_push_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastPullAtMeta =
      const VerificationMeta('lastPullAt');
  @override
  late final GeneratedColumn<DateTime> lastPullAt = GeneratedColumn<DateTime>(
      'last_pull_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, deviceId, providerType, serverCursor, lastPushAt, lastPullAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(Insertable<SyncStateData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('provider_type')) {
      context.handle(
          _providerTypeMeta,
          providerType.isAcceptableOrUnknown(
              data['provider_type']!, _providerTypeMeta));
    }
    if (data.containsKey('server_cursor')) {
      context.handle(
          _serverCursorMeta,
          serverCursor.isAcceptableOrUnknown(
              data['server_cursor']!, _serverCursorMeta));
    }
    if (data.containsKey('last_push_at')) {
      context.handle(
          _lastPushAtMeta,
          lastPushAt.isAcceptableOrUnknown(
              data['last_push_at']!, _lastPushAtMeta));
    }
    if (data.containsKey('last_pull_at')) {
      context.handle(
          _lastPullAtMeta,
          lastPullAt.isAcceptableOrUnknown(
              data['last_pull_at']!, _lastPullAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      providerType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider_type'])!,
      serverCursor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}server_cursor'])!,
      lastPushAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_push_at']),
      lastPullAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_pull_at']),
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  final int id;
  final String deviceId;
  final String providerType;
  final int serverCursor;
  final DateTime? lastPushAt;
  final DateTime? lastPullAt;
  const SyncStateData(
      {required this.id,
      required this.deviceId,
      required this.providerType,
      required this.serverCursor,
      this.lastPushAt,
      this.lastPullAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['provider_type'] = Variable<String>(providerType);
    map['server_cursor'] = Variable<int>(serverCursor);
    if (!nullToAbsent || lastPushAt != null) {
      map['last_push_at'] = Variable<DateTime>(lastPushAt);
    }
    if (!nullToAbsent || lastPullAt != null) {
      map['last_pull_at'] = Variable<DateTime>(lastPullAt);
    }
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      providerType: Value(providerType),
      serverCursor: Value(serverCursor),
      lastPushAt: lastPushAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPushAt),
      lastPullAt: lastPullAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPullAt),
    );
  }

  factory SyncStateData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
      id: serializer.fromJson<int>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      providerType: serializer.fromJson<String>(json['providerType']),
      serverCursor: serializer.fromJson<int>(json['serverCursor']),
      lastPushAt: serializer.fromJson<DateTime?>(json['lastPushAt']),
      lastPullAt: serializer.fromJson<DateTime?>(json['lastPullAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'providerType': serializer.toJson<String>(providerType),
      'serverCursor': serializer.toJson<int>(serverCursor),
      'lastPushAt': serializer.toJson<DateTime?>(lastPushAt),
      'lastPullAt': serializer.toJson<DateTime?>(lastPullAt),
    };
  }

  SyncStateData copyWith(
          {int? id,
          String? deviceId,
          String? providerType,
          int? serverCursor,
          Value<DateTime?> lastPushAt = const Value.absent(),
          Value<DateTime?> lastPullAt = const Value.absent()}) =>
      SyncStateData(
        id: id ?? this.id,
        deviceId: deviceId ?? this.deviceId,
        providerType: providerType ?? this.providerType,
        serverCursor: serverCursor ?? this.serverCursor,
        lastPushAt: lastPushAt.present ? lastPushAt.value : this.lastPushAt,
        lastPullAt: lastPullAt.present ? lastPullAt.value : this.lastPullAt,
      );
  SyncStateData copyWithCompanion(SyncStateCompanion data) {
    return SyncStateData(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      providerType: data.providerType.present
          ? data.providerType.value
          : this.providerType,
      serverCursor: data.serverCursor.present
          ? data.serverCursor.value
          : this.serverCursor,
      lastPushAt:
          data.lastPushAt.present ? data.lastPushAt.value : this.lastPushAt,
      lastPullAt:
          data.lastPullAt.present ? data.lastPullAt.value : this.lastPullAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('providerType: $providerType, ')
          ..write('serverCursor: $serverCursor, ')
          ..write('lastPushAt: $lastPushAt, ')
          ..write('lastPullAt: $lastPullAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, deviceId, providerType, serverCursor, lastPushAt, lastPullAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateData &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.providerType == this.providerType &&
          other.serverCursor == this.serverCursor &&
          other.lastPushAt == this.lastPushAt &&
          other.lastPullAt == this.lastPullAt);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateData> {
  final Value<int> id;
  final Value<String> deviceId;
  final Value<String> providerType;
  final Value<int> serverCursor;
  final Value<DateTime?> lastPushAt;
  final Value<DateTime?> lastPullAt;
  const SyncStateCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.providerType = const Value.absent(),
    this.serverCursor = const Value.absent(),
    this.lastPushAt = const Value.absent(),
    this.lastPullAt = const Value.absent(),
  });
  SyncStateCompanion.insert({
    this.id = const Value.absent(),
    required String deviceId,
    this.providerType = const Value.absent(),
    this.serverCursor = const Value.absent(),
    this.lastPushAt = const Value.absent(),
    this.lastPullAt = const Value.absent(),
  }) : deviceId = Value(deviceId);
  static Insertable<SyncStateData> custom({
    Expression<int>? id,
    Expression<String>? deviceId,
    Expression<String>? providerType,
    Expression<int>? serverCursor,
    Expression<DateTime>? lastPushAt,
    Expression<DateTime>? lastPullAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (providerType != null) 'provider_type': providerType,
      if (serverCursor != null) 'server_cursor': serverCursor,
      if (lastPushAt != null) 'last_push_at': lastPushAt,
      if (lastPullAt != null) 'last_pull_at': lastPullAt,
    });
  }

  SyncStateCompanion copyWith(
      {Value<int>? id,
      Value<String>? deviceId,
      Value<String>? providerType,
      Value<int>? serverCursor,
      Value<DateTime?>? lastPushAt,
      Value<DateTime?>? lastPullAt}) {
    return SyncStateCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      providerType: providerType ?? this.providerType,
      serverCursor: serverCursor ?? this.serverCursor,
      lastPushAt: lastPushAt ?? this.lastPushAt,
      lastPullAt: lastPullAt ?? this.lastPullAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (providerType.present) {
      map['provider_type'] = Variable<String>(providerType.value);
    }
    if (serverCursor.present) {
      map['server_cursor'] = Variable<int>(serverCursor.value);
    }
    if (lastPushAt.present) {
      map['last_push_at'] = Variable<DateTime>(lastPushAt.value);
    }
    if (lastPullAt.present) {
      map['last_pull_at'] = Variable<DateTime>(lastPullAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('providerType: $providerType, ')
          ..write('serverCursor: $serverCursor, ')
          ..write('lastPushAt: $lastPushAt, ')
          ..write('lastPullAt: $lastPullAt')
          ..write(')'))
        .toString();
  }
}

class $BillingJobsTable extends BillingJobs
    with TableInfo<$BillingJobsTable, BillingJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BillingJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _ledgerIdMeta =
      const VerificationMeta('ledgerId');
  @override
  late final GeneratedColumn<int> ledgerId = GeneratedColumn<int>(
      'ledger_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('image_share'));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<String> stage = GeneratedColumn<String>(
      'stage', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('received'));
  static const VerificationMeta _transactionIdMeta =
      const VerificationMeta('transactionId');
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
      'transaction_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _imagePathMeta =
      const VerificationMeta('imagePath');
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
      'image_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rawTextMeta =
      const VerificationMeta('rawText');
  @override
  late final GeneratedColumn<String> rawText = GeneratedColumn<String>(
      'raw_text', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _ocrEngineMeta =
      const VerificationMeta('ocrEngine');
  @override
  late final GeneratedColumn<String> ocrEngine = GeneratedColumn<String>(
      'ocr_engine', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceInfoJsonMeta =
      const VerificationMeta('sourceInfoJson');
  @override
  late final GeneratedColumn<String> sourceInfoJson = GeneratedColumn<String>(
      'source_info_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _ruleResultJsonMeta =
      const VerificationMeta('ruleResultJson');
  @override
  late final GeneratedColumn<String> ruleResultJson = GeneratedColumn<String>(
      'rule_result_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _rulePackageVersionMeta =
      const VerificationMeta('rulePackageVersion');
  @override
  late final GeneratedColumn<int> rulePackageVersion = GeneratedColumn<int>(
      'rule_package_version', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _rulesVersionMeta =
      const VerificationMeta('rulesVersion');
  @override
  late final GeneratedColumn<String> rulesVersion = GeneratedColumn<String>(
      'rules_version', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _normalizationVersionMeta =
      const VerificationMeta('normalizationVersion');
  @override
  late final GeneratedColumn<int> normalizationVersion = GeneratedColumn<int>(
      'normalization_version', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _personalRulesRevisionMeta =
      const VerificationMeta('personalRulesRevision');
  @override
  late final GeneratedColumn<int> personalRulesRevision = GeneratedColumn<int>(
      'personal_rules_revision', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _ruleSnapshotStatusMeta =
      const VerificationMeta('ruleSnapshotStatus');
  @override
  late final GeneratedColumn<String> ruleSnapshotStatus =
      GeneratedColumn<String>('rule_snapshot_status', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _finalResultJsonMeta =
      const VerificationMeta('finalResultJson');
  @override
  late final GeneratedColumn<String> finalResultJson = GeneratedColumn<String>(
      'final_result_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _attemptCountMeta =
      const VerificationMeta('attemptCount');
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
      'attempt_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _leaseUntilMeta =
      const VerificationMeta('leaseUntil');
  @override
  late final GeneratedColumn<DateTime> leaseUntil = GeneratedColumn<DateTime>(
      'lease_until', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _attachmentDoneMeta =
      const VerificationMeta('attachmentDone');
  @override
  late final GeneratedColumn<bool> attachmentDone = GeneratedColumn<bool>(
      'attachment_done', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("attachment_done" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        ledgerId,
        kind,
        status,
        stage,
        transactionId,
        imagePath,
        rawText,
        ocrEngine,
        sourceInfoJson,
        ruleResultJson,
        rulePackageVersion,
        rulesVersion,
        normalizationVersion,
        personalRulesRevision,
        ruleSnapshotStatus,
        finalResultJson,
        attemptCount,
        lastError,
        leaseUntil,
        attachmentDone,
        createdAt,
        updatedAt,
        completedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'billing_jobs';
  @override
  VerificationContext validateIntegrity(Insertable<BillingJob> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ledger_id')) {
      context.handle(_ledgerIdMeta,
          ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('stage')) {
      context.handle(
          _stageMeta, stage.isAcceptableOrUnknown(data['stage']!, _stageMeta));
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
          _transactionIdMeta,
          transactionId.isAcceptableOrUnknown(
              data['transaction_id']!, _transactionIdMeta));
    }
    if (data.containsKey('image_path')) {
      context.handle(_imagePathMeta,
          imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta));
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('raw_text')) {
      context.handle(_rawTextMeta,
          rawText.isAcceptableOrUnknown(data['raw_text']!, _rawTextMeta));
    }
    if (data.containsKey('ocr_engine')) {
      context.handle(_ocrEngineMeta,
          ocrEngine.isAcceptableOrUnknown(data['ocr_engine']!, _ocrEngineMeta));
    }
    if (data.containsKey('source_info_json')) {
      context.handle(
          _sourceInfoJsonMeta,
          sourceInfoJson.isAcceptableOrUnknown(
              data['source_info_json']!, _sourceInfoJsonMeta));
    }
    if (data.containsKey('rule_result_json')) {
      context.handle(
          _ruleResultJsonMeta,
          ruleResultJson.isAcceptableOrUnknown(
              data['rule_result_json']!, _ruleResultJsonMeta));
    }
    if (data.containsKey('rule_package_version')) {
      context.handle(
          _rulePackageVersionMeta,
          rulePackageVersion.isAcceptableOrUnknown(
              data['rule_package_version']!, _rulePackageVersionMeta));
    }
    if (data.containsKey('rules_version')) {
      context.handle(
          _rulesVersionMeta,
          rulesVersion.isAcceptableOrUnknown(
              data['rules_version']!, _rulesVersionMeta));
    }
    if (data.containsKey('normalization_version')) {
      context.handle(
          _normalizationVersionMeta,
          normalizationVersion.isAcceptableOrUnknown(
              data['normalization_version']!, _normalizationVersionMeta));
    }
    if (data.containsKey('personal_rules_revision')) {
      context.handle(
          _personalRulesRevisionMeta,
          personalRulesRevision.isAcceptableOrUnknown(
              data['personal_rules_revision']!, _personalRulesRevisionMeta));
    }
    if (data.containsKey('rule_snapshot_status')) {
      context.handle(
          _ruleSnapshotStatusMeta,
          ruleSnapshotStatus.isAcceptableOrUnknown(
              data['rule_snapshot_status']!, _ruleSnapshotStatusMeta));
    }
    if (data.containsKey('final_result_json')) {
      context.handle(
          _finalResultJsonMeta,
          finalResultJson.isAcceptableOrUnknown(
              data['final_result_json']!, _finalResultJsonMeta));
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
          _attemptCountMeta,
          attemptCount.isAcceptableOrUnknown(
              data['attempt_count']!, _attemptCountMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('lease_until')) {
      context.handle(
          _leaseUntilMeta,
          leaseUntil.isAcceptableOrUnknown(
              data['lease_until']!, _leaseUntilMeta));
    }
    if (data.containsKey('attachment_done')) {
      context.handle(
          _attachmentDoneMeta,
          attachmentDone.isAcceptableOrUnknown(
              data['attachment_done']!, _attachmentDoneMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BillingJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BillingJob(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      ledgerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ledger_id']),
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      stage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stage'])!,
      transactionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}transaction_id']),
      imagePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_path'])!,
      rawText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}raw_text']),
      ocrEngine: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ocr_engine']),
      sourceInfoJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}source_info_json']),
      ruleResultJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}rule_result_json']),
      rulePackageVersion: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}rule_package_version']),
      rulesVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rules_version']),
      normalizationVersion: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}normalization_version']),
      personalRulesRevision: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}personal_rules_revision']),
      ruleSnapshotStatus: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}rule_snapshot_status']),
      finalResultJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}final_result_json']),
      attemptCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempt_count'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      leaseUntil: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}lease_until']),
      attachmentDone: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}attachment_done'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at']),
    );
  }

  @override
  $BillingJobsTable createAlias(String alias) {
    return $BillingJobsTable(attachedDatabase, alias);
  }
}

class BillingJob extends DataClass implements Insertable<BillingJob> {
  final int id;
  final int? ledgerId;
  final String kind;
  final String status;
  final String stage;
  final int? transactionId;
  final String imagePath;
  final String? rawText;
  final String? ocrEngine;
  final String? sourceInfoJson;
  final String? ruleResultJson;
  final int? rulePackageVersion;
  final String? rulesVersion;
  final int? normalizationVersion;
  final int? personalRulesRevision;
  final String? ruleSnapshotStatus;
  final String? finalResultJson;
  final int attemptCount;
  final String? lastError;
  final DateTime? leaseUntil;
  final bool attachmentDone;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  const BillingJob(
      {required this.id,
      this.ledgerId,
      required this.kind,
      required this.status,
      required this.stage,
      this.transactionId,
      required this.imagePath,
      this.rawText,
      this.ocrEngine,
      this.sourceInfoJson,
      this.ruleResultJson,
      this.rulePackageVersion,
      this.rulesVersion,
      this.normalizationVersion,
      this.personalRulesRevision,
      this.ruleSnapshotStatus,
      this.finalResultJson,
      required this.attemptCount,
      this.lastError,
      this.leaseUntil,
      required this.attachmentDone,
      required this.createdAt,
      required this.updatedAt,
      this.completedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || ledgerId != null) {
      map['ledger_id'] = Variable<int>(ledgerId);
    }
    map['kind'] = Variable<String>(kind);
    map['status'] = Variable<String>(status);
    map['stage'] = Variable<String>(stage);
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<int>(transactionId);
    }
    map['image_path'] = Variable<String>(imagePath);
    if (!nullToAbsent || rawText != null) {
      map['raw_text'] = Variable<String>(rawText);
    }
    if (!nullToAbsent || ocrEngine != null) {
      map['ocr_engine'] = Variable<String>(ocrEngine);
    }
    if (!nullToAbsent || sourceInfoJson != null) {
      map['source_info_json'] = Variable<String>(sourceInfoJson);
    }
    if (!nullToAbsent || ruleResultJson != null) {
      map['rule_result_json'] = Variable<String>(ruleResultJson);
    }
    if (!nullToAbsent || rulePackageVersion != null) {
      map['rule_package_version'] = Variable<int>(rulePackageVersion);
    }
    if (!nullToAbsent || rulesVersion != null) {
      map['rules_version'] = Variable<String>(rulesVersion);
    }
    if (!nullToAbsent || normalizationVersion != null) {
      map['normalization_version'] = Variable<int>(normalizationVersion);
    }
    if (!nullToAbsent || personalRulesRevision != null) {
      map['personal_rules_revision'] = Variable<int>(personalRulesRevision);
    }
    if (!nullToAbsent || ruleSnapshotStatus != null) {
      map['rule_snapshot_status'] = Variable<String>(ruleSnapshotStatus);
    }
    if (!nullToAbsent || finalResultJson != null) {
      map['final_result_json'] = Variable<String>(finalResultJson);
    }
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || leaseUntil != null) {
      map['lease_until'] = Variable<DateTime>(leaseUntil);
    }
    map['attachment_done'] = Variable<bool>(attachmentDone);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  BillingJobsCompanion toCompanion(bool nullToAbsent) {
    return BillingJobsCompanion(
      id: Value(id),
      ledgerId: ledgerId == null && nullToAbsent
          ? const Value.absent()
          : Value(ledgerId),
      kind: Value(kind),
      status: Value(status),
      stage: Value(stage),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
      imagePath: Value(imagePath),
      rawText: rawText == null && nullToAbsent
          ? const Value.absent()
          : Value(rawText),
      ocrEngine: ocrEngine == null && nullToAbsent
          ? const Value.absent()
          : Value(ocrEngine),
      sourceInfoJson: sourceInfoJson == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceInfoJson),
      ruleResultJson: ruleResultJson == null && nullToAbsent
          ? const Value.absent()
          : Value(ruleResultJson),
      rulePackageVersion: rulePackageVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(rulePackageVersion),
      rulesVersion: rulesVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(rulesVersion),
      normalizationVersion: normalizationVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(normalizationVersion),
      personalRulesRevision: personalRulesRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(personalRulesRevision),
      ruleSnapshotStatus: ruleSnapshotStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(ruleSnapshotStatus),
      finalResultJson: finalResultJson == null && nullToAbsent
          ? const Value.absent()
          : Value(finalResultJson),
      attemptCount: Value(attemptCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      leaseUntil: leaseUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseUntil),
      attachmentDone: Value(attachmentDone),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory BillingJob.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BillingJob(
      id: serializer.fromJson<int>(json['id']),
      ledgerId: serializer.fromJson<int?>(json['ledgerId']),
      kind: serializer.fromJson<String>(json['kind']),
      status: serializer.fromJson<String>(json['status']),
      stage: serializer.fromJson<String>(json['stage']),
      transactionId: serializer.fromJson<int?>(json['transactionId']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      rawText: serializer.fromJson<String?>(json['rawText']),
      ocrEngine: serializer.fromJson<String?>(json['ocrEngine']),
      sourceInfoJson: serializer.fromJson<String?>(json['sourceInfoJson']),
      ruleResultJson: serializer.fromJson<String?>(json['ruleResultJson']),
      rulePackageVersion: serializer.fromJson<int?>(json['rulePackageVersion']),
      rulesVersion: serializer.fromJson<String?>(json['rulesVersion']),
      normalizationVersion:
          serializer.fromJson<int?>(json['normalizationVersion']),
      personalRulesRevision:
          serializer.fromJson<int?>(json['personalRulesRevision']),
      ruleSnapshotStatus:
          serializer.fromJson<String?>(json['ruleSnapshotStatus']),
      finalResultJson: serializer.fromJson<String?>(json['finalResultJson']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      leaseUntil: serializer.fromJson<DateTime?>(json['leaseUntil']),
      attachmentDone: serializer.fromJson<bool>(json['attachmentDone']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ledgerId': serializer.toJson<int?>(ledgerId),
      'kind': serializer.toJson<String>(kind),
      'status': serializer.toJson<String>(status),
      'stage': serializer.toJson<String>(stage),
      'transactionId': serializer.toJson<int?>(transactionId),
      'imagePath': serializer.toJson<String>(imagePath),
      'rawText': serializer.toJson<String?>(rawText),
      'ocrEngine': serializer.toJson<String?>(ocrEngine),
      'sourceInfoJson': serializer.toJson<String?>(sourceInfoJson),
      'ruleResultJson': serializer.toJson<String?>(ruleResultJson),
      'rulePackageVersion': serializer.toJson<int?>(rulePackageVersion),
      'rulesVersion': serializer.toJson<String?>(rulesVersion),
      'normalizationVersion': serializer.toJson<int?>(normalizationVersion),
      'personalRulesRevision': serializer.toJson<int?>(personalRulesRevision),
      'ruleSnapshotStatus': serializer.toJson<String?>(ruleSnapshotStatus),
      'finalResultJson': serializer.toJson<String?>(finalResultJson),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastError': serializer.toJson<String?>(lastError),
      'leaseUntil': serializer.toJson<DateTime?>(leaseUntil),
      'attachmentDone': serializer.toJson<bool>(attachmentDone),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  BillingJob copyWith(
          {int? id,
          Value<int?> ledgerId = const Value.absent(),
          String? kind,
          String? status,
          String? stage,
          Value<int?> transactionId = const Value.absent(),
          String? imagePath,
          Value<String?> rawText = const Value.absent(),
          Value<String?> ocrEngine = const Value.absent(),
          Value<String?> sourceInfoJson = const Value.absent(),
          Value<String?> ruleResultJson = const Value.absent(),
          Value<int?> rulePackageVersion = const Value.absent(),
          Value<String?> rulesVersion = const Value.absent(),
          Value<int?> normalizationVersion = const Value.absent(),
          Value<int?> personalRulesRevision = const Value.absent(),
          Value<String?> ruleSnapshotStatus = const Value.absent(),
          Value<String?> finalResultJson = const Value.absent(),
          int? attemptCount,
          Value<String?> lastError = const Value.absent(),
          Value<DateTime?> leaseUntil = const Value.absent(),
          bool? attachmentDone,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> completedAt = const Value.absent()}) =>
      BillingJob(
        id: id ?? this.id,
        ledgerId: ledgerId.present ? ledgerId.value : this.ledgerId,
        kind: kind ?? this.kind,
        status: status ?? this.status,
        stage: stage ?? this.stage,
        transactionId:
            transactionId.present ? transactionId.value : this.transactionId,
        imagePath: imagePath ?? this.imagePath,
        rawText: rawText.present ? rawText.value : this.rawText,
        ocrEngine: ocrEngine.present ? ocrEngine.value : this.ocrEngine,
        sourceInfoJson:
            sourceInfoJson.present ? sourceInfoJson.value : this.sourceInfoJson,
        ruleResultJson:
            ruleResultJson.present ? ruleResultJson.value : this.ruleResultJson,
        rulePackageVersion: rulePackageVersion.present
            ? rulePackageVersion.value
            : this.rulePackageVersion,
        rulesVersion:
            rulesVersion.present ? rulesVersion.value : this.rulesVersion,
        normalizationVersion: normalizationVersion.present
            ? normalizationVersion.value
            : this.normalizationVersion,
        personalRulesRevision: personalRulesRevision.present
            ? personalRulesRevision.value
            : this.personalRulesRevision,
        ruleSnapshotStatus: ruleSnapshotStatus.present
            ? ruleSnapshotStatus.value
            : this.ruleSnapshotStatus,
        finalResultJson: finalResultJson.present
            ? finalResultJson.value
            : this.finalResultJson,
        attemptCount: attemptCount ?? this.attemptCount,
        lastError: lastError.present ? lastError.value : this.lastError,
        leaseUntil: leaseUntil.present ? leaseUntil.value : this.leaseUntil,
        attachmentDone: attachmentDone ?? this.attachmentDone,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
      );
  BillingJob copyWithCompanion(BillingJobsCompanion data) {
    return BillingJob(
      id: data.id.present ? data.id.value : this.id,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      kind: data.kind.present ? data.kind.value : this.kind,
      status: data.status.present ? data.status.value : this.status,
      stage: data.stage.present ? data.stage.value : this.stage,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      rawText: data.rawText.present ? data.rawText.value : this.rawText,
      ocrEngine: data.ocrEngine.present ? data.ocrEngine.value : this.ocrEngine,
      sourceInfoJson: data.sourceInfoJson.present
          ? data.sourceInfoJson.value
          : this.sourceInfoJson,
      ruleResultJson: data.ruleResultJson.present
          ? data.ruleResultJson.value
          : this.ruleResultJson,
      rulePackageVersion: data.rulePackageVersion.present
          ? data.rulePackageVersion.value
          : this.rulePackageVersion,
      rulesVersion: data.rulesVersion.present
          ? data.rulesVersion.value
          : this.rulesVersion,
      normalizationVersion: data.normalizationVersion.present
          ? data.normalizationVersion.value
          : this.normalizationVersion,
      personalRulesRevision: data.personalRulesRevision.present
          ? data.personalRulesRevision.value
          : this.personalRulesRevision,
      ruleSnapshotStatus: data.ruleSnapshotStatus.present
          ? data.ruleSnapshotStatus.value
          : this.ruleSnapshotStatus,
      finalResultJson: data.finalResultJson.present
          ? data.finalResultJson.value
          : this.finalResultJson,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      leaseUntil:
          data.leaseUntil.present ? data.leaseUntil.value : this.leaseUntil,
      attachmentDone: data.attachmentDone.present
          ? data.attachmentDone.value
          : this.attachmentDone,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BillingJob(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('stage: $stage, ')
          ..write('transactionId: $transactionId, ')
          ..write('imagePath: $imagePath, ')
          ..write('rawText: $rawText, ')
          ..write('ocrEngine: $ocrEngine, ')
          ..write('sourceInfoJson: $sourceInfoJson, ')
          ..write('ruleResultJson: $ruleResultJson, ')
          ..write('rulePackageVersion: $rulePackageVersion, ')
          ..write('rulesVersion: $rulesVersion, ')
          ..write('normalizationVersion: $normalizationVersion, ')
          ..write('personalRulesRevision: $personalRulesRevision, ')
          ..write('ruleSnapshotStatus: $ruleSnapshotStatus, ')
          ..write('finalResultJson: $finalResultJson, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('attachmentDone: $attachmentDone, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        ledgerId,
        kind,
        status,
        stage,
        transactionId,
        imagePath,
        rawText,
        ocrEngine,
        sourceInfoJson,
        ruleResultJson,
        rulePackageVersion,
        rulesVersion,
        normalizationVersion,
        personalRulesRevision,
        ruleSnapshotStatus,
        finalResultJson,
        attemptCount,
        lastError,
        leaseUntil,
        attachmentDone,
        createdAt,
        updatedAt,
        completedAt
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BillingJob &&
          other.id == this.id &&
          other.ledgerId == this.ledgerId &&
          other.kind == this.kind &&
          other.status == this.status &&
          other.stage == this.stage &&
          other.transactionId == this.transactionId &&
          other.imagePath == this.imagePath &&
          other.rawText == this.rawText &&
          other.ocrEngine == this.ocrEngine &&
          other.sourceInfoJson == this.sourceInfoJson &&
          other.ruleResultJson == this.ruleResultJson &&
          other.rulePackageVersion == this.rulePackageVersion &&
          other.rulesVersion == this.rulesVersion &&
          other.normalizationVersion == this.normalizationVersion &&
          other.personalRulesRevision == this.personalRulesRevision &&
          other.ruleSnapshotStatus == this.ruleSnapshotStatus &&
          other.finalResultJson == this.finalResultJson &&
          other.attemptCount == this.attemptCount &&
          other.lastError == this.lastError &&
          other.leaseUntil == this.leaseUntil &&
          other.attachmentDone == this.attachmentDone &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt);
}

class BillingJobsCompanion extends UpdateCompanion<BillingJob> {
  final Value<int> id;
  final Value<int?> ledgerId;
  final Value<String> kind;
  final Value<String> status;
  final Value<String> stage;
  final Value<int?> transactionId;
  final Value<String> imagePath;
  final Value<String?> rawText;
  final Value<String?> ocrEngine;
  final Value<String?> sourceInfoJson;
  final Value<String?> ruleResultJson;
  final Value<int?> rulePackageVersion;
  final Value<String?> rulesVersion;
  final Value<int?> normalizationVersion;
  final Value<int?> personalRulesRevision;
  final Value<String?> ruleSnapshotStatus;
  final Value<String?> finalResultJson;
  final Value<int> attemptCount;
  final Value<String?> lastError;
  final Value<DateTime?> leaseUntil;
  final Value<bool> attachmentDone;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> completedAt;
  const BillingJobsCompanion({
    this.id = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.kind = const Value.absent(),
    this.status = const Value.absent(),
    this.stage = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.rawText = const Value.absent(),
    this.ocrEngine = const Value.absent(),
    this.sourceInfoJson = const Value.absent(),
    this.ruleResultJson = const Value.absent(),
    this.rulePackageVersion = const Value.absent(),
    this.rulesVersion = const Value.absent(),
    this.normalizationVersion = const Value.absent(),
    this.personalRulesRevision = const Value.absent(),
    this.ruleSnapshotStatus = const Value.absent(),
    this.finalResultJson = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.attachmentDone = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  BillingJobsCompanion.insert({
    this.id = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.kind = const Value.absent(),
    this.status = const Value.absent(),
    this.stage = const Value.absent(),
    this.transactionId = const Value.absent(),
    required String imagePath,
    this.rawText = const Value.absent(),
    this.ocrEngine = const Value.absent(),
    this.sourceInfoJson = const Value.absent(),
    this.ruleResultJson = const Value.absent(),
    this.rulePackageVersion = const Value.absent(),
    this.rulesVersion = const Value.absent(),
    this.normalizationVersion = const Value.absent(),
    this.personalRulesRevision = const Value.absent(),
    this.ruleSnapshotStatus = const Value.absent(),
    this.finalResultJson = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.attachmentDone = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  }) : imagePath = Value(imagePath);
  static Insertable<BillingJob> custom({
    Expression<int>? id,
    Expression<int>? ledgerId,
    Expression<String>? kind,
    Expression<String>? status,
    Expression<String>? stage,
    Expression<int>? transactionId,
    Expression<String>? imagePath,
    Expression<String>? rawText,
    Expression<String>? ocrEngine,
    Expression<String>? sourceInfoJson,
    Expression<String>? ruleResultJson,
    Expression<int>? rulePackageVersion,
    Expression<String>? rulesVersion,
    Expression<int>? normalizationVersion,
    Expression<int>? personalRulesRevision,
    Expression<String>? ruleSnapshotStatus,
    Expression<String>? finalResultJson,
    Expression<int>? attemptCount,
    Expression<String>? lastError,
    Expression<DateTime>? leaseUntil,
    Expression<bool>? attachmentDone,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? completedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (kind != null) 'kind': kind,
      if (status != null) 'status': status,
      if (stage != null) 'stage': stage,
      if (transactionId != null) 'transaction_id': transactionId,
      if (imagePath != null) 'image_path': imagePath,
      if (rawText != null) 'raw_text': rawText,
      if (ocrEngine != null) 'ocr_engine': ocrEngine,
      if (sourceInfoJson != null) 'source_info_json': sourceInfoJson,
      if (ruleResultJson != null) 'rule_result_json': ruleResultJson,
      if (rulePackageVersion != null)
        'rule_package_version': rulePackageVersion,
      if (rulesVersion != null) 'rules_version': rulesVersion,
      if (normalizationVersion != null)
        'normalization_version': normalizationVersion,
      if (personalRulesRevision != null)
        'personal_rules_revision': personalRulesRevision,
      if (ruleSnapshotStatus != null)
        'rule_snapshot_status': ruleSnapshotStatus,
      if (finalResultJson != null) 'final_result_json': finalResultJson,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastError != null) 'last_error': lastError,
      if (leaseUntil != null) 'lease_until': leaseUntil,
      if (attachmentDone != null) 'attachment_done': attachmentDone,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  BillingJobsCompanion copyWith(
      {Value<int>? id,
      Value<int?>? ledgerId,
      Value<String>? kind,
      Value<String>? status,
      Value<String>? stage,
      Value<int?>? transactionId,
      Value<String>? imagePath,
      Value<String?>? rawText,
      Value<String?>? ocrEngine,
      Value<String?>? sourceInfoJson,
      Value<String?>? ruleResultJson,
      Value<int?>? rulePackageVersion,
      Value<String?>? rulesVersion,
      Value<int?>? normalizationVersion,
      Value<int?>? personalRulesRevision,
      Value<String?>? ruleSnapshotStatus,
      Value<String?>? finalResultJson,
      Value<int>? attemptCount,
      Value<String?>? lastError,
      Value<DateTime?>? leaseUntil,
      Value<bool>? attachmentDone,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? completedAt}) {
    return BillingJobsCompanion(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      stage: stage ?? this.stage,
      transactionId: transactionId ?? this.transactionId,
      imagePath: imagePath ?? this.imagePath,
      rawText: rawText ?? this.rawText,
      ocrEngine: ocrEngine ?? this.ocrEngine,
      sourceInfoJson: sourceInfoJson ?? this.sourceInfoJson,
      ruleResultJson: ruleResultJson ?? this.ruleResultJson,
      rulePackageVersion: rulePackageVersion ?? this.rulePackageVersion,
      rulesVersion: rulesVersion ?? this.rulesVersion,
      normalizationVersion: normalizationVersion ?? this.normalizationVersion,
      personalRulesRevision:
          personalRulesRevision ?? this.personalRulesRevision,
      ruleSnapshotStatus: ruleSnapshotStatus ?? this.ruleSnapshotStatus,
      finalResultJson: finalResultJson ?? this.finalResultJson,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      leaseUntil: leaseUntil ?? this.leaseUntil,
      attachmentDone: attachmentDone ?? this.attachmentDone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<int>(ledgerId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (stage.present) {
      map['stage'] = Variable<String>(stage.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (rawText.present) {
      map['raw_text'] = Variable<String>(rawText.value);
    }
    if (ocrEngine.present) {
      map['ocr_engine'] = Variable<String>(ocrEngine.value);
    }
    if (sourceInfoJson.present) {
      map['source_info_json'] = Variable<String>(sourceInfoJson.value);
    }
    if (ruleResultJson.present) {
      map['rule_result_json'] = Variable<String>(ruleResultJson.value);
    }
    if (rulePackageVersion.present) {
      map['rule_package_version'] = Variable<int>(rulePackageVersion.value);
    }
    if (rulesVersion.present) {
      map['rules_version'] = Variable<String>(rulesVersion.value);
    }
    if (normalizationVersion.present) {
      map['normalization_version'] = Variable<int>(normalizationVersion.value);
    }
    if (personalRulesRevision.present) {
      map['personal_rules_revision'] =
          Variable<int>(personalRulesRevision.value);
    }
    if (ruleSnapshotStatus.present) {
      map['rule_snapshot_status'] = Variable<String>(ruleSnapshotStatus.value);
    }
    if (finalResultJson.present) {
      map['final_result_json'] = Variable<String>(finalResultJson.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (leaseUntil.present) {
      map['lease_until'] = Variable<DateTime>(leaseUntil.value);
    }
    if (attachmentDone.present) {
      map['attachment_done'] = Variable<bool>(attachmentDone.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BillingJobsCompanion(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('stage: $stage, ')
          ..write('transactionId: $transactionId, ')
          ..write('imagePath: $imagePath, ')
          ..write('rawText: $rawText, ')
          ..write('ocrEngine: $ocrEngine, ')
          ..write('sourceInfoJson: $sourceInfoJson, ')
          ..write('ruleResultJson: $ruleResultJson, ')
          ..write('rulePackageVersion: $rulePackageVersion, ')
          ..write('rulesVersion: $rulesVersion, ')
          ..write('normalizationVersion: $normalizationVersion, ')
          ..write('personalRulesRevision: $personalRulesRevision, ')
          ..write('ruleSnapshotStatus: $ruleSnapshotStatus, ')
          ..write('finalResultJson: $finalResultJson, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('attachmentDone: $attachmentDone, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

class $BillingCasesTable extends BillingCases
    with TableInfo<$BillingCasesTable, BillingCase> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BillingCasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _requestIdMeta =
      const VerificationMeta('requestId');
  @override
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
      'request_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'UNIQUE NOT NULL');
  static const VerificationMeta _ledgerIdMeta =
      const VerificationMeta('ledgerId');
  @override
  late final GeneratedColumn<int> ledgerId = GeneratedColumn<int>(
      'ledger_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sourceImagePathMeta =
      const VerificationMeta('sourceImagePath');
  @override
  late final GeneratedColumn<String> sourceImagePath = GeneratedColumn<String>(
      'source_image_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceInfoJsonMeta =
      const VerificationMeta('sourceInfoJson');
  @override
  late final GeneratedColumn<String> sourceInfoJson = GeneratedColumn<String>(
      'source_info_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
      'state', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('accepted'));
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _encryptedOcrEvidenceMeta =
      const VerificationMeta('encryptedOcrEvidence');
  @override
  late final GeneratedColumn<String> encryptedOcrEvidence =
      GeneratedColumn<String>('encrypted_ocr_evidence', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _extractionResultJsonMeta =
      const VerificationMeta('extractionResultJson');
  @override
  late final GeneratedColumn<String> extractionResultJson =
      GeneratedColumn<String>('extraction_result_json', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _transactionIdMeta =
      const VerificationMeta('transactionId');
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
      'transaction_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _syncAllowedMeta =
      const VerificationMeta('syncAllowed');
  @override
  late final GeneratedColumn<bool> syncAllowed = GeneratedColumn<bool>(
      'sync_allowed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("sync_allowed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _evidencePurgeAfterMeta =
      const VerificationMeta('evidencePurgeAfter');
  @override
  late final GeneratedColumn<DateTime> evidencePurgeAfter =
      GeneratedColumn<DateTime>('evidence_purge_after', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _workflowDeleteAfterMeta =
      const VerificationMeta('workflowDeleteAfter');
  @override
  late final GeneratedColumn<DateTime> workflowDeleteAfter =
      GeneratedColumn<DateTime>('workflow_delete_after', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        requestId,
        ledgerId,
        sourceImagePath,
        sourceInfoJson,
        state,
        version,
        encryptedOcrEvidence,
        extractionResultJson,
        transactionId,
        syncAllowed,
        evidencePurgeAfter,
        workflowDeleteAfter,
        createdAt,
        updatedAt,
        completedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'billing_cases';
  @override
  VerificationContext validateIntegrity(Insertable<BillingCase> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('request_id')) {
      context.handle(_requestIdMeta,
          requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta));
    } else if (isInserting) {
      context.missing(_requestIdMeta);
    }
    if (data.containsKey('ledger_id')) {
      context.handle(_ledgerIdMeta,
          ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta));
    }
    if (data.containsKey('source_image_path')) {
      context.handle(
          _sourceImagePathMeta,
          sourceImagePath.isAcceptableOrUnknown(
              data['source_image_path']!, _sourceImagePathMeta));
    } else if (isInserting) {
      context.missing(_sourceImagePathMeta);
    }
    if (data.containsKey('source_info_json')) {
      context.handle(
          _sourceInfoJsonMeta,
          sourceInfoJson.isAcceptableOrUnknown(
              data['source_info_json']!, _sourceInfoJsonMeta));
    }
    if (data.containsKey('state')) {
      context.handle(
          _stateMeta, state.isAcceptableOrUnknown(data['state']!, _stateMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('encrypted_ocr_evidence')) {
      context.handle(
          _encryptedOcrEvidenceMeta,
          encryptedOcrEvidence.isAcceptableOrUnknown(
              data['encrypted_ocr_evidence']!, _encryptedOcrEvidenceMeta));
    }
    if (data.containsKey('extraction_result_json')) {
      context.handle(
          _extractionResultJsonMeta,
          extractionResultJson.isAcceptableOrUnknown(
              data['extraction_result_json']!, _extractionResultJsonMeta));
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
          _transactionIdMeta,
          transactionId.isAcceptableOrUnknown(
              data['transaction_id']!, _transactionIdMeta));
    }
    if (data.containsKey('sync_allowed')) {
      context.handle(
          _syncAllowedMeta,
          syncAllowed.isAcceptableOrUnknown(
              data['sync_allowed']!, _syncAllowedMeta));
    }
    if (data.containsKey('evidence_purge_after')) {
      context.handle(
          _evidencePurgeAfterMeta,
          evidencePurgeAfter.isAcceptableOrUnknown(
              data['evidence_purge_after']!, _evidencePurgeAfterMeta));
    }
    if (data.containsKey('workflow_delete_after')) {
      context.handle(
          _workflowDeleteAfterMeta,
          workflowDeleteAfter.isAcceptableOrUnknown(
              data['workflow_delete_after']!, _workflowDeleteAfterMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BillingCase map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BillingCase(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      requestId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}request_id'])!,
      ledgerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ledger_id']),
      sourceImagePath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}source_image_path'])!,
      sourceInfoJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}source_info_json']),
      state: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}state'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      encryptedOcrEvidence: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}encrypted_ocr_evidence']),
      extractionResultJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}extraction_result_json']),
      transactionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}transaction_id']),
      syncAllowed: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}sync_allowed'])!,
      evidencePurgeAfter: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}evidence_purge_after']),
      workflowDeleteAfter: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}workflow_delete_after']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at']),
    );
  }

  @override
  $BillingCasesTable createAlias(String alias) {
    return $BillingCasesTable(attachedDatabase, alias);
  }
}

class BillingCase extends DataClass implements Insertable<BillingCase> {
  final int id;
  final String requestId;
  final int? ledgerId;
  final String sourceImagePath;
  final String? sourceInfoJson;
  final String state;
  final int version;
  final String? encryptedOcrEvidence;
  final String? extractionResultJson;
  final int? transactionId;
  final bool syncAllowed;
  final DateTime? evidencePurgeAfter;
  final DateTime? workflowDeleteAfter;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  const BillingCase(
      {required this.id,
      required this.requestId,
      this.ledgerId,
      required this.sourceImagePath,
      this.sourceInfoJson,
      required this.state,
      required this.version,
      this.encryptedOcrEvidence,
      this.extractionResultJson,
      this.transactionId,
      required this.syncAllowed,
      this.evidencePurgeAfter,
      this.workflowDeleteAfter,
      required this.createdAt,
      required this.updatedAt,
      this.completedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['request_id'] = Variable<String>(requestId);
    if (!nullToAbsent || ledgerId != null) {
      map['ledger_id'] = Variable<int>(ledgerId);
    }
    map['source_image_path'] = Variable<String>(sourceImagePath);
    if (!nullToAbsent || sourceInfoJson != null) {
      map['source_info_json'] = Variable<String>(sourceInfoJson);
    }
    map['state'] = Variable<String>(state);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || encryptedOcrEvidence != null) {
      map['encrypted_ocr_evidence'] = Variable<String>(encryptedOcrEvidence);
    }
    if (!nullToAbsent || extractionResultJson != null) {
      map['extraction_result_json'] = Variable<String>(extractionResultJson);
    }
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<int>(transactionId);
    }
    map['sync_allowed'] = Variable<bool>(syncAllowed);
    if (!nullToAbsent || evidencePurgeAfter != null) {
      map['evidence_purge_after'] = Variable<DateTime>(evidencePurgeAfter);
    }
    if (!nullToAbsent || workflowDeleteAfter != null) {
      map['workflow_delete_after'] = Variable<DateTime>(workflowDeleteAfter);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  BillingCasesCompanion toCompanion(bool nullToAbsent) {
    return BillingCasesCompanion(
      id: Value(id),
      requestId: Value(requestId),
      ledgerId: ledgerId == null && nullToAbsent
          ? const Value.absent()
          : Value(ledgerId),
      sourceImagePath: Value(sourceImagePath),
      sourceInfoJson: sourceInfoJson == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceInfoJson),
      state: Value(state),
      version: Value(version),
      encryptedOcrEvidence: encryptedOcrEvidence == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedOcrEvidence),
      extractionResultJson: extractionResultJson == null && nullToAbsent
          ? const Value.absent()
          : Value(extractionResultJson),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
      syncAllowed: Value(syncAllowed),
      evidencePurgeAfter: evidencePurgeAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(evidencePurgeAfter),
      workflowDeleteAfter: workflowDeleteAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(workflowDeleteAfter),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory BillingCase.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BillingCase(
      id: serializer.fromJson<int>(json['id']),
      requestId: serializer.fromJson<String>(json['requestId']),
      ledgerId: serializer.fromJson<int?>(json['ledgerId']),
      sourceImagePath: serializer.fromJson<String>(json['sourceImagePath']),
      sourceInfoJson: serializer.fromJson<String?>(json['sourceInfoJson']),
      state: serializer.fromJson<String>(json['state']),
      version: serializer.fromJson<int>(json['version']),
      encryptedOcrEvidence:
          serializer.fromJson<String?>(json['encryptedOcrEvidence']),
      extractionResultJson:
          serializer.fromJson<String?>(json['extractionResultJson']),
      transactionId: serializer.fromJson<int?>(json['transactionId']),
      syncAllowed: serializer.fromJson<bool>(json['syncAllowed']),
      evidencePurgeAfter:
          serializer.fromJson<DateTime?>(json['evidencePurgeAfter']),
      workflowDeleteAfter:
          serializer.fromJson<DateTime?>(json['workflowDeleteAfter']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'requestId': serializer.toJson<String>(requestId),
      'ledgerId': serializer.toJson<int?>(ledgerId),
      'sourceImagePath': serializer.toJson<String>(sourceImagePath),
      'sourceInfoJson': serializer.toJson<String?>(sourceInfoJson),
      'state': serializer.toJson<String>(state),
      'version': serializer.toJson<int>(version),
      'encryptedOcrEvidence': serializer.toJson<String?>(encryptedOcrEvidence),
      'extractionResultJson': serializer.toJson<String?>(extractionResultJson),
      'transactionId': serializer.toJson<int?>(transactionId),
      'syncAllowed': serializer.toJson<bool>(syncAllowed),
      'evidencePurgeAfter': serializer.toJson<DateTime?>(evidencePurgeAfter),
      'workflowDeleteAfter': serializer.toJson<DateTime?>(workflowDeleteAfter),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  BillingCase copyWith(
          {int? id,
          String? requestId,
          Value<int?> ledgerId = const Value.absent(),
          String? sourceImagePath,
          Value<String?> sourceInfoJson = const Value.absent(),
          String? state,
          int? version,
          Value<String?> encryptedOcrEvidence = const Value.absent(),
          Value<String?> extractionResultJson = const Value.absent(),
          Value<int?> transactionId = const Value.absent(),
          bool? syncAllowed,
          Value<DateTime?> evidencePurgeAfter = const Value.absent(),
          Value<DateTime?> workflowDeleteAfter = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> completedAt = const Value.absent()}) =>
      BillingCase(
        id: id ?? this.id,
        requestId: requestId ?? this.requestId,
        ledgerId: ledgerId.present ? ledgerId.value : this.ledgerId,
        sourceImagePath: sourceImagePath ?? this.sourceImagePath,
        sourceInfoJson:
            sourceInfoJson.present ? sourceInfoJson.value : this.sourceInfoJson,
        state: state ?? this.state,
        version: version ?? this.version,
        encryptedOcrEvidence: encryptedOcrEvidence.present
            ? encryptedOcrEvidence.value
            : this.encryptedOcrEvidence,
        extractionResultJson: extractionResultJson.present
            ? extractionResultJson.value
            : this.extractionResultJson,
        transactionId:
            transactionId.present ? transactionId.value : this.transactionId,
        syncAllowed: syncAllowed ?? this.syncAllowed,
        evidencePurgeAfter: evidencePurgeAfter.present
            ? evidencePurgeAfter.value
            : this.evidencePurgeAfter,
        workflowDeleteAfter: workflowDeleteAfter.present
            ? workflowDeleteAfter.value
            : this.workflowDeleteAfter,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
      );
  BillingCase copyWithCompanion(BillingCasesCompanion data) {
    return BillingCase(
      id: data.id.present ? data.id.value : this.id,
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      sourceImagePath: data.sourceImagePath.present
          ? data.sourceImagePath.value
          : this.sourceImagePath,
      sourceInfoJson: data.sourceInfoJson.present
          ? data.sourceInfoJson.value
          : this.sourceInfoJson,
      state: data.state.present ? data.state.value : this.state,
      version: data.version.present ? data.version.value : this.version,
      encryptedOcrEvidence: data.encryptedOcrEvidence.present
          ? data.encryptedOcrEvidence.value
          : this.encryptedOcrEvidence,
      extractionResultJson: data.extractionResultJson.present
          ? data.extractionResultJson.value
          : this.extractionResultJson,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      syncAllowed:
          data.syncAllowed.present ? data.syncAllowed.value : this.syncAllowed,
      evidencePurgeAfter: data.evidencePurgeAfter.present
          ? data.evidencePurgeAfter.value
          : this.evidencePurgeAfter,
      workflowDeleteAfter: data.workflowDeleteAfter.present
          ? data.workflowDeleteAfter.value
          : this.workflowDeleteAfter,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BillingCase(')
          ..write('id: $id, ')
          ..write('requestId: $requestId, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('sourceImagePath: $sourceImagePath, ')
          ..write('sourceInfoJson: $sourceInfoJson, ')
          ..write('state: $state, ')
          ..write('version: $version, ')
          ..write('encryptedOcrEvidence: $encryptedOcrEvidence, ')
          ..write('extractionResultJson: $extractionResultJson, ')
          ..write('transactionId: $transactionId, ')
          ..write('syncAllowed: $syncAllowed, ')
          ..write('evidencePurgeAfter: $evidencePurgeAfter, ')
          ..write('workflowDeleteAfter: $workflowDeleteAfter, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      requestId,
      ledgerId,
      sourceImagePath,
      sourceInfoJson,
      state,
      version,
      encryptedOcrEvidence,
      extractionResultJson,
      transactionId,
      syncAllowed,
      evidencePurgeAfter,
      workflowDeleteAfter,
      createdAt,
      updatedAt,
      completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BillingCase &&
          other.id == this.id &&
          other.requestId == this.requestId &&
          other.ledgerId == this.ledgerId &&
          other.sourceImagePath == this.sourceImagePath &&
          other.sourceInfoJson == this.sourceInfoJson &&
          other.state == this.state &&
          other.version == this.version &&
          other.encryptedOcrEvidence == this.encryptedOcrEvidence &&
          other.extractionResultJson == this.extractionResultJson &&
          other.transactionId == this.transactionId &&
          other.syncAllowed == this.syncAllowed &&
          other.evidencePurgeAfter == this.evidencePurgeAfter &&
          other.workflowDeleteAfter == this.workflowDeleteAfter &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt);
}

class BillingCasesCompanion extends UpdateCompanion<BillingCase> {
  final Value<int> id;
  final Value<String> requestId;
  final Value<int?> ledgerId;
  final Value<String> sourceImagePath;
  final Value<String?> sourceInfoJson;
  final Value<String> state;
  final Value<int> version;
  final Value<String?> encryptedOcrEvidence;
  final Value<String?> extractionResultJson;
  final Value<int?> transactionId;
  final Value<bool> syncAllowed;
  final Value<DateTime?> evidencePurgeAfter;
  final Value<DateTime?> workflowDeleteAfter;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> completedAt;
  const BillingCasesCompanion({
    this.id = const Value.absent(),
    this.requestId = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.sourceImagePath = const Value.absent(),
    this.sourceInfoJson = const Value.absent(),
    this.state = const Value.absent(),
    this.version = const Value.absent(),
    this.encryptedOcrEvidence = const Value.absent(),
    this.extractionResultJson = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.syncAllowed = const Value.absent(),
    this.evidencePurgeAfter = const Value.absent(),
    this.workflowDeleteAfter = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  BillingCasesCompanion.insert({
    this.id = const Value.absent(),
    required String requestId,
    this.ledgerId = const Value.absent(),
    required String sourceImagePath,
    this.sourceInfoJson = const Value.absent(),
    this.state = const Value.absent(),
    this.version = const Value.absent(),
    this.encryptedOcrEvidence = const Value.absent(),
    this.extractionResultJson = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.syncAllowed = const Value.absent(),
    this.evidencePurgeAfter = const Value.absent(),
    this.workflowDeleteAfter = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  })  : requestId = Value(requestId),
        sourceImagePath = Value(sourceImagePath);
  static Insertable<BillingCase> custom({
    Expression<int>? id,
    Expression<String>? requestId,
    Expression<int>? ledgerId,
    Expression<String>? sourceImagePath,
    Expression<String>? sourceInfoJson,
    Expression<String>? state,
    Expression<int>? version,
    Expression<String>? encryptedOcrEvidence,
    Expression<String>? extractionResultJson,
    Expression<int>? transactionId,
    Expression<bool>? syncAllowed,
    Expression<DateTime>? evidencePurgeAfter,
    Expression<DateTime>? workflowDeleteAfter,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? completedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (requestId != null) 'request_id': requestId,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (sourceImagePath != null) 'source_image_path': sourceImagePath,
      if (sourceInfoJson != null) 'source_info_json': sourceInfoJson,
      if (state != null) 'state': state,
      if (version != null) 'version': version,
      if (encryptedOcrEvidence != null)
        'encrypted_ocr_evidence': encryptedOcrEvidence,
      if (extractionResultJson != null)
        'extraction_result_json': extractionResultJson,
      if (transactionId != null) 'transaction_id': transactionId,
      if (syncAllowed != null) 'sync_allowed': syncAllowed,
      if (evidencePurgeAfter != null)
        'evidence_purge_after': evidencePurgeAfter,
      if (workflowDeleteAfter != null)
        'workflow_delete_after': workflowDeleteAfter,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  BillingCasesCompanion copyWith(
      {Value<int>? id,
      Value<String>? requestId,
      Value<int?>? ledgerId,
      Value<String>? sourceImagePath,
      Value<String?>? sourceInfoJson,
      Value<String>? state,
      Value<int>? version,
      Value<String?>? encryptedOcrEvidence,
      Value<String?>? extractionResultJson,
      Value<int?>? transactionId,
      Value<bool>? syncAllowed,
      Value<DateTime?>? evidencePurgeAfter,
      Value<DateTime?>? workflowDeleteAfter,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? completedAt}) {
    return BillingCasesCompanion(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      ledgerId: ledgerId ?? this.ledgerId,
      sourceImagePath: sourceImagePath ?? this.sourceImagePath,
      sourceInfoJson: sourceInfoJson ?? this.sourceInfoJson,
      state: state ?? this.state,
      version: version ?? this.version,
      encryptedOcrEvidence: encryptedOcrEvidence ?? this.encryptedOcrEvidence,
      extractionResultJson: extractionResultJson ?? this.extractionResultJson,
      transactionId: transactionId ?? this.transactionId,
      syncAllowed: syncAllowed ?? this.syncAllowed,
      evidencePurgeAfter: evidencePurgeAfter ?? this.evidencePurgeAfter,
      workflowDeleteAfter: workflowDeleteAfter ?? this.workflowDeleteAfter,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<int>(ledgerId.value);
    }
    if (sourceImagePath.present) {
      map['source_image_path'] = Variable<String>(sourceImagePath.value);
    }
    if (sourceInfoJson.present) {
      map['source_info_json'] = Variable<String>(sourceInfoJson.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (encryptedOcrEvidence.present) {
      map['encrypted_ocr_evidence'] =
          Variable<String>(encryptedOcrEvidence.value);
    }
    if (extractionResultJson.present) {
      map['extraction_result_json'] =
          Variable<String>(extractionResultJson.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (syncAllowed.present) {
      map['sync_allowed'] = Variable<bool>(syncAllowed.value);
    }
    if (evidencePurgeAfter.present) {
      map['evidence_purge_after'] =
          Variable<DateTime>(evidencePurgeAfter.value);
    }
    if (workflowDeleteAfter.present) {
      map['workflow_delete_after'] =
          Variable<DateTime>(workflowDeleteAfter.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BillingCasesCompanion(')
          ..write('id: $id, ')
          ..write('requestId: $requestId, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('sourceImagePath: $sourceImagePath, ')
          ..write('sourceInfoJson: $sourceInfoJson, ')
          ..write('state: $state, ')
          ..write('version: $version, ')
          ..write('encryptedOcrEvidence: $encryptedOcrEvidence, ')
          ..write('extractionResultJson: $extractionResultJson, ')
          ..write('transactionId: $transactionId, ')
          ..write('syncAllowed: $syncAllowed, ')
          ..write('evidencePurgeAfter: $evidencePurgeAfter, ')
          ..write('workflowDeleteAfter: $workflowDeleteAfter, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

class $BillingAutomationTasksTable extends BillingAutomationTasks
    with TableInfo<$BillingAutomationTasksTable, BillingAutomationTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BillingAutomationTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _caseIdMeta = const VerificationMeta('caseId');
  @override
  late final GeneratedColumn<int> caseId = GeneratedColumn<int>(
      'case_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
      'state', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('ready'));
  static const VerificationMeta _availableAtMeta =
      const VerificationMeta('availableAt');
  @override
  late final GeneratedColumn<DateTime> availableAt = GeneratedColumn<DateTime>(
      'available_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _attemptMeta =
      const VerificationMeta('attempt');
  @override
  late final GeneratedColumn<int> attempt = GeneratedColumn<int>(
      'attempt', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _leaseOwnerMeta =
      const VerificationMeta('leaseOwner');
  @override
  late final GeneratedColumn<String> leaseOwner = GeneratedColumn<String>(
      'lease_owner', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _leaseGenerationMeta =
      const VerificationMeta('leaseGeneration');
  @override
  late final GeneratedColumn<int> leaseGeneration = GeneratedColumn<int>(
      'lease_generation', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _leaseUntilMeta =
      const VerificationMeta('leaseUntil');
  @override
  late final GeneratedColumn<DateTime> leaseUntil = GeneratedColumn<DateTime>(
      'lease_until', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastErrorCodeMeta =
      const VerificationMeta('lastErrorCode');
  @override
  late final GeneratedColumn<String> lastErrorCode = GeneratedColumn<String>(
      'last_error_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        caseId,
        kind,
        state,
        availableAt,
        attempt,
        leaseOwner,
        leaseGeneration,
        leaseUntil,
        lastErrorCode,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'billing_automation_tasks';
  @override
  VerificationContext validateIntegrity(
      Insertable<BillingAutomationTask> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('case_id')) {
      context.handle(_caseIdMeta,
          caseId.isAcceptableOrUnknown(data['case_id']!, _caseIdMeta));
    } else if (isInserting) {
      context.missing(_caseIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
          _stateMeta, state.isAcceptableOrUnknown(data['state']!, _stateMeta));
    }
    if (data.containsKey('available_at')) {
      context.handle(
          _availableAtMeta,
          availableAt.isAcceptableOrUnknown(
              data['available_at']!, _availableAtMeta));
    }
    if (data.containsKey('attempt')) {
      context.handle(_attemptMeta,
          attempt.isAcceptableOrUnknown(data['attempt']!, _attemptMeta));
    }
    if (data.containsKey('lease_owner')) {
      context.handle(
          _leaseOwnerMeta,
          leaseOwner.isAcceptableOrUnknown(
              data['lease_owner']!, _leaseOwnerMeta));
    }
    if (data.containsKey('lease_generation')) {
      context.handle(
          _leaseGenerationMeta,
          leaseGeneration.isAcceptableOrUnknown(
              data['lease_generation']!, _leaseGenerationMeta));
    }
    if (data.containsKey('lease_until')) {
      context.handle(
          _leaseUntilMeta,
          leaseUntil.isAcceptableOrUnknown(
              data['lease_until']!, _leaseUntilMeta));
    }
    if (data.containsKey('last_error_code')) {
      context.handle(
          _lastErrorCodeMeta,
          lastErrorCode.isAcceptableOrUnknown(
              data['last_error_code']!, _lastErrorCodeMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BillingAutomationTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BillingAutomationTask(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      caseId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}case_id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      state: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}state'])!,
      availableAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}available_at'])!,
      attempt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempt'])!,
      leaseOwner: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lease_owner']),
      leaseGeneration: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}lease_generation'])!,
      leaseUntil: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}lease_until']),
      lastErrorCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error_code']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $BillingAutomationTasksTable createAlias(String alias) {
    return $BillingAutomationTasksTable(attachedDatabase, alias);
  }
}

class BillingAutomationTask extends DataClass
    implements Insertable<BillingAutomationTask> {
  final int id;
  final int caseId;
  final String kind;
  final String state;
  final DateTime availableAt;
  final int attempt;
  final String? leaseOwner;
  final int leaseGeneration;
  final DateTime? leaseUntil;
  final String? lastErrorCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  const BillingAutomationTask(
      {required this.id,
      required this.caseId,
      required this.kind,
      required this.state,
      required this.availableAt,
      required this.attempt,
      this.leaseOwner,
      required this.leaseGeneration,
      this.leaseUntil,
      this.lastErrorCode,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['case_id'] = Variable<int>(caseId);
    map['kind'] = Variable<String>(kind);
    map['state'] = Variable<String>(state);
    map['available_at'] = Variable<DateTime>(availableAt);
    map['attempt'] = Variable<int>(attempt);
    if (!nullToAbsent || leaseOwner != null) {
      map['lease_owner'] = Variable<String>(leaseOwner);
    }
    map['lease_generation'] = Variable<int>(leaseGeneration);
    if (!nullToAbsent || leaseUntil != null) {
      map['lease_until'] = Variable<DateTime>(leaseUntil);
    }
    if (!nullToAbsent || lastErrorCode != null) {
      map['last_error_code'] = Variable<String>(lastErrorCode);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BillingAutomationTasksCompanion toCompanion(bool nullToAbsent) {
    return BillingAutomationTasksCompanion(
      id: Value(id),
      caseId: Value(caseId),
      kind: Value(kind),
      state: Value(state),
      availableAt: Value(availableAt),
      attempt: Value(attempt),
      leaseOwner: leaseOwner == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseOwner),
      leaseGeneration: Value(leaseGeneration),
      leaseUntil: leaseUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseUntil),
      lastErrorCode: lastErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorCode),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BillingAutomationTask.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BillingAutomationTask(
      id: serializer.fromJson<int>(json['id']),
      caseId: serializer.fromJson<int>(json['caseId']),
      kind: serializer.fromJson<String>(json['kind']),
      state: serializer.fromJson<String>(json['state']),
      availableAt: serializer.fromJson<DateTime>(json['availableAt']),
      attempt: serializer.fromJson<int>(json['attempt']),
      leaseOwner: serializer.fromJson<String?>(json['leaseOwner']),
      leaseGeneration: serializer.fromJson<int>(json['leaseGeneration']),
      leaseUntil: serializer.fromJson<DateTime?>(json['leaseUntil']),
      lastErrorCode: serializer.fromJson<String?>(json['lastErrorCode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'caseId': serializer.toJson<int>(caseId),
      'kind': serializer.toJson<String>(kind),
      'state': serializer.toJson<String>(state),
      'availableAt': serializer.toJson<DateTime>(availableAt),
      'attempt': serializer.toJson<int>(attempt),
      'leaseOwner': serializer.toJson<String?>(leaseOwner),
      'leaseGeneration': serializer.toJson<int>(leaseGeneration),
      'leaseUntil': serializer.toJson<DateTime?>(leaseUntil),
      'lastErrorCode': serializer.toJson<String?>(lastErrorCode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BillingAutomationTask copyWith(
          {int? id,
          int? caseId,
          String? kind,
          String? state,
          DateTime? availableAt,
          int? attempt,
          Value<String?> leaseOwner = const Value.absent(),
          int? leaseGeneration,
          Value<DateTime?> leaseUntil = const Value.absent(),
          Value<String?> lastErrorCode = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      BillingAutomationTask(
        id: id ?? this.id,
        caseId: caseId ?? this.caseId,
        kind: kind ?? this.kind,
        state: state ?? this.state,
        availableAt: availableAt ?? this.availableAt,
        attempt: attempt ?? this.attempt,
        leaseOwner: leaseOwner.present ? leaseOwner.value : this.leaseOwner,
        leaseGeneration: leaseGeneration ?? this.leaseGeneration,
        leaseUntil: leaseUntil.present ? leaseUntil.value : this.leaseUntil,
        lastErrorCode:
            lastErrorCode.present ? lastErrorCode.value : this.lastErrorCode,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  BillingAutomationTask copyWithCompanion(
      BillingAutomationTasksCompanion data) {
    return BillingAutomationTask(
      id: data.id.present ? data.id.value : this.id,
      caseId: data.caseId.present ? data.caseId.value : this.caseId,
      kind: data.kind.present ? data.kind.value : this.kind,
      state: data.state.present ? data.state.value : this.state,
      availableAt:
          data.availableAt.present ? data.availableAt.value : this.availableAt,
      attempt: data.attempt.present ? data.attempt.value : this.attempt,
      leaseOwner:
          data.leaseOwner.present ? data.leaseOwner.value : this.leaseOwner,
      leaseGeneration: data.leaseGeneration.present
          ? data.leaseGeneration.value
          : this.leaseGeneration,
      leaseUntil:
          data.leaseUntil.present ? data.leaseUntil.value : this.leaseUntil,
      lastErrorCode: data.lastErrorCode.present
          ? data.lastErrorCode.value
          : this.lastErrorCode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BillingAutomationTask(')
          ..write('id: $id, ')
          ..write('caseId: $caseId, ')
          ..write('kind: $kind, ')
          ..write('state: $state, ')
          ..write('availableAt: $availableAt, ')
          ..write('attempt: $attempt, ')
          ..write('leaseOwner: $leaseOwner, ')
          ..write('leaseGeneration: $leaseGeneration, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      caseId,
      kind,
      state,
      availableAt,
      attempt,
      leaseOwner,
      leaseGeneration,
      leaseUntil,
      lastErrorCode,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BillingAutomationTask &&
          other.id == this.id &&
          other.caseId == this.caseId &&
          other.kind == this.kind &&
          other.state == this.state &&
          other.availableAt == this.availableAt &&
          other.attempt == this.attempt &&
          other.leaseOwner == this.leaseOwner &&
          other.leaseGeneration == this.leaseGeneration &&
          other.leaseUntil == this.leaseUntil &&
          other.lastErrorCode == this.lastErrorCode &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BillingAutomationTasksCompanion
    extends UpdateCompanion<BillingAutomationTask> {
  final Value<int> id;
  final Value<int> caseId;
  final Value<String> kind;
  final Value<String> state;
  final Value<DateTime> availableAt;
  final Value<int> attempt;
  final Value<String?> leaseOwner;
  final Value<int> leaseGeneration;
  final Value<DateTime?> leaseUntil;
  final Value<String?> lastErrorCode;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const BillingAutomationTasksCompanion({
    this.id = const Value.absent(),
    this.caseId = const Value.absent(),
    this.kind = const Value.absent(),
    this.state = const Value.absent(),
    this.availableAt = const Value.absent(),
    this.attempt = const Value.absent(),
    this.leaseOwner = const Value.absent(),
    this.leaseGeneration = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BillingAutomationTasksCompanion.insert({
    this.id = const Value.absent(),
    required int caseId,
    required String kind,
    this.state = const Value.absent(),
    this.availableAt = const Value.absent(),
    this.attempt = const Value.absent(),
    this.leaseOwner = const Value.absent(),
    this.leaseGeneration = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : caseId = Value(caseId),
        kind = Value(kind);
  static Insertable<BillingAutomationTask> custom({
    Expression<int>? id,
    Expression<int>? caseId,
    Expression<String>? kind,
    Expression<String>? state,
    Expression<DateTime>? availableAt,
    Expression<int>? attempt,
    Expression<String>? leaseOwner,
    Expression<int>? leaseGeneration,
    Expression<DateTime>? leaseUntil,
    Expression<String>? lastErrorCode,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (caseId != null) 'case_id': caseId,
      if (kind != null) 'kind': kind,
      if (state != null) 'state': state,
      if (availableAt != null) 'available_at': availableAt,
      if (attempt != null) 'attempt': attempt,
      if (leaseOwner != null) 'lease_owner': leaseOwner,
      if (leaseGeneration != null) 'lease_generation': leaseGeneration,
      if (leaseUntil != null) 'lease_until': leaseUntil,
      if (lastErrorCode != null) 'last_error_code': lastErrorCode,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BillingAutomationTasksCompanion copyWith(
      {Value<int>? id,
      Value<int>? caseId,
      Value<String>? kind,
      Value<String>? state,
      Value<DateTime>? availableAt,
      Value<int>? attempt,
      Value<String?>? leaseOwner,
      Value<int>? leaseGeneration,
      Value<DateTime?>? leaseUntil,
      Value<String?>? lastErrorCode,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return BillingAutomationTasksCompanion(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      kind: kind ?? this.kind,
      state: state ?? this.state,
      availableAt: availableAt ?? this.availableAt,
      attempt: attempt ?? this.attempt,
      leaseOwner: leaseOwner ?? this.leaseOwner,
      leaseGeneration: leaseGeneration ?? this.leaseGeneration,
      leaseUntil: leaseUntil ?? this.leaseUntil,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (caseId.present) {
      map['case_id'] = Variable<int>(caseId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (availableAt.present) {
      map['available_at'] = Variable<DateTime>(availableAt.value);
    }
    if (attempt.present) {
      map['attempt'] = Variable<int>(attempt.value);
    }
    if (leaseOwner.present) {
      map['lease_owner'] = Variable<String>(leaseOwner.value);
    }
    if (leaseGeneration.present) {
      map['lease_generation'] = Variable<int>(leaseGeneration.value);
    }
    if (leaseUntil.present) {
      map['lease_until'] = Variable<DateTime>(leaseUntil.value);
    }
    if (lastErrorCode.present) {
      map['last_error_code'] = Variable<String>(lastErrorCode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BillingAutomationTasksCompanion(')
          ..write('id: $id, ')
          ..write('caseId: $caseId, ')
          ..write('kind: $kind, ')
          ..write('state: $state, ')
          ..write('availableAt: $availableAt, ')
          ..write('attempt: $attempt, ')
          ..write('leaseOwner: $leaseOwner, ')
          ..write('leaseGeneration: $leaseGeneration, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $BillingUserTasksTable extends BillingUserTasks
    with TableInfo<$BillingUserTasksTable, BillingUserTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BillingUserTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _caseIdMeta = const VerificationMeta('caseId');
  @override
  late final GeneratedColumn<int> caseId = GeneratedColumn<int>(
      'case_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
      'state', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('open'));
  static const VerificationMeta _transactionIdMeta =
      const VerificationMeta('transactionId');
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
      'transaction_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _draftJsonMeta =
      const VerificationMeta('draftJson');
  @override
  late final GeneratedColumn<String> draftJson = GeneratedColumn<String>(
      'draft_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _resolutionJsonMeta =
      const VerificationMeta('resolutionJson');
  @override
  late final GeneratedColumn<String> resolutionJson = GeneratedColumn<String>(
      'resolution_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _resolvedAtMeta =
      const VerificationMeta('resolvedAt');
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
      'resolved_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _expiresAtMeta =
      const VerificationMeta('expiresAt');
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
      'expires_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        caseId,
        kind,
        state,
        transactionId,
        draftJson,
        resolutionJson,
        version,
        createdAt,
        resolvedAt,
        expiresAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'billing_user_tasks';
  @override
  VerificationContext validateIntegrity(Insertable<BillingUserTask> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('case_id')) {
      context.handle(_caseIdMeta,
          caseId.isAcceptableOrUnknown(data['case_id']!, _caseIdMeta));
    } else if (isInserting) {
      context.missing(_caseIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
          _stateMeta, state.isAcceptableOrUnknown(data['state']!, _stateMeta));
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
          _transactionIdMeta,
          transactionId.isAcceptableOrUnknown(
              data['transaction_id']!, _transactionIdMeta));
    }
    if (data.containsKey('draft_json')) {
      context.handle(_draftJsonMeta,
          draftJson.isAcceptableOrUnknown(data['draft_json']!, _draftJsonMeta));
    }
    if (data.containsKey('resolution_json')) {
      context.handle(
          _resolutionJsonMeta,
          resolutionJson.isAcceptableOrUnknown(
              data['resolution_json']!, _resolutionJsonMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
          _resolvedAtMeta,
          resolvedAt.isAcceptableOrUnknown(
              data['resolved_at']!, _resolvedAtMeta));
    }
    if (data.containsKey('expires_at')) {
      context.handle(_expiresAtMeta,
          expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BillingUserTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BillingUserTask(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      caseId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}case_id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      state: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}state'])!,
      transactionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}transaction_id']),
      draftJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}draft_json']),
      resolutionJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}resolution_json']),
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      resolvedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}resolved_at']),
      expiresAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expires_at']),
    );
  }

  @override
  $BillingUserTasksTable createAlias(String alias) {
    return $BillingUserTasksTable(attachedDatabase, alias);
  }
}

class BillingUserTask extends DataClass implements Insertable<BillingUserTask> {
  final int id;
  final int caseId;
  final String kind;
  final String state;
  final int? transactionId;
  final String? draftJson;
  final String? resolutionJson;
  final int version;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final DateTime? expiresAt;
  const BillingUserTask(
      {required this.id,
      required this.caseId,
      required this.kind,
      required this.state,
      this.transactionId,
      this.draftJson,
      this.resolutionJson,
      required this.version,
      required this.createdAt,
      this.resolvedAt,
      this.expiresAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['case_id'] = Variable<int>(caseId);
    map['kind'] = Variable<String>(kind);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<int>(transactionId);
    }
    if (!nullToAbsent || draftJson != null) {
      map['draft_json'] = Variable<String>(draftJson);
    }
    if (!nullToAbsent || resolutionJson != null) {
      map['resolution_json'] = Variable<String>(resolutionJson);
    }
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    return map;
  }

  BillingUserTasksCompanion toCompanion(bool nullToAbsent) {
    return BillingUserTasksCompanion(
      id: Value(id),
      caseId: Value(caseId),
      kind: Value(kind),
      state: Value(state),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
      draftJson: draftJson == null && nullToAbsent
          ? const Value.absent()
          : Value(draftJson),
      resolutionJson: resolutionJson == null && nullToAbsent
          ? const Value.absent()
          : Value(resolutionJson),
      version: Value(version),
      createdAt: Value(createdAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
    );
  }

  factory BillingUserTask.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BillingUserTask(
      id: serializer.fromJson<int>(json['id']),
      caseId: serializer.fromJson<int>(json['caseId']),
      kind: serializer.fromJson<String>(json['kind']),
      state: serializer.fromJson<String>(json['state']),
      transactionId: serializer.fromJson<int?>(json['transactionId']),
      draftJson: serializer.fromJson<String?>(json['draftJson']),
      resolutionJson: serializer.fromJson<String?>(json['resolutionJson']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'caseId': serializer.toJson<int>(caseId),
      'kind': serializer.toJson<String>(kind),
      'state': serializer.toJson<String>(state),
      'transactionId': serializer.toJson<int?>(transactionId),
      'draftJson': serializer.toJson<String?>(draftJson),
      'resolutionJson': serializer.toJson<String?>(resolutionJson),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
    };
  }

  BillingUserTask copyWith(
          {int? id,
          int? caseId,
          String? kind,
          String? state,
          Value<int?> transactionId = const Value.absent(),
          Value<String?> draftJson = const Value.absent(),
          Value<String?> resolutionJson = const Value.absent(),
          int? version,
          DateTime? createdAt,
          Value<DateTime?> resolvedAt = const Value.absent(),
          Value<DateTime?> expiresAt = const Value.absent()}) =>
      BillingUserTask(
        id: id ?? this.id,
        caseId: caseId ?? this.caseId,
        kind: kind ?? this.kind,
        state: state ?? this.state,
        transactionId:
            transactionId.present ? transactionId.value : this.transactionId,
        draftJson: draftJson.present ? draftJson.value : this.draftJson,
        resolutionJson:
            resolutionJson.present ? resolutionJson.value : this.resolutionJson,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
        expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
      );
  BillingUserTask copyWithCompanion(BillingUserTasksCompanion data) {
    return BillingUserTask(
      id: data.id.present ? data.id.value : this.id,
      caseId: data.caseId.present ? data.caseId.value : this.caseId,
      kind: data.kind.present ? data.kind.value : this.kind,
      state: data.state.present ? data.state.value : this.state,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      draftJson: data.draftJson.present ? data.draftJson.value : this.draftJson,
      resolutionJson: data.resolutionJson.present
          ? data.resolutionJson.value
          : this.resolutionJson,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      resolvedAt:
          data.resolvedAt.present ? data.resolvedAt.value : this.resolvedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BillingUserTask(')
          ..write('id: $id, ')
          ..write('caseId: $caseId, ')
          ..write('kind: $kind, ')
          ..write('state: $state, ')
          ..write('transactionId: $transactionId, ')
          ..write('draftJson: $draftJson, ')
          ..write('resolutionJson: $resolutionJson, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, caseId, kind, state, transactionId,
      draftJson, resolutionJson, version, createdAt, resolvedAt, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BillingUserTask &&
          other.id == this.id &&
          other.caseId == this.caseId &&
          other.kind == this.kind &&
          other.state == this.state &&
          other.transactionId == this.transactionId &&
          other.draftJson == this.draftJson &&
          other.resolutionJson == this.resolutionJson &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.resolvedAt == this.resolvedAt &&
          other.expiresAt == this.expiresAt);
}

class BillingUserTasksCompanion extends UpdateCompanion<BillingUserTask> {
  final Value<int> id;
  final Value<int> caseId;
  final Value<String> kind;
  final Value<String> state;
  final Value<int?> transactionId;
  final Value<String?> draftJson;
  final Value<String?> resolutionJson;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime?> resolvedAt;
  final Value<DateTime?> expiresAt;
  const BillingUserTasksCompanion({
    this.id = const Value.absent(),
    this.caseId = const Value.absent(),
    this.kind = const Value.absent(),
    this.state = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.draftJson = const Value.absent(),
    this.resolutionJson = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
  });
  BillingUserTasksCompanion.insert({
    this.id = const Value.absent(),
    required int caseId,
    required String kind,
    this.state = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.draftJson = const Value.absent(),
    this.resolutionJson = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
  })  : caseId = Value(caseId),
        kind = Value(kind);
  static Insertable<BillingUserTask> custom({
    Expression<int>? id,
    Expression<int>? caseId,
    Expression<String>? kind,
    Expression<String>? state,
    Expression<int>? transactionId,
    Expression<String>? draftJson,
    Expression<String>? resolutionJson,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? resolvedAt,
    Expression<DateTime>? expiresAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (caseId != null) 'case_id': caseId,
      if (kind != null) 'kind': kind,
      if (state != null) 'state': state,
      if (transactionId != null) 'transaction_id': transactionId,
      if (draftJson != null) 'draft_json': draftJson,
      if (resolutionJson != null) 'resolution_json': resolutionJson,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
    });
  }

  BillingUserTasksCompanion copyWith(
      {Value<int>? id,
      Value<int>? caseId,
      Value<String>? kind,
      Value<String>? state,
      Value<int?>? transactionId,
      Value<String?>? draftJson,
      Value<String?>? resolutionJson,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime?>? resolvedAt,
      Value<DateTime?>? expiresAt}) {
    return BillingUserTasksCompanion(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      kind: kind ?? this.kind,
      state: state ?? this.state,
      transactionId: transactionId ?? this.transactionId,
      draftJson: draftJson ?? this.draftJson,
      resolutionJson: resolutionJson ?? this.resolutionJson,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (caseId.present) {
      map['case_id'] = Variable<int>(caseId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (draftJson.present) {
      map['draft_json'] = Variable<String>(draftJson.value);
    }
    if (resolutionJson.present) {
      map['resolution_json'] = Variable<String>(resolutionJson.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BillingUserTasksCompanion(')
          ..write('id: $id, ')
          ..write('caseId: $caseId, ')
          ..write('kind: $kind, ')
          ..write('state: $state, ')
          ..write('transactionId: $transactionId, ')
          ..write('draftJson: $draftJson, ')
          ..write('resolutionJson: $resolutionJson, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }
}

class $BillingPreparedAttachmentsTable extends BillingPreparedAttachments
    with
        TableInfo<$BillingPreparedAttachmentsTable, BillingPreparedAttachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BillingPreparedAttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _caseIdMeta = const VerificationMeta('caseId');
  @override
  late final GeneratedColumn<int> caseId = GeneratedColumn<int>(
      'case_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'UNIQUE NOT NULL');
  static const VerificationMeta _sourcePathMeta =
      const VerificationMeta('sourcePath');
  @override
  late final GeneratedColumn<String> sourcePath = GeneratedColumn<String>(
      'source_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _preparedPathMeta =
      const VerificationMeta('preparedPath');
  @override
  late final GeneratedColumn<String> preparedPath = GeneratedColumn<String>(
      'prepared_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contentHashMeta =
      const VerificationMeta('contentHash');
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
      'content_hash', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mimeTypeMeta =
      const VerificationMeta('mimeType');
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
      'mime_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _byteLengthMeta =
      const VerificationMeta('byteLength');
  @override
  late final GeneratedColumn<int> byteLength = GeneratedColumn<int>(
      'byte_length', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
      'width', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
      'height', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
      'state', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _errorCodeMeta =
      const VerificationMeta('errorCode');
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
      'error_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _preparedAtMeta =
      const VerificationMeta('preparedAt');
  @override
  late final GeneratedColumn<DateTime> preparedAt = GeneratedColumn<DateTime>(
      'prepared_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _publishedAtMeta =
      const VerificationMeta('publishedAt');
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
      'published_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        caseId,
        sourcePath,
        preparedPath,
        contentHash,
        mimeType,
        byteLength,
        width,
        height,
        state,
        errorCode,
        createdAt,
        preparedAt,
        publishedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'billing_prepared_attachments';
  @override
  VerificationContext validateIntegrity(
      Insertable<BillingPreparedAttachment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('case_id')) {
      context.handle(_caseIdMeta,
          caseId.isAcceptableOrUnknown(data['case_id']!, _caseIdMeta));
    } else if (isInserting) {
      context.missing(_caseIdMeta);
    }
    if (data.containsKey('source_path')) {
      context.handle(
          _sourcePathMeta,
          sourcePath.isAcceptableOrUnknown(
              data['source_path']!, _sourcePathMeta));
    } else if (isInserting) {
      context.missing(_sourcePathMeta);
    }
    if (data.containsKey('prepared_path')) {
      context.handle(
          _preparedPathMeta,
          preparedPath.isAcceptableOrUnknown(
              data['prepared_path']!, _preparedPathMeta));
    }
    if (data.containsKey('content_hash')) {
      context.handle(
          _contentHashMeta,
          contentHash.isAcceptableOrUnknown(
              data['content_hash']!, _contentHashMeta));
    }
    if (data.containsKey('mime_type')) {
      context.handle(_mimeTypeMeta,
          mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta));
    }
    if (data.containsKey('byte_length')) {
      context.handle(
          _byteLengthMeta,
          byteLength.isAcceptableOrUnknown(
              data['byte_length']!, _byteLengthMeta));
    }
    if (data.containsKey('width')) {
      context.handle(
          _widthMeta, width.isAcceptableOrUnknown(data['width']!, _widthMeta));
    }
    if (data.containsKey('height')) {
      context.handle(_heightMeta,
          height.isAcceptableOrUnknown(data['height']!, _heightMeta));
    }
    if (data.containsKey('state')) {
      context.handle(
          _stateMeta, state.isAcceptableOrUnknown(data['state']!, _stateMeta));
    }
    if (data.containsKey('error_code')) {
      context.handle(_errorCodeMeta,
          errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('prepared_at')) {
      context.handle(
          _preparedAtMeta,
          preparedAt.isAcceptableOrUnknown(
              data['prepared_at']!, _preparedAtMeta));
    }
    if (data.containsKey('published_at')) {
      context.handle(
          _publishedAtMeta,
          publishedAt.isAcceptableOrUnknown(
              data['published_at']!, _publishedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BillingPreparedAttachment map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BillingPreparedAttachment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      caseId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}case_id'])!,
      sourcePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_path'])!,
      preparedPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}prepared_path']),
      contentHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_hash']),
      mimeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mime_type']),
      byteLength: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}byte_length']),
      width: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}width']),
      height: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}height']),
      state: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}state'])!,
      errorCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_code']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      preparedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}prepared_at']),
      publishedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}published_at']),
    );
  }

  @override
  $BillingPreparedAttachmentsTable createAlias(String alias) {
    return $BillingPreparedAttachmentsTable(attachedDatabase, alias);
  }
}

class BillingPreparedAttachment extends DataClass
    implements Insertable<BillingPreparedAttachment> {
  final int id;
  final int caseId;
  final String sourcePath;
  final String? preparedPath;
  final String? contentHash;
  final String? mimeType;
  final int? byteLength;
  final int? width;
  final int? height;
  final String state;
  final String? errorCode;
  final DateTime createdAt;
  final DateTime? preparedAt;
  final DateTime? publishedAt;
  const BillingPreparedAttachment(
      {required this.id,
      required this.caseId,
      required this.sourcePath,
      this.preparedPath,
      this.contentHash,
      this.mimeType,
      this.byteLength,
      this.width,
      this.height,
      required this.state,
      this.errorCode,
      required this.createdAt,
      this.preparedAt,
      this.publishedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['case_id'] = Variable<int>(caseId);
    map['source_path'] = Variable<String>(sourcePath);
    if (!nullToAbsent || preparedPath != null) {
      map['prepared_path'] = Variable<String>(preparedPath);
    }
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    if (!nullToAbsent || byteLength != null) {
      map['byte_length'] = Variable<int>(byteLength);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || preparedAt != null) {
      map['prepared_at'] = Variable<DateTime>(preparedAt);
    }
    if (!nullToAbsent || publishedAt != null) {
      map['published_at'] = Variable<DateTime>(publishedAt);
    }
    return map;
  }

  BillingPreparedAttachmentsCompanion toCompanion(bool nullToAbsent) {
    return BillingPreparedAttachmentsCompanion(
      id: Value(id),
      caseId: Value(caseId),
      sourcePath: Value(sourcePath),
      preparedPath: preparedPath == null && nullToAbsent
          ? const Value.absent()
          : Value(preparedPath),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      byteLength: byteLength == null && nullToAbsent
          ? const Value.absent()
          : Value(byteLength),
      width:
          width == null && nullToAbsent ? const Value.absent() : Value(width),
      height:
          height == null && nullToAbsent ? const Value.absent() : Value(height),
      state: Value(state),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      createdAt: Value(createdAt),
      preparedAt: preparedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(preparedAt),
      publishedAt: publishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedAt),
    );
  }

  factory BillingPreparedAttachment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BillingPreparedAttachment(
      id: serializer.fromJson<int>(json['id']),
      caseId: serializer.fromJson<int>(json['caseId']),
      sourcePath: serializer.fromJson<String>(json['sourcePath']),
      preparedPath: serializer.fromJson<String?>(json['preparedPath']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      byteLength: serializer.fromJson<int?>(json['byteLength']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      state: serializer.fromJson<String>(json['state']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      preparedAt: serializer.fromJson<DateTime?>(json['preparedAt']),
      publishedAt: serializer.fromJson<DateTime?>(json['publishedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'caseId': serializer.toJson<int>(caseId),
      'sourcePath': serializer.toJson<String>(sourcePath),
      'preparedPath': serializer.toJson<String?>(preparedPath),
      'contentHash': serializer.toJson<String?>(contentHash),
      'mimeType': serializer.toJson<String?>(mimeType),
      'byteLength': serializer.toJson<int?>(byteLength),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'state': serializer.toJson<String>(state),
      'errorCode': serializer.toJson<String?>(errorCode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'preparedAt': serializer.toJson<DateTime?>(preparedAt),
      'publishedAt': serializer.toJson<DateTime?>(publishedAt),
    };
  }

  BillingPreparedAttachment copyWith(
          {int? id,
          int? caseId,
          String? sourcePath,
          Value<String?> preparedPath = const Value.absent(),
          Value<String?> contentHash = const Value.absent(),
          Value<String?> mimeType = const Value.absent(),
          Value<int?> byteLength = const Value.absent(),
          Value<int?> width = const Value.absent(),
          Value<int?> height = const Value.absent(),
          String? state,
          Value<String?> errorCode = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> preparedAt = const Value.absent(),
          Value<DateTime?> publishedAt = const Value.absent()}) =>
      BillingPreparedAttachment(
        id: id ?? this.id,
        caseId: caseId ?? this.caseId,
        sourcePath: sourcePath ?? this.sourcePath,
        preparedPath:
            preparedPath.present ? preparedPath.value : this.preparedPath,
        contentHash: contentHash.present ? contentHash.value : this.contentHash,
        mimeType: mimeType.present ? mimeType.value : this.mimeType,
        byteLength: byteLength.present ? byteLength.value : this.byteLength,
        width: width.present ? width.value : this.width,
        height: height.present ? height.value : this.height,
        state: state ?? this.state,
        errorCode: errorCode.present ? errorCode.value : this.errorCode,
        createdAt: createdAt ?? this.createdAt,
        preparedAt: preparedAt.present ? preparedAt.value : this.preparedAt,
        publishedAt: publishedAt.present ? publishedAt.value : this.publishedAt,
      );
  BillingPreparedAttachment copyWithCompanion(
      BillingPreparedAttachmentsCompanion data) {
    return BillingPreparedAttachment(
      id: data.id.present ? data.id.value : this.id,
      caseId: data.caseId.present ? data.caseId.value : this.caseId,
      sourcePath:
          data.sourcePath.present ? data.sourcePath.value : this.sourcePath,
      preparedPath: data.preparedPath.present
          ? data.preparedPath.value
          : this.preparedPath,
      contentHash:
          data.contentHash.present ? data.contentHash.value : this.contentHash,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      byteLength:
          data.byteLength.present ? data.byteLength.value : this.byteLength,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      state: data.state.present ? data.state.value : this.state,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      preparedAt:
          data.preparedAt.present ? data.preparedAt.value : this.preparedAt,
      publishedAt:
          data.publishedAt.present ? data.publishedAt.value : this.publishedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BillingPreparedAttachment(')
          ..write('id: $id, ')
          ..write('caseId: $caseId, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('preparedPath: $preparedPath, ')
          ..write('contentHash: $contentHash, ')
          ..write('mimeType: $mimeType, ')
          ..write('byteLength: $byteLength, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('state: $state, ')
          ..write('errorCode: $errorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('preparedAt: $preparedAt, ')
          ..write('publishedAt: $publishedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      caseId,
      sourcePath,
      preparedPath,
      contentHash,
      mimeType,
      byteLength,
      width,
      height,
      state,
      errorCode,
      createdAt,
      preparedAt,
      publishedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BillingPreparedAttachment &&
          other.id == this.id &&
          other.caseId == this.caseId &&
          other.sourcePath == this.sourcePath &&
          other.preparedPath == this.preparedPath &&
          other.contentHash == this.contentHash &&
          other.mimeType == this.mimeType &&
          other.byteLength == this.byteLength &&
          other.width == this.width &&
          other.height == this.height &&
          other.state == this.state &&
          other.errorCode == this.errorCode &&
          other.createdAt == this.createdAt &&
          other.preparedAt == this.preparedAt &&
          other.publishedAt == this.publishedAt);
}

class BillingPreparedAttachmentsCompanion
    extends UpdateCompanion<BillingPreparedAttachment> {
  final Value<int> id;
  final Value<int> caseId;
  final Value<String> sourcePath;
  final Value<String?> preparedPath;
  final Value<String?> contentHash;
  final Value<String?> mimeType;
  final Value<int?> byteLength;
  final Value<int?> width;
  final Value<int?> height;
  final Value<String> state;
  final Value<String?> errorCode;
  final Value<DateTime> createdAt;
  final Value<DateTime?> preparedAt;
  final Value<DateTime?> publishedAt;
  const BillingPreparedAttachmentsCompanion({
    this.id = const Value.absent(),
    this.caseId = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.preparedPath = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.byteLength = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.state = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.preparedAt = const Value.absent(),
    this.publishedAt = const Value.absent(),
  });
  BillingPreparedAttachmentsCompanion.insert({
    this.id = const Value.absent(),
    required int caseId,
    required String sourcePath,
    this.preparedPath = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.byteLength = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.state = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.preparedAt = const Value.absent(),
    this.publishedAt = const Value.absent(),
  })  : caseId = Value(caseId),
        sourcePath = Value(sourcePath);
  static Insertable<BillingPreparedAttachment> custom({
    Expression<int>? id,
    Expression<int>? caseId,
    Expression<String>? sourcePath,
    Expression<String>? preparedPath,
    Expression<String>? contentHash,
    Expression<String>? mimeType,
    Expression<int>? byteLength,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? state,
    Expression<String>? errorCode,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? preparedAt,
    Expression<DateTime>? publishedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (caseId != null) 'case_id': caseId,
      if (sourcePath != null) 'source_path': sourcePath,
      if (preparedPath != null) 'prepared_path': preparedPath,
      if (contentHash != null) 'content_hash': contentHash,
      if (mimeType != null) 'mime_type': mimeType,
      if (byteLength != null) 'byte_length': byteLength,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (state != null) 'state': state,
      if (errorCode != null) 'error_code': errorCode,
      if (createdAt != null) 'created_at': createdAt,
      if (preparedAt != null) 'prepared_at': preparedAt,
      if (publishedAt != null) 'published_at': publishedAt,
    });
  }

  BillingPreparedAttachmentsCompanion copyWith(
      {Value<int>? id,
      Value<int>? caseId,
      Value<String>? sourcePath,
      Value<String?>? preparedPath,
      Value<String?>? contentHash,
      Value<String?>? mimeType,
      Value<int?>? byteLength,
      Value<int?>? width,
      Value<int?>? height,
      Value<String>? state,
      Value<String?>? errorCode,
      Value<DateTime>? createdAt,
      Value<DateTime?>? preparedAt,
      Value<DateTime?>? publishedAt}) {
    return BillingPreparedAttachmentsCompanion(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      sourcePath: sourcePath ?? this.sourcePath,
      preparedPath: preparedPath ?? this.preparedPath,
      contentHash: contentHash ?? this.contentHash,
      mimeType: mimeType ?? this.mimeType,
      byteLength: byteLength ?? this.byteLength,
      width: width ?? this.width,
      height: height ?? this.height,
      state: state ?? this.state,
      errorCode: errorCode ?? this.errorCode,
      createdAt: createdAt ?? this.createdAt,
      preparedAt: preparedAt ?? this.preparedAt,
      publishedAt: publishedAt ?? this.publishedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (caseId.present) {
      map['case_id'] = Variable<int>(caseId.value);
    }
    if (sourcePath.present) {
      map['source_path'] = Variable<String>(sourcePath.value);
    }
    if (preparedPath.present) {
      map['prepared_path'] = Variable<String>(preparedPath.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (byteLength.present) {
      map['byte_length'] = Variable<int>(byteLength.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (preparedAt.present) {
      map['prepared_at'] = Variable<DateTime>(preparedAt.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BillingPreparedAttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('caseId: $caseId, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('preparedPath: $preparedPath, ')
          ..write('contentHash: $contentHash, ')
          ..write('mimeType: $mimeType, ')
          ..write('byteLength: $byteLength, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('state: $state, ')
          ..write('errorCode: $errorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('preparedAt: $preparedAt, ')
          ..write('publishedAt: $publishedAt')
          ..write(')'))
        .toString();
  }
}

class $BillingOutboxTable extends BillingOutbox
    with TableInfo<$BillingOutboxTable, BillingOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BillingOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _caseIdMeta = const VerificationMeta('caseId');
  @override
  late final GeneratedColumn<int> caseId = GeneratedColumn<int>(
      'case_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _userTaskIdMeta =
      const VerificationMeta('userTaskId');
  @override
  late final GeneratedColumn<int> userTaskId = GeneratedColumn<int>(
      'user_task_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _eventTypeMeta =
      const VerificationMeta('eventType');
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
      'event_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
      'state', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _attemptMeta =
      const VerificationMeta('attempt');
  @override
  late final GeneratedColumn<int> attempt = GeneratedColumn<int>(
      'attempt', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _availableAtMeta =
      const VerificationMeta('availableAt');
  @override
  late final GeneratedColumn<DateTime> availableAt = GeneratedColumn<DateTime>(
      'available_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _deliveredAtMeta =
      const VerificationMeta('deliveredAt');
  @override
  late final GeneratedColumn<DateTime> deliveredAt = GeneratedColumn<DateTime>(
      'delivered_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        caseId,
        userTaskId,
        eventType,
        payloadJson,
        state,
        attempt,
        availableAt,
        createdAt,
        deliveredAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'billing_outbox';
  @override
  VerificationContext validateIntegrity(Insertable<BillingOutboxData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('case_id')) {
      context.handle(_caseIdMeta,
          caseId.isAcceptableOrUnknown(data['case_id']!, _caseIdMeta));
    } else if (isInserting) {
      context.missing(_caseIdMeta);
    }
    if (data.containsKey('user_task_id')) {
      context.handle(
          _userTaskIdMeta,
          userTaskId.isAcceptableOrUnknown(
              data['user_task_id']!, _userTaskIdMeta));
    }
    if (data.containsKey('event_type')) {
      context.handle(_eventTypeMeta,
          eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta));
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    }
    if (data.containsKey('state')) {
      context.handle(
          _stateMeta, state.isAcceptableOrUnknown(data['state']!, _stateMeta));
    }
    if (data.containsKey('attempt')) {
      context.handle(_attemptMeta,
          attempt.isAcceptableOrUnknown(data['attempt']!, _attemptMeta));
    }
    if (data.containsKey('available_at')) {
      context.handle(
          _availableAtMeta,
          availableAt.isAcceptableOrUnknown(
              data['available_at']!, _availableAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('delivered_at')) {
      context.handle(
          _deliveredAtMeta,
          deliveredAt.isAcceptableOrUnknown(
              data['delivered_at']!, _deliveredAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BillingOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BillingOutboxData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      caseId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}case_id'])!,
      userTaskId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}user_task_id']),
      eventType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_type'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json']),
      state: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}state'])!,
      attempt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempt'])!,
      availableAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}available_at'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      deliveredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}delivered_at']),
    );
  }

  @override
  $BillingOutboxTable createAlias(String alias) {
    return $BillingOutboxTable(attachedDatabase, alias);
  }
}

class BillingOutboxData extends DataClass
    implements Insertable<BillingOutboxData> {
  final int id;
  final int caseId;
  final int? userTaskId;
  final String eventType;
  final String? payloadJson;
  final String state;
  final int attempt;
  final DateTime availableAt;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  const BillingOutboxData(
      {required this.id,
      required this.caseId,
      this.userTaskId,
      required this.eventType,
      this.payloadJson,
      required this.state,
      required this.attempt,
      required this.availableAt,
      required this.createdAt,
      this.deliveredAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['case_id'] = Variable<int>(caseId);
    if (!nullToAbsent || userTaskId != null) {
      map['user_task_id'] = Variable<int>(userTaskId);
    }
    map['event_type'] = Variable<String>(eventType);
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    map['state'] = Variable<String>(state);
    map['attempt'] = Variable<int>(attempt);
    map['available_at'] = Variable<DateTime>(availableAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deliveredAt != null) {
      map['delivered_at'] = Variable<DateTime>(deliveredAt);
    }
    return map;
  }

  BillingOutboxCompanion toCompanion(bool nullToAbsent) {
    return BillingOutboxCompanion(
      id: Value(id),
      caseId: Value(caseId),
      userTaskId: userTaskId == null && nullToAbsent
          ? const Value.absent()
          : Value(userTaskId),
      eventType: Value(eventType),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
      state: Value(state),
      attempt: Value(attempt),
      availableAt: Value(availableAt),
      createdAt: Value(createdAt),
      deliveredAt: deliveredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deliveredAt),
    );
  }

  factory BillingOutboxData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BillingOutboxData(
      id: serializer.fromJson<int>(json['id']),
      caseId: serializer.fromJson<int>(json['caseId']),
      userTaskId: serializer.fromJson<int?>(json['userTaskId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
      state: serializer.fromJson<String>(json['state']),
      attempt: serializer.fromJson<int>(json['attempt']),
      availableAt: serializer.fromJson<DateTime>(json['availableAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deliveredAt: serializer.fromJson<DateTime?>(json['deliveredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'caseId': serializer.toJson<int>(caseId),
      'userTaskId': serializer.toJson<int?>(userTaskId),
      'eventType': serializer.toJson<String>(eventType),
      'payloadJson': serializer.toJson<String?>(payloadJson),
      'state': serializer.toJson<String>(state),
      'attempt': serializer.toJson<int>(attempt),
      'availableAt': serializer.toJson<DateTime>(availableAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deliveredAt': serializer.toJson<DateTime?>(deliveredAt),
    };
  }

  BillingOutboxData copyWith(
          {int? id,
          int? caseId,
          Value<int?> userTaskId = const Value.absent(),
          String? eventType,
          Value<String?> payloadJson = const Value.absent(),
          String? state,
          int? attempt,
          DateTime? availableAt,
          DateTime? createdAt,
          Value<DateTime?> deliveredAt = const Value.absent()}) =>
      BillingOutboxData(
        id: id ?? this.id,
        caseId: caseId ?? this.caseId,
        userTaskId: userTaskId.present ? userTaskId.value : this.userTaskId,
        eventType: eventType ?? this.eventType,
        payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
        state: state ?? this.state,
        attempt: attempt ?? this.attempt,
        availableAt: availableAt ?? this.availableAt,
        createdAt: createdAt ?? this.createdAt,
        deliveredAt: deliveredAt.present ? deliveredAt.value : this.deliveredAt,
      );
  BillingOutboxData copyWithCompanion(BillingOutboxCompanion data) {
    return BillingOutboxData(
      id: data.id.present ? data.id.value : this.id,
      caseId: data.caseId.present ? data.caseId.value : this.caseId,
      userTaskId:
          data.userTaskId.present ? data.userTaskId.value : this.userTaskId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      state: data.state.present ? data.state.value : this.state,
      attempt: data.attempt.present ? data.attempt.value : this.attempt,
      availableAt:
          data.availableAt.present ? data.availableAt.value : this.availableAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deliveredAt:
          data.deliveredAt.present ? data.deliveredAt.value : this.deliveredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BillingOutboxData(')
          ..write('id: $id, ')
          ..write('caseId: $caseId, ')
          ..write('userTaskId: $userTaskId, ')
          ..write('eventType: $eventType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('state: $state, ')
          ..write('attempt: $attempt, ')
          ..write('availableAt: $availableAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('deliveredAt: $deliveredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, caseId, userTaskId, eventType,
      payloadJson, state, attempt, availableAt, createdAt, deliveredAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BillingOutboxData &&
          other.id == this.id &&
          other.caseId == this.caseId &&
          other.userTaskId == this.userTaskId &&
          other.eventType == this.eventType &&
          other.payloadJson == this.payloadJson &&
          other.state == this.state &&
          other.attempt == this.attempt &&
          other.availableAt == this.availableAt &&
          other.createdAt == this.createdAt &&
          other.deliveredAt == this.deliveredAt);
}

class BillingOutboxCompanion extends UpdateCompanion<BillingOutboxData> {
  final Value<int> id;
  final Value<int> caseId;
  final Value<int?> userTaskId;
  final Value<String> eventType;
  final Value<String?> payloadJson;
  final Value<String> state;
  final Value<int> attempt;
  final Value<DateTime> availableAt;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deliveredAt;
  const BillingOutboxCompanion({
    this.id = const Value.absent(),
    this.caseId = const Value.absent(),
    this.userTaskId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.state = const Value.absent(),
    this.attempt = const Value.absent(),
    this.availableAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deliveredAt = const Value.absent(),
  });
  BillingOutboxCompanion.insert({
    this.id = const Value.absent(),
    required int caseId,
    this.userTaskId = const Value.absent(),
    required String eventType,
    this.payloadJson = const Value.absent(),
    this.state = const Value.absent(),
    this.attempt = const Value.absent(),
    this.availableAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deliveredAt = const Value.absent(),
  })  : caseId = Value(caseId),
        eventType = Value(eventType);
  static Insertable<BillingOutboxData> custom({
    Expression<int>? id,
    Expression<int>? caseId,
    Expression<int>? userTaskId,
    Expression<String>? eventType,
    Expression<String>? payloadJson,
    Expression<String>? state,
    Expression<int>? attempt,
    Expression<DateTime>? availableAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deliveredAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (caseId != null) 'case_id': caseId,
      if (userTaskId != null) 'user_task_id': userTaskId,
      if (eventType != null) 'event_type': eventType,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (state != null) 'state': state,
      if (attempt != null) 'attempt': attempt,
      if (availableAt != null) 'available_at': availableAt,
      if (createdAt != null) 'created_at': createdAt,
      if (deliveredAt != null) 'delivered_at': deliveredAt,
    });
  }

  BillingOutboxCompanion copyWith(
      {Value<int>? id,
      Value<int>? caseId,
      Value<int?>? userTaskId,
      Value<String>? eventType,
      Value<String?>? payloadJson,
      Value<String>? state,
      Value<int>? attempt,
      Value<DateTime>? availableAt,
      Value<DateTime>? createdAt,
      Value<DateTime?>? deliveredAt}) {
    return BillingOutboxCompanion(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      userTaskId: userTaskId ?? this.userTaskId,
      eventType: eventType ?? this.eventType,
      payloadJson: payloadJson ?? this.payloadJson,
      state: state ?? this.state,
      attempt: attempt ?? this.attempt,
      availableAt: availableAt ?? this.availableAt,
      createdAt: createdAt ?? this.createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (caseId.present) {
      map['case_id'] = Variable<int>(caseId.value);
    }
    if (userTaskId.present) {
      map['user_task_id'] = Variable<int>(userTaskId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (attempt.present) {
      map['attempt'] = Variable<int>(attempt.value);
    }
    if (availableAt.present) {
      map['available_at'] = Variable<DateTime>(availableAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deliveredAt.present) {
      map['delivered_at'] = Variable<DateTime>(deliveredAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BillingOutboxCompanion(')
          ..write('id: $id, ')
          ..write('caseId: $caseId, ')
          ..write('userTaskId: $userTaskId, ')
          ..write('eventType: $eventType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('state: $state, ')
          ..write('attempt: $attempt, ')
          ..write('availableAt: $availableAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('deliveredAt: $deliveredAt')
          ..write(')'))
        .toString();
  }
}

class $BillingCaseArtifactsTable extends BillingCaseArtifacts
    with TableInfo<$BillingCaseArtifactsTable, BillingCaseArtifact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BillingCaseArtifactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _caseIdMeta = const VerificationMeta('caseId');
  @override
  late final GeneratedColumn<int> caseId = GeneratedColumn<int>(
      'case_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _privatePathMeta =
      const VerificationMeta('privatePath');
  @override
  late final GeneratedColumn<String> privatePath = GeneratedColumn<String>(
      'private_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
      'state', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('active'));
  static const VerificationMeta _deleteAfterMeta =
      const VerificationMeta('deleteAfter');
  @override
  late final GeneratedColumn<DateTime> deleteAfter = GeneratedColumn<DateTime>(
      'delete_after', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        caseId,
        kind,
        privatePath,
        state,
        deleteAfter,
        deletedAt,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'billing_case_artifacts';
  @override
  VerificationContext validateIntegrity(
      Insertable<BillingCaseArtifact> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('case_id')) {
      context.handle(_caseIdMeta,
          caseId.isAcceptableOrUnknown(data['case_id']!, _caseIdMeta));
    } else if (isInserting) {
      context.missing(_caseIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('private_path')) {
      context.handle(
          _privatePathMeta,
          privatePath.isAcceptableOrUnknown(
              data['private_path']!, _privatePathMeta));
    } else if (isInserting) {
      context.missing(_privatePathMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
          _stateMeta, state.isAcceptableOrUnknown(data['state']!, _stateMeta));
    }
    if (data.containsKey('delete_after')) {
      context.handle(
          _deleteAfterMeta,
          deleteAfter.isAcceptableOrUnknown(
              data['delete_after']!, _deleteAfterMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BillingCaseArtifact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BillingCaseArtifact(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      caseId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}case_id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      privatePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}private_path'])!,
      state: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}state'])!,
      deleteAfter: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}delete_after']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $BillingCaseArtifactsTable createAlias(String alias) {
    return $BillingCaseArtifactsTable(attachedDatabase, alias);
  }
}

class BillingCaseArtifact extends DataClass
    implements Insertable<BillingCaseArtifact> {
  final int id;
  final int caseId;
  final String kind;
  final String privatePath;
  final String state;
  final DateTime? deleteAfter;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const BillingCaseArtifact(
      {required this.id,
      required this.caseId,
      required this.kind,
      required this.privatePath,
      required this.state,
      this.deleteAfter,
      this.deletedAt,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['case_id'] = Variable<int>(caseId);
    map['kind'] = Variable<String>(kind);
    map['private_path'] = Variable<String>(privatePath);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || deleteAfter != null) {
      map['delete_after'] = Variable<DateTime>(deleteAfter);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BillingCaseArtifactsCompanion toCompanion(bool nullToAbsent) {
    return BillingCaseArtifactsCompanion(
      id: Value(id),
      caseId: Value(caseId),
      kind: Value(kind),
      privatePath: Value(privatePath),
      state: Value(state),
      deleteAfter: deleteAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(deleteAfter),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BillingCaseArtifact.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BillingCaseArtifact(
      id: serializer.fromJson<int>(json['id']),
      caseId: serializer.fromJson<int>(json['caseId']),
      kind: serializer.fromJson<String>(json['kind']),
      privatePath: serializer.fromJson<String>(json['privatePath']),
      state: serializer.fromJson<String>(json['state']),
      deleteAfter: serializer.fromJson<DateTime?>(json['deleteAfter']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'caseId': serializer.toJson<int>(caseId),
      'kind': serializer.toJson<String>(kind),
      'privatePath': serializer.toJson<String>(privatePath),
      'state': serializer.toJson<String>(state),
      'deleteAfter': serializer.toJson<DateTime?>(deleteAfter),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BillingCaseArtifact copyWith(
          {int? id,
          int? caseId,
          String? kind,
          String? privatePath,
          String? state,
          Value<DateTime?> deleteAfter = const Value.absent(),
          Value<DateTime?> deletedAt = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      BillingCaseArtifact(
        id: id ?? this.id,
        caseId: caseId ?? this.caseId,
        kind: kind ?? this.kind,
        privatePath: privatePath ?? this.privatePath,
        state: state ?? this.state,
        deleteAfter: deleteAfter.present ? deleteAfter.value : this.deleteAfter,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  BillingCaseArtifact copyWithCompanion(BillingCaseArtifactsCompanion data) {
    return BillingCaseArtifact(
      id: data.id.present ? data.id.value : this.id,
      caseId: data.caseId.present ? data.caseId.value : this.caseId,
      kind: data.kind.present ? data.kind.value : this.kind,
      privatePath:
          data.privatePath.present ? data.privatePath.value : this.privatePath,
      state: data.state.present ? data.state.value : this.state,
      deleteAfter:
          data.deleteAfter.present ? data.deleteAfter.value : this.deleteAfter,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BillingCaseArtifact(')
          ..write('id: $id, ')
          ..write('caseId: $caseId, ')
          ..write('kind: $kind, ')
          ..write('privatePath: $privatePath, ')
          ..write('state: $state, ')
          ..write('deleteAfter: $deleteAfter, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, caseId, kind, privatePath, state,
      deleteAfter, deletedAt, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BillingCaseArtifact &&
          other.id == this.id &&
          other.caseId == this.caseId &&
          other.kind == this.kind &&
          other.privatePath == this.privatePath &&
          other.state == this.state &&
          other.deleteAfter == this.deleteAfter &&
          other.deletedAt == this.deletedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BillingCaseArtifactsCompanion
    extends UpdateCompanion<BillingCaseArtifact> {
  final Value<int> id;
  final Value<int> caseId;
  final Value<String> kind;
  final Value<String> privatePath;
  final Value<String> state;
  final Value<DateTime?> deleteAfter;
  final Value<DateTime?> deletedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const BillingCaseArtifactsCompanion({
    this.id = const Value.absent(),
    this.caseId = const Value.absent(),
    this.kind = const Value.absent(),
    this.privatePath = const Value.absent(),
    this.state = const Value.absent(),
    this.deleteAfter = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BillingCaseArtifactsCompanion.insert({
    this.id = const Value.absent(),
    required int caseId,
    required String kind,
    required String privatePath,
    this.state = const Value.absent(),
    this.deleteAfter = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : caseId = Value(caseId),
        kind = Value(kind),
        privatePath = Value(privatePath);
  static Insertable<BillingCaseArtifact> custom({
    Expression<int>? id,
    Expression<int>? caseId,
    Expression<String>? kind,
    Expression<String>? privatePath,
    Expression<String>? state,
    Expression<DateTime>? deleteAfter,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (caseId != null) 'case_id': caseId,
      if (kind != null) 'kind': kind,
      if (privatePath != null) 'private_path': privatePath,
      if (state != null) 'state': state,
      if (deleteAfter != null) 'delete_after': deleteAfter,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BillingCaseArtifactsCompanion copyWith(
      {Value<int>? id,
      Value<int>? caseId,
      Value<String>? kind,
      Value<String>? privatePath,
      Value<String>? state,
      Value<DateTime?>? deleteAfter,
      Value<DateTime?>? deletedAt,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return BillingCaseArtifactsCompanion(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      kind: kind ?? this.kind,
      privatePath: privatePath ?? this.privatePath,
      state: state ?? this.state,
      deleteAfter: deleteAfter ?? this.deleteAfter,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (caseId.present) {
      map['case_id'] = Variable<int>(caseId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (privatePath.present) {
      map['private_path'] = Variable<String>(privatePath.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (deleteAfter.present) {
      map['delete_after'] = Variable<DateTime>(deleteAfter.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BillingCaseArtifactsCompanion(')
          ..write('id: $id, ')
          ..write('caseId: $caseId, ')
          ..write('kind: $kind, ')
          ..write('privatePath: $privatePath, ')
          ..write('state: $state, ')
          ..write('deleteAfter: $deleteAfter, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$BeeDatabase extends GeneratedDatabase {
  _$BeeDatabase(QueryExecutor e) : super(e);
  $BeeDatabaseManager get managers => $BeeDatabaseManager(this);
  late final $LedgersTable ledgers = $LedgersTable(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $RecurringTransactionsTable recurringTransactions =
      $RecurringTransactionsTable(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $TransactionTagsTable transactionTags =
      $TransactionTagsTable(this);
  late final $BudgetsTable budgets = $BudgetsTable(this);
  late final $TransactionAttachmentsTable transactionAttachments =
      $TransactionAttachmentsTable(this);
  late final $LocalChangesTable localChanges = $LocalChangesTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final $BillingJobsTable billingJobs = $BillingJobsTable(this);
  late final $BillingCasesTable billingCases = $BillingCasesTable(this);
  late final $BillingAutomationTasksTable billingAutomationTasks =
      $BillingAutomationTasksTable(this);
  late final $BillingUserTasksTable billingUserTasks =
      $BillingUserTasksTable(this);
  late final $BillingPreparedAttachmentsTable billingPreparedAttachments =
      $BillingPreparedAttachmentsTable(this);
  late final $BillingOutboxTable billingOutbox = $BillingOutboxTable(this);
  late final $BillingCaseArtifactsTable billingCaseArtifacts =
      $BillingCaseArtifactsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        ledgers,
        accounts,
        categories,
        transactions,
        recurringTransactions,
        conversations,
        messages,
        tags,
        transactionTags,
        budgets,
        transactionAttachments,
        localChanges,
        syncState,
        billingJobs,
        billingCases,
        billingAutomationTasks,
        billingUserTasks,
        billingPreparedAttachments,
        billingOutbox,
        billingCaseArtifacts
      ];
}

typedef $$LedgersTableCreateCompanionBuilder = LedgersCompanion Function({
  Value<int> id,
  required String name,
  Value<String> currency,
  Value<String> type,
  Value<DateTime> createdAt,
  Value<String?> syncId,
});
typedef $$LedgersTableUpdateCompanionBuilder = LedgersCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> currency,
  Value<String> type,
  Value<DateTime> createdAt,
  Value<String?> syncId,
});

class $$LedgersTableFilterComposer
    extends Composer<_$BeeDatabase, $LedgersTable> {
  $$LedgersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnFilters(column));
}

class $$LedgersTableOrderingComposer
    extends Composer<_$BeeDatabase, $LedgersTable> {
  $$LedgersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnOrderings(column));
}

class $$LedgersTableAnnotationComposer
    extends Composer<_$BeeDatabase, $LedgersTable> {
  $$LedgersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);
}

class $$LedgersTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $LedgersTable,
    Ledger,
    $$LedgersTableFilterComposer,
    $$LedgersTableOrderingComposer,
    $$LedgersTableAnnotationComposer,
    $$LedgersTableCreateCompanionBuilder,
    $$LedgersTableUpdateCompanionBuilder,
    (Ledger, BaseReferences<_$BeeDatabase, $LedgersTable, Ledger>),
    Ledger,
    PrefetchHooks Function()> {
  $$LedgersTableTableManager(_$BeeDatabase db, $LedgersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
          }) =>
              LedgersCompanion(
            id: id,
            name: name,
            currency: currency,
            type: type,
            createdAt: createdAt,
            syncId: syncId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String> currency = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
          }) =>
              LedgersCompanion.insert(
            id: id,
            name: name,
            currency: currency,
            type: type,
            createdAt: createdAt,
            syncId: syncId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LedgersTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $LedgersTable,
    Ledger,
    $$LedgersTableFilterComposer,
    $$LedgersTableOrderingComposer,
    $$LedgersTableAnnotationComposer,
    $$LedgersTableCreateCompanionBuilder,
    $$LedgersTableUpdateCompanionBuilder,
    (Ledger, BaseReferences<_$BeeDatabase, $LedgersTable, Ledger>),
    Ledger,
    PrefetchHooks Function()>;
typedef $$AccountsTableCreateCompanionBuilder = AccountsCompanion Function({
  Value<int> id,
  required int ledgerId,
  required String name,
  Value<String> type,
  Value<String> currency,
  Value<double> initialBalance,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<int> sortOrder,
  Value<double?> creditLimit,
  Value<int?> billingDay,
  Value<int?> paymentDueDay,
  Value<String?> bankName,
  Value<String?> cardLastFour,
  Value<String?> note,
  Value<String?> syncId,
});
typedef $$AccountsTableUpdateCompanionBuilder = AccountsCompanion Function({
  Value<int> id,
  Value<int> ledgerId,
  Value<String> name,
  Value<String> type,
  Value<String> currency,
  Value<double> initialBalance,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<int> sortOrder,
  Value<double?> creditLimit,
  Value<int?> billingDay,
  Value<int?> paymentDueDay,
  Value<String?> bankName,
  Value<String?> cardLastFour,
  Value<String?> note,
  Value<String?> syncId,
});

class $$AccountsTableFilterComposer
    extends Composer<_$BeeDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get initialBalance => $composableBuilder(
      column: $table.initialBalance,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get creditLimit => $composableBuilder(
      column: $table.creditLimit, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get billingDay => $composableBuilder(
      column: $table.billingDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get paymentDueDay => $composableBuilder(
      column: $table.paymentDueDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bankName => $composableBuilder(
      column: $table.bankName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cardLastFour => $composableBuilder(
      column: $table.cardLastFour, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnFilters(column));
}

class $$AccountsTableOrderingComposer
    extends Composer<_$BeeDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get initialBalance => $composableBuilder(
      column: $table.initialBalance,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get creditLimit => $composableBuilder(
      column: $table.creditLimit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get billingDay => $composableBuilder(
      column: $table.billingDay, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get paymentDueDay => $composableBuilder(
      column: $table.paymentDueDay,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bankName => $composableBuilder(
      column: $table.bankName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cardLastFour => $composableBuilder(
      column: $table.cardLastFour,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnOrderings(column));
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<double> get initialBalance => $composableBuilder(
      column: $table.initialBalance, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<double> get creditLimit => $composableBuilder(
      column: $table.creditLimit, builder: (column) => column);

  GeneratedColumn<int> get billingDay => $composableBuilder(
      column: $table.billingDay, builder: (column) => column);

  GeneratedColumn<int> get paymentDueDay => $composableBuilder(
      column: $table.paymentDueDay, builder: (column) => column);

  GeneratedColumn<String> get bankName =>
      $composableBuilder(column: $table.bankName, builder: (column) => column);

  GeneratedColumn<String> get cardLastFour => $composableBuilder(
      column: $table.cardLastFour, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);
}

class $$AccountsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $AccountsTable,
    Account,
    $$AccountsTableFilterComposer,
    $$AccountsTableOrderingComposer,
    $$AccountsTableAnnotationComposer,
    $$AccountsTableCreateCompanionBuilder,
    $$AccountsTableUpdateCompanionBuilder,
    (Account, BaseReferences<_$BeeDatabase, $AccountsTable, Account>),
    Account,
    PrefetchHooks Function()> {
  $$AccountsTableTableManager(_$BeeDatabase db, $AccountsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> ledgerId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<double> initialBalance = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<double?> creditLimit = const Value.absent(),
            Value<int?> billingDay = const Value.absent(),
            Value<int?> paymentDueDay = const Value.absent(),
            Value<String?> bankName = const Value.absent(),
            Value<String?> cardLastFour = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
          }) =>
              AccountsCompanion(
            id: id,
            ledgerId: ledgerId,
            name: name,
            type: type,
            currency: currency,
            initialBalance: initialBalance,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sortOrder: sortOrder,
            creditLimit: creditLimit,
            billingDay: billingDay,
            paymentDueDay: paymentDueDay,
            bankName: bankName,
            cardLastFour: cardLastFour,
            note: note,
            syncId: syncId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int ledgerId,
            required String name,
            Value<String> type = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<double> initialBalance = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<double?> creditLimit = const Value.absent(),
            Value<int?> billingDay = const Value.absent(),
            Value<int?> paymentDueDay = const Value.absent(),
            Value<String?> bankName = const Value.absent(),
            Value<String?> cardLastFour = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
          }) =>
              AccountsCompanion.insert(
            id: id,
            ledgerId: ledgerId,
            name: name,
            type: type,
            currency: currency,
            initialBalance: initialBalance,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sortOrder: sortOrder,
            creditLimit: creditLimit,
            billingDay: billingDay,
            paymentDueDay: paymentDueDay,
            bankName: bankName,
            cardLastFour: cardLastFour,
            note: note,
            syncId: syncId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AccountsTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $AccountsTable,
    Account,
    $$AccountsTableFilterComposer,
    $$AccountsTableOrderingComposer,
    $$AccountsTableAnnotationComposer,
    $$AccountsTableCreateCompanionBuilder,
    $$AccountsTableUpdateCompanionBuilder,
    (Account, BaseReferences<_$BeeDatabase, $AccountsTable, Account>),
    Account,
    PrefetchHooks Function()>;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  required String name,
  required String kind,
  Value<String?> icon,
  Value<int> sortOrder,
  Value<int?> parentId,
  Value<int> level,
  Value<String> iconType,
  Value<String?> customIconPath,
  Value<String?> communityIconId,
  Value<String?> syncId,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> kind,
  Value<String?> icon,
  Value<int> sortOrder,
  Value<int?> parentId,
  Value<int> level,
  Value<String> iconType,
  Value<String?> customIconPath,
  Value<String?> communityIconId,
  Value<String?> syncId,
});

class $$CategoriesTableFilterComposer
    extends Composer<_$BeeDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconType => $composableBuilder(
      column: $table.iconType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customIconPath => $composableBuilder(
      column: $table.customIconPath,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get communityIconId => $composableBuilder(
      column: $table.communityIconId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnFilters(column));
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$BeeDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconType => $composableBuilder(
      column: $table.iconType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customIconPath => $composableBuilder(
      column: $table.customIconPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get communityIconId => $composableBuilder(
      column: $table.communityIconId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnOrderings(column));
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$BeeDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get iconType =>
      $composableBuilder(column: $table.iconType, builder: (column) => column);

  GeneratedColumn<String> get customIconPath => $composableBuilder(
      column: $table.customIconPath, builder: (column) => column);

  GeneratedColumn<String> get communityIconId => $composableBuilder(
      column: $table.communityIconId, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);
}

class $$CategoriesTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $CategoriesTable,
    Category,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (Category, BaseReferences<_$BeeDatabase, $CategoriesTable, Category>),
    Category,
    PrefetchHooks Function()> {
  $$CategoriesTableTableManager(_$BeeDatabase db, $CategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String?> icon = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int?> parentId = const Value.absent(),
            Value<int> level = const Value.absent(),
            Value<String> iconType = const Value.absent(),
            Value<String?> customIconPath = const Value.absent(),
            Value<String?> communityIconId = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
          }) =>
              CategoriesCompanion(
            id: id,
            name: name,
            kind: kind,
            icon: icon,
            sortOrder: sortOrder,
            parentId: parentId,
            level: level,
            iconType: iconType,
            customIconPath: customIconPath,
            communityIconId: communityIconId,
            syncId: syncId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required String kind,
            Value<String?> icon = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int?> parentId = const Value.absent(),
            Value<int> level = const Value.absent(),
            Value<String> iconType = const Value.absent(),
            Value<String?> customIconPath = const Value.absent(),
            Value<String?> communityIconId = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
          }) =>
              CategoriesCompanion.insert(
            id: id,
            name: name,
            kind: kind,
            icon: icon,
            sortOrder: sortOrder,
            parentId: parentId,
            level: level,
            iconType: iconType,
            customIconPath: customIconPath,
            communityIconId: communityIconId,
            syncId: syncId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CategoriesTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $CategoriesTable,
    Category,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (Category, BaseReferences<_$BeeDatabase, $CategoriesTable, Category>),
    Category,
    PrefetchHooks Function()>;
typedef $$TransactionsTableCreateCompanionBuilder = TransactionsCompanion
    Function({
  Value<int> id,
  required int ledgerId,
  required String type,
  required double amount,
  Value<int?> categoryId,
  Value<int?> accountId,
  Value<int?> toAccountId,
  Value<DateTime> happenedAt,
  Value<String?> note,
  Value<String?> paymentMethod,
  Value<String?> counterparty,
  Value<String?> paymentChannel,
  Value<String?> merchantFullName,
  Value<String?> acquirer,
  Value<String?> detailsText,
  Value<double?> discountAmount,
  Value<bool> needsClassification,
  Value<int?> recurringId,
  Value<String?> syncId,
});
typedef $$TransactionsTableUpdateCompanionBuilder = TransactionsCompanion
    Function({
  Value<int> id,
  Value<int> ledgerId,
  Value<String> type,
  Value<double> amount,
  Value<int?> categoryId,
  Value<int?> accountId,
  Value<int?> toAccountId,
  Value<DateTime> happenedAt,
  Value<String?> note,
  Value<String?> paymentMethod,
  Value<String?> counterparty,
  Value<String?> paymentChannel,
  Value<String?> merchantFullName,
  Value<String?> acquirer,
  Value<String?> detailsText,
  Value<double?> discountAmount,
  Value<bool> needsClassification,
  Value<int?> recurringId,
  Value<String?> syncId,
});

class $$TransactionsTableFilterComposer
    extends Composer<_$BeeDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get toAccountId => $composableBuilder(
      column: $table.toAccountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get happenedAt => $composableBuilder(
      column: $table.happenedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get counterparty => $composableBuilder(
      column: $table.counterparty, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get paymentChannel => $composableBuilder(
      column: $table.paymentChannel,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get merchantFullName => $composableBuilder(
      column: $table.merchantFullName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get acquirer => $composableBuilder(
      column: $table.acquirer, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get detailsText => $composableBuilder(
      column: $table.detailsText, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get discountAmount => $composableBuilder(
      column: $table.discountAmount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get needsClassification => $composableBuilder(
      column: $table.needsClassification,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get recurringId => $composableBuilder(
      column: $table.recurringId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnFilters(column));
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$BeeDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get toAccountId => $composableBuilder(
      column: $table.toAccountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get happenedAt => $composableBuilder(
      column: $table.happenedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get counterparty => $composableBuilder(
      column: $table.counterparty,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get paymentChannel => $composableBuilder(
      column: $table.paymentChannel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get merchantFullName => $composableBuilder(
      column: $table.merchantFullName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get acquirer => $composableBuilder(
      column: $table.acquirer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get detailsText => $composableBuilder(
      column: $table.detailsText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get discountAmount => $composableBuilder(
      column: $table.discountAmount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get needsClassification => $composableBuilder(
      column: $table.needsClassification,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get recurringId => $composableBuilder(
      column: $table.recurringId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnOrderings(column));
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<int> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get toAccountId => $composableBuilder(
      column: $table.toAccountId, builder: (column) => column);

  GeneratedColumn<DateTime> get happenedAt => $composableBuilder(
      column: $table.happenedAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod, builder: (column) => column);

  GeneratedColumn<String> get counterparty => $composableBuilder(
      column: $table.counterparty, builder: (column) => column);

  GeneratedColumn<String> get paymentChannel => $composableBuilder(
      column: $table.paymentChannel, builder: (column) => column);

  GeneratedColumn<String> get merchantFullName => $composableBuilder(
      column: $table.merchantFullName, builder: (column) => column);

  GeneratedColumn<String> get acquirer =>
      $composableBuilder(column: $table.acquirer, builder: (column) => column);

  GeneratedColumn<String> get detailsText => $composableBuilder(
      column: $table.detailsText, builder: (column) => column);

  GeneratedColumn<double> get discountAmount => $composableBuilder(
      column: $table.discountAmount, builder: (column) => column);

  GeneratedColumn<bool> get needsClassification => $composableBuilder(
      column: $table.needsClassification, builder: (column) => column);

  GeneratedColumn<int> get recurringId => $composableBuilder(
      column: $table.recurringId, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);
}

class $$TransactionsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $TransactionsTable,
    Transaction,
    $$TransactionsTableFilterComposer,
    $$TransactionsTableOrderingComposer,
    $$TransactionsTableAnnotationComposer,
    $$TransactionsTableCreateCompanionBuilder,
    $$TransactionsTableUpdateCompanionBuilder,
    (
      Transaction,
      BaseReferences<_$BeeDatabase, $TransactionsTable, Transaction>
    ),
    Transaction,
    PrefetchHooks Function()> {
  $$TransactionsTableTableManager(_$BeeDatabase db, $TransactionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> ledgerId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<int?> categoryId = const Value.absent(),
            Value<int?> accountId = const Value.absent(),
            Value<int?> toAccountId = const Value.absent(),
            Value<DateTime> happenedAt = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> paymentMethod = const Value.absent(),
            Value<String?> counterparty = const Value.absent(),
            Value<String?> paymentChannel = const Value.absent(),
            Value<String?> merchantFullName = const Value.absent(),
            Value<String?> acquirer = const Value.absent(),
            Value<String?> detailsText = const Value.absent(),
            Value<double?> discountAmount = const Value.absent(),
            Value<bool> needsClassification = const Value.absent(),
            Value<int?> recurringId = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
          }) =>
              TransactionsCompanion(
            id: id,
            ledgerId: ledgerId,
            type: type,
            amount: amount,
            categoryId: categoryId,
            accountId: accountId,
            toAccountId: toAccountId,
            happenedAt: happenedAt,
            note: note,
            paymentMethod: paymentMethod,
            counterparty: counterparty,
            paymentChannel: paymentChannel,
            merchantFullName: merchantFullName,
            acquirer: acquirer,
            detailsText: detailsText,
            discountAmount: discountAmount,
            needsClassification: needsClassification,
            recurringId: recurringId,
            syncId: syncId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int ledgerId,
            required String type,
            required double amount,
            Value<int?> categoryId = const Value.absent(),
            Value<int?> accountId = const Value.absent(),
            Value<int?> toAccountId = const Value.absent(),
            Value<DateTime> happenedAt = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> paymentMethod = const Value.absent(),
            Value<String?> counterparty = const Value.absent(),
            Value<String?> paymentChannel = const Value.absent(),
            Value<String?> merchantFullName = const Value.absent(),
            Value<String?> acquirer = const Value.absent(),
            Value<String?> detailsText = const Value.absent(),
            Value<double?> discountAmount = const Value.absent(),
            Value<bool> needsClassification = const Value.absent(),
            Value<int?> recurringId = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
          }) =>
              TransactionsCompanion.insert(
            id: id,
            ledgerId: ledgerId,
            type: type,
            amount: amount,
            categoryId: categoryId,
            accountId: accountId,
            toAccountId: toAccountId,
            happenedAt: happenedAt,
            note: note,
            paymentMethod: paymentMethod,
            counterparty: counterparty,
            paymentChannel: paymentChannel,
            merchantFullName: merchantFullName,
            acquirer: acquirer,
            detailsText: detailsText,
            discountAmount: discountAmount,
            needsClassification: needsClassification,
            recurringId: recurringId,
            syncId: syncId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TransactionsTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $TransactionsTable,
    Transaction,
    $$TransactionsTableFilterComposer,
    $$TransactionsTableOrderingComposer,
    $$TransactionsTableAnnotationComposer,
    $$TransactionsTableCreateCompanionBuilder,
    $$TransactionsTableUpdateCompanionBuilder,
    (
      Transaction,
      BaseReferences<_$BeeDatabase, $TransactionsTable, Transaction>
    ),
    Transaction,
    PrefetchHooks Function()>;
typedef $$RecurringTransactionsTableCreateCompanionBuilder
    = RecurringTransactionsCompanion Function({
  Value<int> id,
  required int ledgerId,
  required String type,
  required double amount,
  Value<int?> categoryId,
  Value<int?> accountId,
  Value<int?> toAccountId,
  Value<String?> note,
  required String frequency,
  Value<int> interval,
  Value<int?> dayOfMonth,
  Value<int?> dayOfWeek,
  Value<int?> monthOfYear,
  required DateTime startDate,
  Value<DateTime?> endDate,
  Value<DateTime?> lastGeneratedDate,
  Value<bool> enabled,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$RecurringTransactionsTableUpdateCompanionBuilder
    = RecurringTransactionsCompanion Function({
  Value<int> id,
  Value<int> ledgerId,
  Value<String> type,
  Value<double> amount,
  Value<int?> categoryId,
  Value<int?> accountId,
  Value<int?> toAccountId,
  Value<String?> note,
  Value<String> frequency,
  Value<int> interval,
  Value<int?> dayOfMonth,
  Value<int?> dayOfWeek,
  Value<int?> monthOfYear,
  Value<DateTime> startDate,
  Value<DateTime?> endDate,
  Value<DateTime?> lastGeneratedDate,
  Value<bool> enabled,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$RecurringTransactionsTableFilterComposer
    extends Composer<_$BeeDatabase, $RecurringTransactionsTable> {
  $$RecurringTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get toAccountId => $composableBuilder(
      column: $table.toAccountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get frequency => $composableBuilder(
      column: $table.frequency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get interval => $composableBuilder(
      column: $table.interval, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dayOfMonth => $composableBuilder(
      column: $table.dayOfMonth, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dayOfWeek => $composableBuilder(
      column: $table.dayOfWeek, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get monthOfYear => $composableBuilder(
      column: $table.monthOfYear, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endDate => $composableBuilder(
      column: $table.endDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastGeneratedDate => $composableBuilder(
      column: $table.lastGeneratedDate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$RecurringTransactionsTableOrderingComposer
    extends Composer<_$BeeDatabase, $RecurringTransactionsTable> {
  $$RecurringTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get toAccountId => $composableBuilder(
      column: $table.toAccountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get frequency => $composableBuilder(
      column: $table.frequency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get interval => $composableBuilder(
      column: $table.interval, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dayOfMonth => $composableBuilder(
      column: $table.dayOfMonth, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dayOfWeek => $composableBuilder(
      column: $table.dayOfWeek, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get monthOfYear => $composableBuilder(
      column: $table.monthOfYear, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
      column: $table.endDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastGeneratedDate => $composableBuilder(
      column: $table.lastGeneratedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$RecurringTransactionsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $RecurringTransactionsTable> {
  $$RecurringTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<int> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get toAccountId => $composableBuilder(
      column: $table.toAccountId, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<int> get interval =>
      $composableBuilder(column: $table.interval, builder: (column) => column);

  GeneratedColumn<int> get dayOfMonth => $composableBuilder(
      column: $table.dayOfMonth, builder: (column) => column);

  GeneratedColumn<int> get dayOfWeek =>
      $composableBuilder(column: $table.dayOfWeek, builder: (column) => column);

  GeneratedColumn<int> get monthOfYear => $composableBuilder(
      column: $table.monthOfYear, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<DateTime> get lastGeneratedDate => $composableBuilder(
      column: $table.lastGeneratedDate, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RecurringTransactionsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $RecurringTransactionsTable,
    RecurringTransaction,
    $$RecurringTransactionsTableFilterComposer,
    $$RecurringTransactionsTableOrderingComposer,
    $$RecurringTransactionsTableAnnotationComposer,
    $$RecurringTransactionsTableCreateCompanionBuilder,
    $$RecurringTransactionsTableUpdateCompanionBuilder,
    (
      RecurringTransaction,
      BaseReferences<_$BeeDatabase, $RecurringTransactionsTable,
          RecurringTransaction>
    ),
    RecurringTransaction,
    PrefetchHooks Function()> {
  $$RecurringTransactionsTableTableManager(
      _$BeeDatabase db, $RecurringTransactionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecurringTransactionsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$RecurringTransactionsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecurringTransactionsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> ledgerId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<int?> categoryId = const Value.absent(),
            Value<int?> accountId = const Value.absent(),
            Value<int?> toAccountId = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String> frequency = const Value.absent(),
            Value<int> interval = const Value.absent(),
            Value<int?> dayOfMonth = const Value.absent(),
            Value<int?> dayOfWeek = const Value.absent(),
            Value<int?> monthOfYear = const Value.absent(),
            Value<DateTime> startDate = const Value.absent(),
            Value<DateTime?> endDate = const Value.absent(),
            Value<DateTime?> lastGeneratedDate = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              RecurringTransactionsCompanion(
            id: id,
            ledgerId: ledgerId,
            type: type,
            amount: amount,
            categoryId: categoryId,
            accountId: accountId,
            toAccountId: toAccountId,
            note: note,
            frequency: frequency,
            interval: interval,
            dayOfMonth: dayOfMonth,
            dayOfWeek: dayOfWeek,
            monthOfYear: monthOfYear,
            startDate: startDate,
            endDate: endDate,
            lastGeneratedDate: lastGeneratedDate,
            enabled: enabled,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int ledgerId,
            required String type,
            required double amount,
            Value<int?> categoryId = const Value.absent(),
            Value<int?> accountId = const Value.absent(),
            Value<int?> toAccountId = const Value.absent(),
            Value<String?> note = const Value.absent(),
            required String frequency,
            Value<int> interval = const Value.absent(),
            Value<int?> dayOfMonth = const Value.absent(),
            Value<int?> dayOfWeek = const Value.absent(),
            Value<int?> monthOfYear = const Value.absent(),
            required DateTime startDate,
            Value<DateTime?> endDate = const Value.absent(),
            Value<DateTime?> lastGeneratedDate = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              RecurringTransactionsCompanion.insert(
            id: id,
            ledgerId: ledgerId,
            type: type,
            amount: amount,
            categoryId: categoryId,
            accountId: accountId,
            toAccountId: toAccountId,
            note: note,
            frequency: frequency,
            interval: interval,
            dayOfMonth: dayOfMonth,
            dayOfWeek: dayOfWeek,
            monthOfYear: monthOfYear,
            startDate: startDate,
            endDate: endDate,
            lastGeneratedDate: lastGeneratedDate,
            enabled: enabled,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RecurringTransactionsTableProcessedTableManager
    = ProcessedTableManager<
        _$BeeDatabase,
        $RecurringTransactionsTable,
        RecurringTransaction,
        $$RecurringTransactionsTableFilterComposer,
        $$RecurringTransactionsTableOrderingComposer,
        $$RecurringTransactionsTableAnnotationComposer,
        $$RecurringTransactionsTableCreateCompanionBuilder,
        $$RecurringTransactionsTableUpdateCompanionBuilder,
        (
          RecurringTransaction,
          BaseReferences<_$BeeDatabase, $RecurringTransactionsTable,
              RecurringTransaction>
        ),
        RecurringTransaction,
        PrefetchHooks Function()>;
typedef $$ConversationsTableCreateCompanionBuilder = ConversationsCompanion
    Function({
  Value<int> id,
  Value<int?> ledgerId,
  Value<String> title,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$ConversationsTableUpdateCompanionBuilder = ConversationsCompanion
    Function({
  Value<int> id,
  Value<int?> ledgerId,
  Value<String> title,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$ConversationsTableFilterComposer
    extends Composer<_$BeeDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$BeeDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ConversationsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $ConversationsTable,
    Conversation,
    $$ConversationsTableFilterComposer,
    $$ConversationsTableOrderingComposer,
    $$ConversationsTableAnnotationComposer,
    $$ConversationsTableCreateCompanionBuilder,
    $$ConversationsTableUpdateCompanionBuilder,
    (
      Conversation,
      BaseReferences<_$BeeDatabase, $ConversationsTable, Conversation>
    ),
    Conversation,
    PrefetchHooks Function()> {
  $$ConversationsTableTableManager(_$BeeDatabase db, $ConversationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> ledgerId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              ConversationsCompanion(
            id: id,
            ledgerId: ledgerId,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> ledgerId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              ConversationsCompanion.insert(
            id: id,
            ledgerId: ledgerId,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ConversationsTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $ConversationsTable,
    Conversation,
    $$ConversationsTableFilterComposer,
    $$ConversationsTableOrderingComposer,
    $$ConversationsTableAnnotationComposer,
    $$ConversationsTableCreateCompanionBuilder,
    $$ConversationsTableUpdateCompanionBuilder,
    (
      Conversation,
      BaseReferences<_$BeeDatabase, $ConversationsTable, Conversation>
    ),
    Conversation,
    PrefetchHooks Function()>;
typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  required int conversationId,
  required String role,
  required String content,
  required String messageType,
  Value<String?> metadata,
  Value<int?> transactionId,
  Value<DateTime> createdAt,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  Value<int> conversationId,
  Value<String> role,
  Value<String> content,
  Value<String> messageType,
  Value<String?> metadata,
  Value<int?> transactionId,
  Value<DateTime> createdAt,
});

class $$MessagesTableFilterComposer
    extends Composer<_$BeeDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get metadata => $composableBuilder(
      column: $table.metadata, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$MessagesTableOrderingComposer
    extends Composer<_$BeeDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get metadata => $composableBuilder(
      column: $table.metadata, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get transactionId => $composableBuilder(
      column: $table.transactionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$BeeDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get conversationId => $composableBuilder(
      column: $table.conversationId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<int> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MessagesTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $MessagesTable,
    Message,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (Message, BaseReferences<_$BeeDatabase, $MessagesTable, Message>),
    Message,
    PrefetchHooks Function()> {
  $$MessagesTableTableManager(_$BeeDatabase db, $MessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> conversationId = const Value.absent(),
            Value<String> role = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String> messageType = const Value.absent(),
            Value<String?> metadata = const Value.absent(),
            Value<int?> transactionId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              MessagesCompanion(
            id: id,
            conversationId: conversationId,
            role: role,
            content: content,
            messageType: messageType,
            metadata: metadata,
            transactionId: transactionId,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int conversationId,
            required String role,
            required String content,
            required String messageType,
            Value<String?> metadata = const Value.absent(),
            Value<int?> transactionId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              MessagesCompanion.insert(
            id: id,
            conversationId: conversationId,
            role: role,
            content: content,
            messageType: messageType,
            metadata: metadata,
            transactionId: transactionId,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MessagesTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $MessagesTable,
    Message,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (Message, BaseReferences<_$BeeDatabase, $MessagesTable, Message>),
    Message,
    PrefetchHooks Function()>;
typedef $$TagsTableCreateCompanionBuilder = TagsCompanion Function({
  Value<int> id,
  required String name,
  Value<String?> color,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
  Value<String?> syncId,
});
typedef $$TagsTableUpdateCompanionBuilder = TagsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> color,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
  Value<String?> syncId,
});

class $$TagsTableFilterComposer extends Composer<_$BeeDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnFilters(column));
}

class $$TagsTableOrderingComposer extends Composer<_$BeeDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnOrderings(column));
}

class $$TagsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);
}

class $$TagsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $TagsTable,
    Tag,
    $$TagsTableFilterComposer,
    $$TagsTableOrderingComposer,
    $$TagsTableAnnotationComposer,
    $$TagsTableCreateCompanionBuilder,
    $$TagsTableUpdateCompanionBuilder,
    (Tag, BaseReferences<_$BeeDatabase, $TagsTable, Tag>),
    Tag,
    PrefetchHooks Function()> {
  $$TagsTableTableManager(_$BeeDatabase db, $TagsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
          }) =>
              TagsCompanion(
            id: id,
            name: name,
            color: color,
            sortOrder: sortOrder,
            createdAt: createdAt,
            syncId: syncId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String?> color = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
          }) =>
              TagsCompanion.insert(
            id: id,
            name: name,
            color: color,
            sortOrder: sortOrder,
            createdAt: createdAt,
            syncId: syncId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TagsTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $TagsTable,
    Tag,
    $$TagsTableFilterComposer,
    $$TagsTableOrderingComposer,
    $$TagsTableAnnotationComposer,
    $$TagsTableCreateCompanionBuilder,
    $$TagsTableUpdateCompanionBuilder,
    (Tag, BaseReferences<_$BeeDatabase, $TagsTable, Tag>),
    Tag,
    PrefetchHooks Function()>;
typedef $$TransactionTagsTableCreateCompanionBuilder = TransactionTagsCompanion
    Function({
  Value<int> id,
  required int transactionId,
  required int tagId,
});
typedef $$TransactionTagsTableUpdateCompanionBuilder = TransactionTagsCompanion
    Function({
  Value<int> id,
  Value<int> transactionId,
  Value<int> tagId,
});

class $$TransactionTagsTableFilterComposer
    extends Composer<_$BeeDatabase, $TransactionTagsTable> {
  $$TransactionTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tagId => $composableBuilder(
      column: $table.tagId, builder: (column) => ColumnFilters(column));
}

class $$TransactionTagsTableOrderingComposer
    extends Composer<_$BeeDatabase, $TransactionTagsTable> {
  $$TransactionTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get transactionId => $composableBuilder(
      column: $table.transactionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tagId => $composableBuilder(
      column: $table.tagId, builder: (column) => ColumnOrderings(column));
}

class $$TransactionTagsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $TransactionTagsTable> {
  $$TransactionTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => column);

  GeneratedColumn<int> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);
}

class $$TransactionTagsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $TransactionTagsTable,
    TransactionTag,
    $$TransactionTagsTableFilterComposer,
    $$TransactionTagsTableOrderingComposer,
    $$TransactionTagsTableAnnotationComposer,
    $$TransactionTagsTableCreateCompanionBuilder,
    $$TransactionTagsTableUpdateCompanionBuilder,
    (
      TransactionTag,
      BaseReferences<_$BeeDatabase, $TransactionTagsTable, TransactionTag>
    ),
    TransactionTag,
    PrefetchHooks Function()> {
  $$TransactionTagsTableTableManager(
      _$BeeDatabase db, $TransactionTagsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> transactionId = const Value.absent(),
            Value<int> tagId = const Value.absent(),
          }) =>
              TransactionTagsCompanion(
            id: id,
            transactionId: transactionId,
            tagId: tagId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int transactionId,
            required int tagId,
          }) =>
              TransactionTagsCompanion.insert(
            id: id,
            transactionId: transactionId,
            tagId: tagId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TransactionTagsTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $TransactionTagsTable,
    TransactionTag,
    $$TransactionTagsTableFilterComposer,
    $$TransactionTagsTableOrderingComposer,
    $$TransactionTagsTableAnnotationComposer,
    $$TransactionTagsTableCreateCompanionBuilder,
    $$TransactionTagsTableUpdateCompanionBuilder,
    (
      TransactionTag,
      BaseReferences<_$BeeDatabase, $TransactionTagsTable, TransactionTag>
    ),
    TransactionTag,
    PrefetchHooks Function()>;
typedef $$BudgetsTableCreateCompanionBuilder = BudgetsCompanion Function({
  Value<int> id,
  Value<String?> syncId,
  required int ledgerId,
  Value<String> type,
  Value<int?> categoryId,
  required double amount,
  Value<String> period,
  Value<int> startDay,
  Value<bool> enabled,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$BudgetsTableUpdateCompanionBuilder = BudgetsCompanion Function({
  Value<int> id,
  Value<String?> syncId,
  Value<int> ledgerId,
  Value<String> type,
  Value<int?> categoryId,
  Value<double> amount,
  Value<String> period,
  Value<int> startDay,
  Value<bool> enabled,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$BudgetsTableFilterComposer
    extends Composer<_$BeeDatabase, $BudgetsTable> {
  $$BudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get period => $composableBuilder(
      column: $table.period, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startDay => $composableBuilder(
      column: $table.startDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$BudgetsTableOrderingComposer
    extends Composer<_$BeeDatabase, $BudgetsTable> {
  $$BudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncId => $composableBuilder(
      column: $table.syncId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get period => $composableBuilder(
      column: $table.period, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startDay => $composableBuilder(
      column: $table.startDay, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$BudgetsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $BudgetsTable> {
  $$BudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<int> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get period =>
      $composableBuilder(column: $table.period, builder: (column) => column);

  GeneratedColumn<int> get startDay =>
      $composableBuilder(column: $table.startDay, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BudgetsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $BudgetsTable,
    Budget,
    $$BudgetsTableFilterComposer,
    $$BudgetsTableOrderingComposer,
    $$BudgetsTableAnnotationComposer,
    $$BudgetsTableCreateCompanionBuilder,
    $$BudgetsTableUpdateCompanionBuilder,
    (Budget, BaseReferences<_$BeeDatabase, $BudgetsTable, Budget>),
    Budget,
    PrefetchHooks Function()> {
  $$BudgetsTableTableManager(_$BeeDatabase db, $BudgetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
            Value<int> ledgerId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<int?> categoryId = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<String> period = const Value.absent(),
            Value<int> startDay = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              BudgetsCompanion(
            id: id,
            syncId: syncId,
            ledgerId: ledgerId,
            type: type,
            categoryId: categoryId,
            amount: amount,
            period: period,
            startDay: startDay,
            enabled: enabled,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> syncId = const Value.absent(),
            required int ledgerId,
            Value<String> type = const Value.absent(),
            Value<int?> categoryId = const Value.absent(),
            required double amount,
            Value<String> period = const Value.absent(),
            Value<int> startDay = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              BudgetsCompanion.insert(
            id: id,
            syncId: syncId,
            ledgerId: ledgerId,
            type: type,
            categoryId: categoryId,
            amount: amount,
            period: period,
            startDay: startDay,
            enabled: enabled,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BudgetsTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $BudgetsTable,
    Budget,
    $$BudgetsTableFilterComposer,
    $$BudgetsTableOrderingComposer,
    $$BudgetsTableAnnotationComposer,
    $$BudgetsTableCreateCompanionBuilder,
    $$BudgetsTableUpdateCompanionBuilder,
    (Budget, BaseReferences<_$BeeDatabase, $BudgetsTable, Budget>),
    Budget,
    PrefetchHooks Function()>;
typedef $$TransactionAttachmentsTableCreateCompanionBuilder
    = TransactionAttachmentsCompanion Function({
  Value<int> id,
  required int transactionId,
  required String fileName,
  Value<String?> originKey,
  Value<String?> originalName,
  Value<int?> fileSize,
  Value<int?> width,
  Value<int?> height,
  Value<int> sortOrder,
  Value<String?> cloudFileId,
  Value<String?> cloudSha256,
  Value<DateTime> createdAt,
});
typedef $$TransactionAttachmentsTableUpdateCompanionBuilder
    = TransactionAttachmentsCompanion Function({
  Value<int> id,
  Value<int> transactionId,
  Value<String> fileName,
  Value<String?> originKey,
  Value<String?> originalName,
  Value<int?> fileSize,
  Value<int?> width,
  Value<int?> height,
  Value<int> sortOrder,
  Value<String?> cloudFileId,
  Value<String?> cloudSha256,
  Value<DateTime> createdAt,
});

class $$TransactionAttachmentsTableFilterComposer
    extends Composer<_$BeeDatabase, $TransactionAttachmentsTable> {
  $$TransactionAttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fileName => $composableBuilder(
      column: $table.fileName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get originKey => $composableBuilder(
      column: $table.originKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get originalName => $composableBuilder(
      column: $table.originalName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fileSize => $composableBuilder(
      column: $table.fileSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get width => $composableBuilder(
      column: $table.width, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get height => $composableBuilder(
      column: $table.height, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cloudFileId => $composableBuilder(
      column: $table.cloudFileId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cloudSha256 => $composableBuilder(
      column: $table.cloudSha256, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$TransactionAttachmentsTableOrderingComposer
    extends Composer<_$BeeDatabase, $TransactionAttachmentsTable> {
  $$TransactionAttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get transactionId => $composableBuilder(
      column: $table.transactionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fileName => $composableBuilder(
      column: $table.fileName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get originKey => $composableBuilder(
      column: $table.originKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get originalName => $composableBuilder(
      column: $table.originalName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fileSize => $composableBuilder(
      column: $table.fileSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get width => $composableBuilder(
      column: $table.width, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get height => $composableBuilder(
      column: $table.height, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cloudFileId => $composableBuilder(
      column: $table.cloudFileId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cloudSha256 => $composableBuilder(
      column: $table.cloudSha256, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$TransactionAttachmentsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $TransactionAttachmentsTable> {
  $$TransactionAttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get originKey =>
      $composableBuilder(column: $table.originKey, builder: (column) => column);

  GeneratedColumn<String> get originalName => $composableBuilder(
      column: $table.originalName, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get cloudFileId => $composableBuilder(
      column: $table.cloudFileId, builder: (column) => column);

  GeneratedColumn<String> get cloudSha256 => $composableBuilder(
      column: $table.cloudSha256, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TransactionAttachmentsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $TransactionAttachmentsTable,
    TransactionAttachment,
    $$TransactionAttachmentsTableFilterComposer,
    $$TransactionAttachmentsTableOrderingComposer,
    $$TransactionAttachmentsTableAnnotationComposer,
    $$TransactionAttachmentsTableCreateCompanionBuilder,
    $$TransactionAttachmentsTableUpdateCompanionBuilder,
    (
      TransactionAttachment,
      BaseReferences<_$BeeDatabase, $TransactionAttachmentsTable,
          TransactionAttachment>
    ),
    TransactionAttachment,
    PrefetchHooks Function()> {
  $$TransactionAttachmentsTableTableManager(
      _$BeeDatabase db, $TransactionAttachmentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionAttachmentsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionAttachmentsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionAttachmentsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> transactionId = const Value.absent(),
            Value<String> fileName = const Value.absent(),
            Value<String?> originKey = const Value.absent(),
            Value<String?> originalName = const Value.absent(),
            Value<int?> fileSize = const Value.absent(),
            Value<int?> width = const Value.absent(),
            Value<int?> height = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<String?> cloudFileId = const Value.absent(),
            Value<String?> cloudSha256 = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              TransactionAttachmentsCompanion(
            id: id,
            transactionId: transactionId,
            fileName: fileName,
            originKey: originKey,
            originalName: originalName,
            fileSize: fileSize,
            width: width,
            height: height,
            sortOrder: sortOrder,
            cloudFileId: cloudFileId,
            cloudSha256: cloudSha256,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int transactionId,
            required String fileName,
            Value<String?> originKey = const Value.absent(),
            Value<String?> originalName = const Value.absent(),
            Value<int?> fileSize = const Value.absent(),
            Value<int?> width = const Value.absent(),
            Value<int?> height = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<String?> cloudFileId = const Value.absent(),
            Value<String?> cloudSha256 = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              TransactionAttachmentsCompanion.insert(
            id: id,
            transactionId: transactionId,
            fileName: fileName,
            originKey: originKey,
            originalName: originalName,
            fileSize: fileSize,
            width: width,
            height: height,
            sortOrder: sortOrder,
            cloudFileId: cloudFileId,
            cloudSha256: cloudSha256,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TransactionAttachmentsTableProcessedTableManager
    = ProcessedTableManager<
        _$BeeDatabase,
        $TransactionAttachmentsTable,
        TransactionAttachment,
        $$TransactionAttachmentsTableFilterComposer,
        $$TransactionAttachmentsTableOrderingComposer,
        $$TransactionAttachmentsTableAnnotationComposer,
        $$TransactionAttachmentsTableCreateCompanionBuilder,
        $$TransactionAttachmentsTableUpdateCompanionBuilder,
        (
          TransactionAttachment,
          BaseReferences<_$BeeDatabase, $TransactionAttachmentsTable,
              TransactionAttachment>
        ),
        TransactionAttachment,
        PrefetchHooks Function()>;
typedef $$LocalChangesTableCreateCompanionBuilder = LocalChangesCompanion
    Function({
  Value<int> id,
  required String entityType,
  required int entityId,
  required String entitySyncId,
  required int ledgerId,
  required String action,
  Value<String?> payloadJson,
  Value<DateTime> createdAt,
  Value<DateTime?> pushedAt,
});
typedef $$LocalChangesTableUpdateCompanionBuilder = LocalChangesCompanion
    Function({
  Value<int> id,
  Value<String> entityType,
  Value<int> entityId,
  Value<String> entitySyncId,
  Value<int> ledgerId,
  Value<String> action,
  Value<String?> payloadJson,
  Value<DateTime> createdAt,
  Value<DateTime?> pushedAt,
});

class $$LocalChangesTableFilterComposer
    extends Composer<_$BeeDatabase, $LocalChangesTable> {
  $$LocalChangesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entitySyncId => $composableBuilder(
      column: $table.entitySyncId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get pushedAt => $composableBuilder(
      column: $table.pushedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalChangesTableOrderingComposer
    extends Composer<_$BeeDatabase, $LocalChangesTable> {
  $$LocalChangesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entitySyncId => $composableBuilder(
      column: $table.entitySyncId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get pushedAt => $composableBuilder(
      column: $table.pushedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalChangesTableAnnotationComposer
    extends Composer<_$BeeDatabase, $LocalChangesTable> {
  $$LocalChangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<int> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get entitySyncId => $composableBuilder(
      column: $table.entitySyncId, builder: (column) => column);

  GeneratedColumn<int> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get pushedAt =>
      $composableBuilder(column: $table.pushedAt, builder: (column) => column);
}

class $$LocalChangesTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $LocalChangesTable,
    LocalChange,
    $$LocalChangesTableFilterComposer,
    $$LocalChangesTableOrderingComposer,
    $$LocalChangesTableAnnotationComposer,
    $$LocalChangesTableCreateCompanionBuilder,
    $$LocalChangesTableUpdateCompanionBuilder,
    (
      LocalChange,
      BaseReferences<_$BeeDatabase, $LocalChangesTable, LocalChange>
    ),
    LocalChange,
    PrefetchHooks Function()> {
  $$LocalChangesTableTableManager(_$BeeDatabase db, $LocalChangesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalChangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalChangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalChangesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> entityType = const Value.absent(),
            Value<int> entityId = const Value.absent(),
            Value<String> entitySyncId = const Value.absent(),
            Value<int> ledgerId = const Value.absent(),
            Value<String> action = const Value.absent(),
            Value<String?> payloadJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> pushedAt = const Value.absent(),
          }) =>
              LocalChangesCompanion(
            id: id,
            entityType: entityType,
            entityId: entityId,
            entitySyncId: entitySyncId,
            ledgerId: ledgerId,
            action: action,
            payloadJson: payloadJson,
            createdAt: createdAt,
            pushedAt: pushedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String entityType,
            required int entityId,
            required String entitySyncId,
            required int ledgerId,
            required String action,
            Value<String?> payloadJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> pushedAt = const Value.absent(),
          }) =>
              LocalChangesCompanion.insert(
            id: id,
            entityType: entityType,
            entityId: entityId,
            entitySyncId: entitySyncId,
            ledgerId: ledgerId,
            action: action,
            payloadJson: payloadJson,
            createdAt: createdAt,
            pushedAt: pushedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalChangesTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $LocalChangesTable,
    LocalChange,
    $$LocalChangesTableFilterComposer,
    $$LocalChangesTableOrderingComposer,
    $$LocalChangesTableAnnotationComposer,
    $$LocalChangesTableCreateCompanionBuilder,
    $$LocalChangesTableUpdateCompanionBuilder,
    (
      LocalChange,
      BaseReferences<_$BeeDatabase, $LocalChangesTable, LocalChange>
    ),
    LocalChange,
    PrefetchHooks Function()>;
typedef $$SyncStateTableCreateCompanionBuilder = SyncStateCompanion Function({
  Value<int> id,
  required String deviceId,
  Value<String> providerType,
  Value<int> serverCursor,
  Value<DateTime?> lastPushAt,
  Value<DateTime?> lastPullAt,
});
typedef $$SyncStateTableUpdateCompanionBuilder = SyncStateCompanion Function({
  Value<int> id,
  Value<String> deviceId,
  Value<String> providerType,
  Value<int> serverCursor,
  Value<DateTime?> lastPushAt,
  Value<DateTime?> lastPullAt,
});

class $$SyncStateTableFilterComposer
    extends Composer<_$BeeDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get providerType => $composableBuilder(
      column: $table.providerType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get serverCursor => $composableBuilder(
      column: $table.serverCursor, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastPushAt => $composableBuilder(
      column: $table.lastPushAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastPullAt => $composableBuilder(
      column: $table.lastPullAt, builder: (column) => ColumnFilters(column));
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$BeeDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get providerType => $composableBuilder(
      column: $table.providerType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get serverCursor => $composableBuilder(
      column: $table.serverCursor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastPushAt => $composableBuilder(
      column: $table.lastPushAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastPullAt => $composableBuilder(
      column: $table.lastPullAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$BeeDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get providerType => $composableBuilder(
      column: $table.providerType, builder: (column) => column);

  GeneratedColumn<int> get serverCursor => $composableBuilder(
      column: $table.serverCursor, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPushAt => $composableBuilder(
      column: $table.lastPushAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPullAt => $composableBuilder(
      column: $table.lastPullAt, builder: (column) => column);
}

class $$SyncStateTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $SyncStateTable,
    SyncStateData,
    $$SyncStateTableFilterComposer,
    $$SyncStateTableOrderingComposer,
    $$SyncStateTableAnnotationComposer,
    $$SyncStateTableCreateCompanionBuilder,
    $$SyncStateTableUpdateCompanionBuilder,
    (
      SyncStateData,
      BaseReferences<_$BeeDatabase, $SyncStateTable, SyncStateData>
    ),
    SyncStateData,
    PrefetchHooks Function()> {
  $$SyncStateTableTableManager(_$BeeDatabase db, $SyncStateTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<String> providerType = const Value.absent(),
            Value<int> serverCursor = const Value.absent(),
            Value<DateTime?> lastPushAt = const Value.absent(),
            Value<DateTime?> lastPullAt = const Value.absent(),
          }) =>
              SyncStateCompanion(
            id: id,
            deviceId: deviceId,
            providerType: providerType,
            serverCursor: serverCursor,
            lastPushAt: lastPushAt,
            lastPullAt: lastPullAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String deviceId,
            Value<String> providerType = const Value.absent(),
            Value<int> serverCursor = const Value.absent(),
            Value<DateTime?> lastPushAt = const Value.absent(),
            Value<DateTime?> lastPullAt = const Value.absent(),
          }) =>
              SyncStateCompanion.insert(
            id: id,
            deviceId: deviceId,
            providerType: providerType,
            serverCursor: serverCursor,
            lastPushAt: lastPushAt,
            lastPullAt: lastPullAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncStateTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $SyncStateTable,
    SyncStateData,
    $$SyncStateTableFilterComposer,
    $$SyncStateTableOrderingComposer,
    $$SyncStateTableAnnotationComposer,
    $$SyncStateTableCreateCompanionBuilder,
    $$SyncStateTableUpdateCompanionBuilder,
    (
      SyncStateData,
      BaseReferences<_$BeeDatabase, $SyncStateTable, SyncStateData>
    ),
    SyncStateData,
    PrefetchHooks Function()>;
typedef $$BillingJobsTableCreateCompanionBuilder = BillingJobsCompanion
    Function({
  Value<int> id,
  Value<int?> ledgerId,
  Value<String> kind,
  Value<String> status,
  Value<String> stage,
  Value<int?> transactionId,
  required String imagePath,
  Value<String?> rawText,
  Value<String?> ocrEngine,
  Value<String?> sourceInfoJson,
  Value<String?> ruleResultJson,
  Value<int?> rulePackageVersion,
  Value<String?> rulesVersion,
  Value<int?> normalizationVersion,
  Value<int?> personalRulesRevision,
  Value<String?> ruleSnapshotStatus,
  Value<String?> finalResultJson,
  Value<int> attemptCount,
  Value<String?> lastError,
  Value<DateTime?> leaseUntil,
  Value<bool> attachmentDone,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> completedAt,
});
typedef $$BillingJobsTableUpdateCompanionBuilder = BillingJobsCompanion
    Function({
  Value<int> id,
  Value<int?> ledgerId,
  Value<String> kind,
  Value<String> status,
  Value<String> stage,
  Value<int?> transactionId,
  Value<String> imagePath,
  Value<String?> rawText,
  Value<String?> ocrEngine,
  Value<String?> sourceInfoJson,
  Value<String?> ruleResultJson,
  Value<int?> rulePackageVersion,
  Value<String?> rulesVersion,
  Value<int?> normalizationVersion,
  Value<int?> personalRulesRevision,
  Value<String?> ruleSnapshotStatus,
  Value<String?> finalResultJson,
  Value<int> attemptCount,
  Value<String?> lastError,
  Value<DateTime?> leaseUntil,
  Value<bool> attachmentDone,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> completedAt,
});

class $$BillingJobsTableFilterComposer
    extends Composer<_$BeeDatabase, $BillingJobsTable> {
  $$BillingJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stage => $composableBuilder(
      column: $table.stage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rawText => $composableBuilder(
      column: $table.rawText, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ocrEngine => $composableBuilder(
      column: $table.ocrEngine, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceInfoJson => $composableBuilder(
      column: $table.sourceInfoJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ruleResultJson => $composableBuilder(
      column: $table.ruleResultJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rulePackageVersion => $composableBuilder(
      column: $table.rulePackageVersion,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rulesVersion => $composableBuilder(
      column: $table.rulesVersion, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get normalizationVersion => $composableBuilder(
      column: $table.normalizationVersion,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get personalRulesRevision => $composableBuilder(
      column: $table.personalRulesRevision,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ruleSnapshotStatus => $composableBuilder(
      column: $table.ruleSnapshotStatus,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get finalResultJson => $composableBuilder(
      column: $table.finalResultJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get leaseUntil => $composableBuilder(
      column: $table.leaseUntil, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get attachmentDone => $composableBuilder(
      column: $table.attachmentDone,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));
}

class $$BillingJobsTableOrderingComposer
    extends Composer<_$BeeDatabase, $BillingJobsTable> {
  $$BillingJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stage => $composableBuilder(
      column: $table.stage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get transactionId => $composableBuilder(
      column: $table.transactionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rawText => $composableBuilder(
      column: $table.rawText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ocrEngine => $composableBuilder(
      column: $table.ocrEngine, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceInfoJson => $composableBuilder(
      column: $table.sourceInfoJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ruleResultJson => $composableBuilder(
      column: $table.ruleResultJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rulePackageVersion => $composableBuilder(
      column: $table.rulePackageVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rulesVersion => $composableBuilder(
      column: $table.rulesVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get normalizationVersion => $composableBuilder(
      column: $table.normalizationVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get personalRulesRevision => $composableBuilder(
      column: $table.personalRulesRevision,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ruleSnapshotStatus => $composableBuilder(
      column: $table.ruleSnapshotStatus,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get finalResultJson => $composableBuilder(
      column: $table.finalResultJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get leaseUntil => $composableBuilder(
      column: $table.leaseUntil, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get attachmentDone => $composableBuilder(
      column: $table.attachmentDone,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));
}

class $$BillingJobsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $BillingJobsTable> {
  $$BillingJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<int> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get rawText =>
      $composableBuilder(column: $table.rawText, builder: (column) => column);

  GeneratedColumn<String> get ocrEngine =>
      $composableBuilder(column: $table.ocrEngine, builder: (column) => column);

  GeneratedColumn<String> get sourceInfoJson => $composableBuilder(
      column: $table.sourceInfoJson, builder: (column) => column);

  GeneratedColumn<String> get ruleResultJson => $composableBuilder(
      column: $table.ruleResultJson, builder: (column) => column);

  GeneratedColumn<int> get rulePackageVersion => $composableBuilder(
      column: $table.rulePackageVersion, builder: (column) => column);

  GeneratedColumn<String> get rulesVersion => $composableBuilder(
      column: $table.rulesVersion, builder: (column) => column);

  GeneratedColumn<int> get normalizationVersion => $composableBuilder(
      column: $table.normalizationVersion, builder: (column) => column);

  GeneratedColumn<int> get personalRulesRevision => $composableBuilder(
      column: $table.personalRulesRevision, builder: (column) => column);

  GeneratedColumn<String> get ruleSnapshotStatus => $composableBuilder(
      column: $table.ruleSnapshotStatus, builder: (column) => column);

  GeneratedColumn<String> get finalResultJson => $composableBuilder(
      column: $table.finalResultJson, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get leaseUntil => $composableBuilder(
      column: $table.leaseUntil, builder: (column) => column);

  GeneratedColumn<bool> get attachmentDone => $composableBuilder(
      column: $table.attachmentDone, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);
}

class $$BillingJobsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $BillingJobsTable,
    BillingJob,
    $$BillingJobsTableFilterComposer,
    $$BillingJobsTableOrderingComposer,
    $$BillingJobsTableAnnotationComposer,
    $$BillingJobsTableCreateCompanionBuilder,
    $$BillingJobsTableUpdateCompanionBuilder,
    (BillingJob, BaseReferences<_$BeeDatabase, $BillingJobsTable, BillingJob>),
    BillingJob,
    PrefetchHooks Function()> {
  $$BillingJobsTableTableManager(_$BeeDatabase db, $BillingJobsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BillingJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BillingJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BillingJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> ledgerId = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> stage = const Value.absent(),
            Value<int?> transactionId = const Value.absent(),
            Value<String> imagePath = const Value.absent(),
            Value<String?> rawText = const Value.absent(),
            Value<String?> ocrEngine = const Value.absent(),
            Value<String?> sourceInfoJson = const Value.absent(),
            Value<String?> ruleResultJson = const Value.absent(),
            Value<int?> rulePackageVersion = const Value.absent(),
            Value<String?> rulesVersion = const Value.absent(),
            Value<int?> normalizationVersion = const Value.absent(),
            Value<int?> personalRulesRevision = const Value.absent(),
            Value<String?> ruleSnapshotStatus = const Value.absent(),
            Value<String?> finalResultJson = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<DateTime?> leaseUntil = const Value.absent(),
            Value<bool> attachmentDone = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
          }) =>
              BillingJobsCompanion(
            id: id,
            ledgerId: ledgerId,
            kind: kind,
            status: status,
            stage: stage,
            transactionId: transactionId,
            imagePath: imagePath,
            rawText: rawText,
            ocrEngine: ocrEngine,
            sourceInfoJson: sourceInfoJson,
            ruleResultJson: ruleResultJson,
            rulePackageVersion: rulePackageVersion,
            rulesVersion: rulesVersion,
            normalizationVersion: normalizationVersion,
            personalRulesRevision: personalRulesRevision,
            ruleSnapshotStatus: ruleSnapshotStatus,
            finalResultJson: finalResultJson,
            attemptCount: attemptCount,
            lastError: lastError,
            leaseUntil: leaseUntil,
            attachmentDone: attachmentDone,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int?> ledgerId = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> stage = const Value.absent(),
            Value<int?> transactionId = const Value.absent(),
            required String imagePath,
            Value<String?> rawText = const Value.absent(),
            Value<String?> ocrEngine = const Value.absent(),
            Value<String?> sourceInfoJson = const Value.absent(),
            Value<String?> ruleResultJson = const Value.absent(),
            Value<int?> rulePackageVersion = const Value.absent(),
            Value<String?> rulesVersion = const Value.absent(),
            Value<int?> normalizationVersion = const Value.absent(),
            Value<int?> personalRulesRevision = const Value.absent(),
            Value<String?> ruleSnapshotStatus = const Value.absent(),
            Value<String?> finalResultJson = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<DateTime?> leaseUntil = const Value.absent(),
            Value<bool> attachmentDone = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
          }) =>
              BillingJobsCompanion.insert(
            id: id,
            ledgerId: ledgerId,
            kind: kind,
            status: status,
            stage: stage,
            transactionId: transactionId,
            imagePath: imagePath,
            rawText: rawText,
            ocrEngine: ocrEngine,
            sourceInfoJson: sourceInfoJson,
            ruleResultJson: ruleResultJson,
            rulePackageVersion: rulePackageVersion,
            rulesVersion: rulesVersion,
            normalizationVersion: normalizationVersion,
            personalRulesRevision: personalRulesRevision,
            ruleSnapshotStatus: ruleSnapshotStatus,
            finalResultJson: finalResultJson,
            attemptCount: attemptCount,
            lastError: lastError,
            leaseUntil: leaseUntil,
            attachmentDone: attachmentDone,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BillingJobsTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $BillingJobsTable,
    BillingJob,
    $$BillingJobsTableFilterComposer,
    $$BillingJobsTableOrderingComposer,
    $$BillingJobsTableAnnotationComposer,
    $$BillingJobsTableCreateCompanionBuilder,
    $$BillingJobsTableUpdateCompanionBuilder,
    (BillingJob, BaseReferences<_$BeeDatabase, $BillingJobsTable, BillingJob>),
    BillingJob,
    PrefetchHooks Function()>;
typedef $$BillingCasesTableCreateCompanionBuilder = BillingCasesCompanion
    Function({
  Value<int> id,
  required String requestId,
  Value<int?> ledgerId,
  required String sourceImagePath,
  Value<String?> sourceInfoJson,
  Value<String> state,
  Value<int> version,
  Value<String?> encryptedOcrEvidence,
  Value<String?> extractionResultJson,
  Value<int?> transactionId,
  Value<bool> syncAllowed,
  Value<DateTime?> evidencePurgeAfter,
  Value<DateTime?> workflowDeleteAfter,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> completedAt,
});
typedef $$BillingCasesTableUpdateCompanionBuilder = BillingCasesCompanion
    Function({
  Value<int> id,
  Value<String> requestId,
  Value<int?> ledgerId,
  Value<String> sourceImagePath,
  Value<String?> sourceInfoJson,
  Value<String> state,
  Value<int> version,
  Value<String?> encryptedOcrEvidence,
  Value<String?> extractionResultJson,
  Value<int?> transactionId,
  Value<bool> syncAllowed,
  Value<DateTime?> evidencePurgeAfter,
  Value<DateTime?> workflowDeleteAfter,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> completedAt,
});

class $$BillingCasesTableFilterComposer
    extends Composer<_$BeeDatabase, $BillingCasesTable> {
  $$BillingCasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get requestId => $composableBuilder(
      column: $table.requestId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceImagePath => $composableBuilder(
      column: $table.sourceImagePath,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceInfoJson => $composableBuilder(
      column: $table.sourceInfoJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get encryptedOcrEvidence => $composableBuilder(
      column: $table.encryptedOcrEvidence,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get extractionResultJson => $composableBuilder(
      column: $table.extractionResultJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get syncAllowed => $composableBuilder(
      column: $table.syncAllowed, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get evidencePurgeAfter => $composableBuilder(
      column: $table.evidencePurgeAfter,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get workflowDeleteAfter => $composableBuilder(
      column: $table.workflowDeleteAfter,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));
}

class $$BillingCasesTableOrderingComposer
    extends Composer<_$BeeDatabase, $BillingCasesTable> {
  $$BillingCasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get requestId => $composableBuilder(
      column: $table.requestId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ledgerId => $composableBuilder(
      column: $table.ledgerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceImagePath => $composableBuilder(
      column: $table.sourceImagePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceInfoJson => $composableBuilder(
      column: $table.sourceInfoJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get encryptedOcrEvidence => $composableBuilder(
      column: $table.encryptedOcrEvidence,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get extractionResultJson => $composableBuilder(
      column: $table.extractionResultJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get transactionId => $composableBuilder(
      column: $table.transactionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get syncAllowed => $composableBuilder(
      column: $table.syncAllowed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get evidencePurgeAfter => $composableBuilder(
      column: $table.evidencePurgeAfter,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get workflowDeleteAfter => $composableBuilder(
      column: $table.workflowDeleteAfter,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));
}

class $$BillingCasesTableAnnotationComposer
    extends Composer<_$BeeDatabase, $BillingCasesTable> {
  $$BillingCasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<int> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get sourceImagePath => $composableBuilder(
      column: $table.sourceImagePath, builder: (column) => column);

  GeneratedColumn<String> get sourceInfoJson => $composableBuilder(
      column: $table.sourceInfoJson, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get encryptedOcrEvidence => $composableBuilder(
      column: $table.encryptedOcrEvidence, builder: (column) => column);

  GeneratedColumn<String> get extractionResultJson => $composableBuilder(
      column: $table.extractionResultJson, builder: (column) => column);

  GeneratedColumn<int> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => column);

  GeneratedColumn<bool> get syncAllowed => $composableBuilder(
      column: $table.syncAllowed, builder: (column) => column);

  GeneratedColumn<DateTime> get evidencePurgeAfter => $composableBuilder(
      column: $table.evidencePurgeAfter, builder: (column) => column);

  GeneratedColumn<DateTime> get workflowDeleteAfter => $composableBuilder(
      column: $table.workflowDeleteAfter, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);
}

class $$BillingCasesTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $BillingCasesTable,
    BillingCase,
    $$BillingCasesTableFilterComposer,
    $$BillingCasesTableOrderingComposer,
    $$BillingCasesTableAnnotationComposer,
    $$BillingCasesTableCreateCompanionBuilder,
    $$BillingCasesTableUpdateCompanionBuilder,
    (
      BillingCase,
      BaseReferences<_$BeeDatabase, $BillingCasesTable, BillingCase>
    ),
    BillingCase,
    PrefetchHooks Function()> {
  $$BillingCasesTableTableManager(_$BeeDatabase db, $BillingCasesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BillingCasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BillingCasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BillingCasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> requestId = const Value.absent(),
            Value<int?> ledgerId = const Value.absent(),
            Value<String> sourceImagePath = const Value.absent(),
            Value<String?> sourceInfoJson = const Value.absent(),
            Value<String> state = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String?> encryptedOcrEvidence = const Value.absent(),
            Value<String?> extractionResultJson = const Value.absent(),
            Value<int?> transactionId = const Value.absent(),
            Value<bool> syncAllowed = const Value.absent(),
            Value<DateTime?> evidencePurgeAfter = const Value.absent(),
            Value<DateTime?> workflowDeleteAfter = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
          }) =>
              BillingCasesCompanion(
            id: id,
            requestId: requestId,
            ledgerId: ledgerId,
            sourceImagePath: sourceImagePath,
            sourceInfoJson: sourceInfoJson,
            state: state,
            version: version,
            encryptedOcrEvidence: encryptedOcrEvidence,
            extractionResultJson: extractionResultJson,
            transactionId: transactionId,
            syncAllowed: syncAllowed,
            evidencePurgeAfter: evidencePurgeAfter,
            workflowDeleteAfter: workflowDeleteAfter,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String requestId,
            Value<int?> ledgerId = const Value.absent(),
            required String sourceImagePath,
            Value<String?> sourceInfoJson = const Value.absent(),
            Value<String> state = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String?> encryptedOcrEvidence = const Value.absent(),
            Value<String?> extractionResultJson = const Value.absent(),
            Value<int?> transactionId = const Value.absent(),
            Value<bool> syncAllowed = const Value.absent(),
            Value<DateTime?> evidencePurgeAfter = const Value.absent(),
            Value<DateTime?> workflowDeleteAfter = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
          }) =>
              BillingCasesCompanion.insert(
            id: id,
            requestId: requestId,
            ledgerId: ledgerId,
            sourceImagePath: sourceImagePath,
            sourceInfoJson: sourceInfoJson,
            state: state,
            version: version,
            encryptedOcrEvidence: encryptedOcrEvidence,
            extractionResultJson: extractionResultJson,
            transactionId: transactionId,
            syncAllowed: syncAllowed,
            evidencePurgeAfter: evidencePurgeAfter,
            workflowDeleteAfter: workflowDeleteAfter,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BillingCasesTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $BillingCasesTable,
    BillingCase,
    $$BillingCasesTableFilterComposer,
    $$BillingCasesTableOrderingComposer,
    $$BillingCasesTableAnnotationComposer,
    $$BillingCasesTableCreateCompanionBuilder,
    $$BillingCasesTableUpdateCompanionBuilder,
    (
      BillingCase,
      BaseReferences<_$BeeDatabase, $BillingCasesTable, BillingCase>
    ),
    BillingCase,
    PrefetchHooks Function()>;
typedef $$BillingAutomationTasksTableCreateCompanionBuilder
    = BillingAutomationTasksCompanion Function({
  Value<int> id,
  required int caseId,
  required String kind,
  Value<String> state,
  Value<DateTime> availableAt,
  Value<int> attempt,
  Value<String?> leaseOwner,
  Value<int> leaseGeneration,
  Value<DateTime?> leaseUntil,
  Value<String?> lastErrorCode,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$BillingAutomationTasksTableUpdateCompanionBuilder
    = BillingAutomationTasksCompanion Function({
  Value<int> id,
  Value<int> caseId,
  Value<String> kind,
  Value<String> state,
  Value<DateTime> availableAt,
  Value<int> attempt,
  Value<String?> leaseOwner,
  Value<int> leaseGeneration,
  Value<DateTime?> leaseUntil,
  Value<String?> lastErrorCode,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$BillingAutomationTasksTableFilterComposer
    extends Composer<_$BeeDatabase, $BillingAutomationTasksTable> {
  $$BillingAutomationTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get caseId => $composableBuilder(
      column: $table.caseId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get availableAt => $composableBuilder(
      column: $table.availableAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempt => $composableBuilder(
      column: $table.attempt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get leaseOwner => $composableBuilder(
      column: $table.leaseOwner, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get leaseGeneration => $composableBuilder(
      column: $table.leaseGeneration,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get leaseUntil => $composableBuilder(
      column: $table.leaseUntil, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastErrorCode => $composableBuilder(
      column: $table.lastErrorCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$BillingAutomationTasksTableOrderingComposer
    extends Composer<_$BeeDatabase, $BillingAutomationTasksTable> {
  $$BillingAutomationTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get caseId => $composableBuilder(
      column: $table.caseId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get availableAt => $composableBuilder(
      column: $table.availableAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempt => $composableBuilder(
      column: $table.attempt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get leaseOwner => $composableBuilder(
      column: $table.leaseOwner, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get leaseGeneration => $composableBuilder(
      column: $table.leaseGeneration,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get leaseUntil => $composableBuilder(
      column: $table.leaseUntil, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastErrorCode => $composableBuilder(
      column: $table.lastErrorCode,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$BillingAutomationTasksTableAnnotationComposer
    extends Composer<_$BeeDatabase, $BillingAutomationTasksTable> {
  $$BillingAutomationTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get caseId =>
      $composableBuilder(column: $table.caseId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get availableAt => $composableBuilder(
      column: $table.availableAt, builder: (column) => column);

  GeneratedColumn<int> get attempt =>
      $composableBuilder(column: $table.attempt, builder: (column) => column);

  GeneratedColumn<String> get leaseOwner => $composableBuilder(
      column: $table.leaseOwner, builder: (column) => column);

  GeneratedColumn<int> get leaseGeneration => $composableBuilder(
      column: $table.leaseGeneration, builder: (column) => column);

  GeneratedColumn<DateTime> get leaseUntil => $composableBuilder(
      column: $table.leaseUntil, builder: (column) => column);

  GeneratedColumn<String> get lastErrorCode => $composableBuilder(
      column: $table.lastErrorCode, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BillingAutomationTasksTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $BillingAutomationTasksTable,
    BillingAutomationTask,
    $$BillingAutomationTasksTableFilterComposer,
    $$BillingAutomationTasksTableOrderingComposer,
    $$BillingAutomationTasksTableAnnotationComposer,
    $$BillingAutomationTasksTableCreateCompanionBuilder,
    $$BillingAutomationTasksTableUpdateCompanionBuilder,
    (
      BillingAutomationTask,
      BaseReferences<_$BeeDatabase, $BillingAutomationTasksTable,
          BillingAutomationTask>
    ),
    BillingAutomationTask,
    PrefetchHooks Function()> {
  $$BillingAutomationTasksTableTableManager(
      _$BeeDatabase db, $BillingAutomationTasksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BillingAutomationTasksTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$BillingAutomationTasksTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BillingAutomationTasksTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> caseId = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> state = const Value.absent(),
            Value<DateTime> availableAt = const Value.absent(),
            Value<int> attempt = const Value.absent(),
            Value<String?> leaseOwner = const Value.absent(),
            Value<int> leaseGeneration = const Value.absent(),
            Value<DateTime?> leaseUntil = const Value.absent(),
            Value<String?> lastErrorCode = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              BillingAutomationTasksCompanion(
            id: id,
            caseId: caseId,
            kind: kind,
            state: state,
            availableAt: availableAt,
            attempt: attempt,
            leaseOwner: leaseOwner,
            leaseGeneration: leaseGeneration,
            leaseUntil: leaseUntil,
            lastErrorCode: lastErrorCode,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int caseId,
            required String kind,
            Value<String> state = const Value.absent(),
            Value<DateTime> availableAt = const Value.absent(),
            Value<int> attempt = const Value.absent(),
            Value<String?> leaseOwner = const Value.absent(),
            Value<int> leaseGeneration = const Value.absent(),
            Value<DateTime?> leaseUntil = const Value.absent(),
            Value<String?> lastErrorCode = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              BillingAutomationTasksCompanion.insert(
            id: id,
            caseId: caseId,
            kind: kind,
            state: state,
            availableAt: availableAt,
            attempt: attempt,
            leaseOwner: leaseOwner,
            leaseGeneration: leaseGeneration,
            leaseUntil: leaseUntil,
            lastErrorCode: lastErrorCode,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BillingAutomationTasksTableProcessedTableManager
    = ProcessedTableManager<
        _$BeeDatabase,
        $BillingAutomationTasksTable,
        BillingAutomationTask,
        $$BillingAutomationTasksTableFilterComposer,
        $$BillingAutomationTasksTableOrderingComposer,
        $$BillingAutomationTasksTableAnnotationComposer,
        $$BillingAutomationTasksTableCreateCompanionBuilder,
        $$BillingAutomationTasksTableUpdateCompanionBuilder,
        (
          BillingAutomationTask,
          BaseReferences<_$BeeDatabase, $BillingAutomationTasksTable,
              BillingAutomationTask>
        ),
        BillingAutomationTask,
        PrefetchHooks Function()>;
typedef $$BillingUserTasksTableCreateCompanionBuilder
    = BillingUserTasksCompanion Function({
  Value<int> id,
  required int caseId,
  required String kind,
  Value<String> state,
  Value<int?> transactionId,
  Value<String?> draftJson,
  Value<String?> resolutionJson,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime?> resolvedAt,
  Value<DateTime?> expiresAt,
});
typedef $$BillingUserTasksTableUpdateCompanionBuilder
    = BillingUserTasksCompanion Function({
  Value<int> id,
  Value<int> caseId,
  Value<String> kind,
  Value<String> state,
  Value<int?> transactionId,
  Value<String?> draftJson,
  Value<String?> resolutionJson,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime?> resolvedAt,
  Value<DateTime?> expiresAt,
});

class $$BillingUserTasksTableFilterComposer
    extends Composer<_$BeeDatabase, $BillingUserTasksTable> {
  $$BillingUserTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get caseId => $composableBuilder(
      column: $table.caseId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get draftJson => $composableBuilder(
      column: $table.draftJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resolutionJson => $composableBuilder(
      column: $table.resolutionJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnFilters(column));
}

class $$BillingUserTasksTableOrderingComposer
    extends Composer<_$BeeDatabase, $BillingUserTasksTable> {
  $$BillingUserTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get caseId => $composableBuilder(
      column: $table.caseId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get transactionId => $composableBuilder(
      column: $table.transactionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get draftJson => $composableBuilder(
      column: $table.draftJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resolutionJson => $composableBuilder(
      column: $table.resolutionJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnOrderings(column));
}

class $$BillingUserTasksTableAnnotationComposer
    extends Composer<_$BeeDatabase, $BillingUserTasksTable> {
  $$BillingUserTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get caseId =>
      $composableBuilder(column: $table.caseId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => column);

  GeneratedColumn<String> get draftJson =>
      $composableBuilder(column: $table.draftJson, builder: (column) => column);

  GeneratedColumn<String> get resolutionJson => $composableBuilder(
      column: $table.resolutionJson, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$BillingUserTasksTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $BillingUserTasksTable,
    BillingUserTask,
    $$BillingUserTasksTableFilterComposer,
    $$BillingUserTasksTableOrderingComposer,
    $$BillingUserTasksTableAnnotationComposer,
    $$BillingUserTasksTableCreateCompanionBuilder,
    $$BillingUserTasksTableUpdateCompanionBuilder,
    (
      BillingUserTask,
      BaseReferences<_$BeeDatabase, $BillingUserTasksTable, BillingUserTask>
    ),
    BillingUserTask,
    PrefetchHooks Function()> {
  $$BillingUserTasksTableTableManager(
      _$BeeDatabase db, $BillingUserTasksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BillingUserTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BillingUserTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BillingUserTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> caseId = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> state = const Value.absent(),
            Value<int?> transactionId = const Value.absent(),
            Value<String?> draftJson = const Value.absent(),
            Value<String?> resolutionJson = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> resolvedAt = const Value.absent(),
            Value<DateTime?> expiresAt = const Value.absent(),
          }) =>
              BillingUserTasksCompanion(
            id: id,
            caseId: caseId,
            kind: kind,
            state: state,
            transactionId: transactionId,
            draftJson: draftJson,
            resolutionJson: resolutionJson,
            version: version,
            createdAt: createdAt,
            resolvedAt: resolvedAt,
            expiresAt: expiresAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int caseId,
            required String kind,
            Value<String> state = const Value.absent(),
            Value<int?> transactionId = const Value.absent(),
            Value<String?> draftJson = const Value.absent(),
            Value<String?> resolutionJson = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> resolvedAt = const Value.absent(),
            Value<DateTime?> expiresAt = const Value.absent(),
          }) =>
              BillingUserTasksCompanion.insert(
            id: id,
            caseId: caseId,
            kind: kind,
            state: state,
            transactionId: transactionId,
            draftJson: draftJson,
            resolutionJson: resolutionJson,
            version: version,
            createdAt: createdAt,
            resolvedAt: resolvedAt,
            expiresAt: expiresAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BillingUserTasksTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $BillingUserTasksTable,
    BillingUserTask,
    $$BillingUserTasksTableFilterComposer,
    $$BillingUserTasksTableOrderingComposer,
    $$BillingUserTasksTableAnnotationComposer,
    $$BillingUserTasksTableCreateCompanionBuilder,
    $$BillingUserTasksTableUpdateCompanionBuilder,
    (
      BillingUserTask,
      BaseReferences<_$BeeDatabase, $BillingUserTasksTable, BillingUserTask>
    ),
    BillingUserTask,
    PrefetchHooks Function()>;
typedef $$BillingPreparedAttachmentsTableCreateCompanionBuilder
    = BillingPreparedAttachmentsCompanion Function({
  Value<int> id,
  required int caseId,
  required String sourcePath,
  Value<String?> preparedPath,
  Value<String?> contentHash,
  Value<String?> mimeType,
  Value<int?> byteLength,
  Value<int?> width,
  Value<int?> height,
  Value<String> state,
  Value<String?> errorCode,
  Value<DateTime> createdAt,
  Value<DateTime?> preparedAt,
  Value<DateTime?> publishedAt,
});
typedef $$BillingPreparedAttachmentsTableUpdateCompanionBuilder
    = BillingPreparedAttachmentsCompanion Function({
  Value<int> id,
  Value<int> caseId,
  Value<String> sourcePath,
  Value<String?> preparedPath,
  Value<String?> contentHash,
  Value<String?> mimeType,
  Value<int?> byteLength,
  Value<int?> width,
  Value<int?> height,
  Value<String> state,
  Value<String?> errorCode,
  Value<DateTime> createdAt,
  Value<DateTime?> preparedAt,
  Value<DateTime?> publishedAt,
});

class $$BillingPreparedAttachmentsTableFilterComposer
    extends Composer<_$BeeDatabase, $BillingPreparedAttachmentsTable> {
  $$BillingPreparedAttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get caseId => $composableBuilder(
      column: $table.caseId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourcePath => $composableBuilder(
      column: $table.sourcePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get preparedPath => $composableBuilder(
      column: $table.preparedPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentHash => $composableBuilder(
      column: $table.contentHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mimeType => $composableBuilder(
      column: $table.mimeType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get byteLength => $composableBuilder(
      column: $table.byteLength, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get width => $composableBuilder(
      column: $table.width, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get height => $composableBuilder(
      column: $table.height, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorCode => $composableBuilder(
      column: $table.errorCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get preparedAt => $composableBuilder(
      column: $table.preparedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => ColumnFilters(column));
}

class $$BillingPreparedAttachmentsTableOrderingComposer
    extends Composer<_$BeeDatabase, $BillingPreparedAttachmentsTable> {
  $$BillingPreparedAttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get caseId => $composableBuilder(
      column: $table.caseId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourcePath => $composableBuilder(
      column: $table.sourcePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get preparedPath => $composableBuilder(
      column: $table.preparedPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentHash => $composableBuilder(
      column: $table.contentHash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mimeType => $composableBuilder(
      column: $table.mimeType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get byteLength => $composableBuilder(
      column: $table.byteLength, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get width => $composableBuilder(
      column: $table.width, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get height => $composableBuilder(
      column: $table.height, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorCode => $composableBuilder(
      column: $table.errorCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get preparedAt => $composableBuilder(
      column: $table.preparedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => ColumnOrderings(column));
}

class $$BillingPreparedAttachmentsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $BillingPreparedAttachmentsTable> {
  $$BillingPreparedAttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get caseId =>
      $composableBuilder(column: $table.caseId, builder: (column) => column);

  GeneratedColumn<String> get sourcePath => $composableBuilder(
      column: $table.sourcePath, builder: (column) => column);

  GeneratedColumn<String> get preparedPath => $composableBuilder(
      column: $table.preparedPath, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
      column: $table.contentHash, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get byteLength => $composableBuilder(
      column: $table.byteLength, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get preparedAt => $composableBuilder(
      column: $table.preparedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
      column: $table.publishedAt, builder: (column) => column);
}

class $$BillingPreparedAttachmentsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $BillingPreparedAttachmentsTable,
    BillingPreparedAttachment,
    $$BillingPreparedAttachmentsTableFilterComposer,
    $$BillingPreparedAttachmentsTableOrderingComposer,
    $$BillingPreparedAttachmentsTableAnnotationComposer,
    $$BillingPreparedAttachmentsTableCreateCompanionBuilder,
    $$BillingPreparedAttachmentsTableUpdateCompanionBuilder,
    (
      BillingPreparedAttachment,
      BaseReferences<_$BeeDatabase, $BillingPreparedAttachmentsTable,
          BillingPreparedAttachment>
    ),
    BillingPreparedAttachment,
    PrefetchHooks Function()> {
  $$BillingPreparedAttachmentsTableTableManager(
      _$BeeDatabase db, $BillingPreparedAttachmentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BillingPreparedAttachmentsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$BillingPreparedAttachmentsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BillingPreparedAttachmentsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> caseId = const Value.absent(),
            Value<String> sourcePath = const Value.absent(),
            Value<String?> preparedPath = const Value.absent(),
            Value<String?> contentHash = const Value.absent(),
            Value<String?> mimeType = const Value.absent(),
            Value<int?> byteLength = const Value.absent(),
            Value<int?> width = const Value.absent(),
            Value<int?> height = const Value.absent(),
            Value<String> state = const Value.absent(),
            Value<String?> errorCode = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> preparedAt = const Value.absent(),
            Value<DateTime?> publishedAt = const Value.absent(),
          }) =>
              BillingPreparedAttachmentsCompanion(
            id: id,
            caseId: caseId,
            sourcePath: sourcePath,
            preparedPath: preparedPath,
            contentHash: contentHash,
            mimeType: mimeType,
            byteLength: byteLength,
            width: width,
            height: height,
            state: state,
            errorCode: errorCode,
            createdAt: createdAt,
            preparedAt: preparedAt,
            publishedAt: publishedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int caseId,
            required String sourcePath,
            Value<String?> preparedPath = const Value.absent(),
            Value<String?> contentHash = const Value.absent(),
            Value<String?> mimeType = const Value.absent(),
            Value<int?> byteLength = const Value.absent(),
            Value<int?> width = const Value.absent(),
            Value<int?> height = const Value.absent(),
            Value<String> state = const Value.absent(),
            Value<String?> errorCode = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> preparedAt = const Value.absent(),
            Value<DateTime?> publishedAt = const Value.absent(),
          }) =>
              BillingPreparedAttachmentsCompanion.insert(
            id: id,
            caseId: caseId,
            sourcePath: sourcePath,
            preparedPath: preparedPath,
            contentHash: contentHash,
            mimeType: mimeType,
            byteLength: byteLength,
            width: width,
            height: height,
            state: state,
            errorCode: errorCode,
            createdAt: createdAt,
            preparedAt: preparedAt,
            publishedAt: publishedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BillingPreparedAttachmentsTableProcessedTableManager
    = ProcessedTableManager<
        _$BeeDatabase,
        $BillingPreparedAttachmentsTable,
        BillingPreparedAttachment,
        $$BillingPreparedAttachmentsTableFilterComposer,
        $$BillingPreparedAttachmentsTableOrderingComposer,
        $$BillingPreparedAttachmentsTableAnnotationComposer,
        $$BillingPreparedAttachmentsTableCreateCompanionBuilder,
        $$BillingPreparedAttachmentsTableUpdateCompanionBuilder,
        (
          BillingPreparedAttachment,
          BaseReferences<_$BeeDatabase, $BillingPreparedAttachmentsTable,
              BillingPreparedAttachment>
        ),
        BillingPreparedAttachment,
        PrefetchHooks Function()>;
typedef $$BillingOutboxTableCreateCompanionBuilder = BillingOutboxCompanion
    Function({
  Value<int> id,
  required int caseId,
  Value<int?> userTaskId,
  required String eventType,
  Value<String?> payloadJson,
  Value<String> state,
  Value<int> attempt,
  Value<DateTime> availableAt,
  Value<DateTime> createdAt,
  Value<DateTime?> deliveredAt,
});
typedef $$BillingOutboxTableUpdateCompanionBuilder = BillingOutboxCompanion
    Function({
  Value<int> id,
  Value<int> caseId,
  Value<int?> userTaskId,
  Value<String> eventType,
  Value<String?> payloadJson,
  Value<String> state,
  Value<int> attempt,
  Value<DateTime> availableAt,
  Value<DateTime> createdAt,
  Value<DateTime?> deliveredAt,
});

class $$BillingOutboxTableFilterComposer
    extends Composer<_$BeeDatabase, $BillingOutboxTable> {
  $$BillingOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get caseId => $composableBuilder(
      column: $table.caseId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get userTaskId => $composableBuilder(
      column: $table.userTaskId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempt => $composableBuilder(
      column: $table.attempt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get availableAt => $composableBuilder(
      column: $table.availableAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deliveredAt => $composableBuilder(
      column: $table.deliveredAt, builder: (column) => ColumnFilters(column));
}

class $$BillingOutboxTableOrderingComposer
    extends Composer<_$BeeDatabase, $BillingOutboxTable> {
  $$BillingOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get caseId => $composableBuilder(
      column: $table.caseId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get userTaskId => $composableBuilder(
      column: $table.userTaskId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempt => $composableBuilder(
      column: $table.attempt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get availableAt => $composableBuilder(
      column: $table.availableAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deliveredAt => $composableBuilder(
      column: $table.deliveredAt, builder: (column) => ColumnOrderings(column));
}

class $$BillingOutboxTableAnnotationComposer
    extends Composer<_$BeeDatabase, $BillingOutboxTable> {
  $$BillingOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get caseId =>
      $composableBuilder(column: $table.caseId, builder: (column) => column);

  GeneratedColumn<int> get userTaskId => $composableBuilder(
      column: $table.userTaskId, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attempt =>
      $composableBuilder(column: $table.attempt, builder: (column) => column);

  GeneratedColumn<DateTime> get availableAt => $composableBuilder(
      column: $table.availableAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deliveredAt => $composableBuilder(
      column: $table.deliveredAt, builder: (column) => column);
}

class $$BillingOutboxTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $BillingOutboxTable,
    BillingOutboxData,
    $$BillingOutboxTableFilterComposer,
    $$BillingOutboxTableOrderingComposer,
    $$BillingOutboxTableAnnotationComposer,
    $$BillingOutboxTableCreateCompanionBuilder,
    $$BillingOutboxTableUpdateCompanionBuilder,
    (
      BillingOutboxData,
      BaseReferences<_$BeeDatabase, $BillingOutboxTable, BillingOutboxData>
    ),
    BillingOutboxData,
    PrefetchHooks Function()> {
  $$BillingOutboxTableTableManager(_$BeeDatabase db, $BillingOutboxTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BillingOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BillingOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BillingOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> caseId = const Value.absent(),
            Value<int?> userTaskId = const Value.absent(),
            Value<String> eventType = const Value.absent(),
            Value<String?> payloadJson = const Value.absent(),
            Value<String> state = const Value.absent(),
            Value<int> attempt = const Value.absent(),
            Value<DateTime> availableAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> deliveredAt = const Value.absent(),
          }) =>
              BillingOutboxCompanion(
            id: id,
            caseId: caseId,
            userTaskId: userTaskId,
            eventType: eventType,
            payloadJson: payloadJson,
            state: state,
            attempt: attempt,
            availableAt: availableAt,
            createdAt: createdAt,
            deliveredAt: deliveredAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int caseId,
            Value<int?> userTaskId = const Value.absent(),
            required String eventType,
            Value<String?> payloadJson = const Value.absent(),
            Value<String> state = const Value.absent(),
            Value<int> attempt = const Value.absent(),
            Value<DateTime> availableAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> deliveredAt = const Value.absent(),
          }) =>
              BillingOutboxCompanion.insert(
            id: id,
            caseId: caseId,
            userTaskId: userTaskId,
            eventType: eventType,
            payloadJson: payloadJson,
            state: state,
            attempt: attempt,
            availableAt: availableAt,
            createdAt: createdAt,
            deliveredAt: deliveredAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BillingOutboxTableProcessedTableManager = ProcessedTableManager<
    _$BeeDatabase,
    $BillingOutboxTable,
    BillingOutboxData,
    $$BillingOutboxTableFilterComposer,
    $$BillingOutboxTableOrderingComposer,
    $$BillingOutboxTableAnnotationComposer,
    $$BillingOutboxTableCreateCompanionBuilder,
    $$BillingOutboxTableUpdateCompanionBuilder,
    (
      BillingOutboxData,
      BaseReferences<_$BeeDatabase, $BillingOutboxTable, BillingOutboxData>
    ),
    BillingOutboxData,
    PrefetchHooks Function()>;
typedef $$BillingCaseArtifactsTableCreateCompanionBuilder
    = BillingCaseArtifactsCompanion Function({
  Value<int> id,
  required int caseId,
  required String kind,
  required String privatePath,
  Value<String> state,
  Value<DateTime?> deleteAfter,
  Value<DateTime?> deletedAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$BillingCaseArtifactsTableUpdateCompanionBuilder
    = BillingCaseArtifactsCompanion Function({
  Value<int> id,
  Value<int> caseId,
  Value<String> kind,
  Value<String> privatePath,
  Value<String> state,
  Value<DateTime?> deleteAfter,
  Value<DateTime?> deletedAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$BillingCaseArtifactsTableFilterComposer
    extends Composer<_$BeeDatabase, $BillingCaseArtifactsTable> {
  $$BillingCaseArtifactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get caseId => $composableBuilder(
      column: $table.caseId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get privatePath => $composableBuilder(
      column: $table.privatePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deleteAfter => $composableBuilder(
      column: $table.deleteAfter, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$BillingCaseArtifactsTableOrderingComposer
    extends Composer<_$BeeDatabase, $BillingCaseArtifactsTable> {
  $$BillingCaseArtifactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get caseId => $composableBuilder(
      column: $table.caseId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get privatePath => $composableBuilder(
      column: $table.privatePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deleteAfter => $composableBuilder(
      column: $table.deleteAfter, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$BillingCaseArtifactsTableAnnotationComposer
    extends Composer<_$BeeDatabase, $BillingCaseArtifactsTable> {
  $$BillingCaseArtifactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get caseId =>
      $composableBuilder(column: $table.caseId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get privatePath => $composableBuilder(
      column: $table.privatePath, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get deleteAfter => $composableBuilder(
      column: $table.deleteAfter, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BillingCaseArtifactsTableTableManager extends RootTableManager<
    _$BeeDatabase,
    $BillingCaseArtifactsTable,
    BillingCaseArtifact,
    $$BillingCaseArtifactsTableFilterComposer,
    $$BillingCaseArtifactsTableOrderingComposer,
    $$BillingCaseArtifactsTableAnnotationComposer,
    $$BillingCaseArtifactsTableCreateCompanionBuilder,
    $$BillingCaseArtifactsTableUpdateCompanionBuilder,
    (
      BillingCaseArtifact,
      BaseReferences<_$BeeDatabase, $BillingCaseArtifactsTable,
          BillingCaseArtifact>
    ),
    BillingCaseArtifact,
    PrefetchHooks Function()> {
  $$BillingCaseArtifactsTableTableManager(
      _$BeeDatabase db, $BillingCaseArtifactsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BillingCaseArtifactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BillingCaseArtifactsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BillingCaseArtifactsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> caseId = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> privatePath = const Value.absent(),
            Value<String> state = const Value.absent(),
            Value<DateTime?> deleteAfter = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              BillingCaseArtifactsCompanion(
            id: id,
            caseId: caseId,
            kind: kind,
            privatePath: privatePath,
            state: state,
            deleteAfter: deleteAfter,
            deletedAt: deletedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int caseId,
            required String kind,
            required String privatePath,
            Value<String> state = const Value.absent(),
            Value<DateTime?> deleteAfter = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              BillingCaseArtifactsCompanion.insert(
            id: id,
            caseId: caseId,
            kind: kind,
            privatePath: privatePath,
            state: state,
            deleteAfter: deleteAfter,
            deletedAt: deletedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BillingCaseArtifactsTableProcessedTableManager
    = ProcessedTableManager<
        _$BeeDatabase,
        $BillingCaseArtifactsTable,
        BillingCaseArtifact,
        $$BillingCaseArtifactsTableFilterComposer,
        $$BillingCaseArtifactsTableOrderingComposer,
        $$BillingCaseArtifactsTableAnnotationComposer,
        $$BillingCaseArtifactsTableCreateCompanionBuilder,
        $$BillingCaseArtifactsTableUpdateCompanionBuilder,
        (
          BillingCaseArtifact,
          BaseReferences<_$BeeDatabase, $BillingCaseArtifactsTable,
              BillingCaseArtifact>
        ),
        BillingCaseArtifact,
        PrefetchHooks Function()>;

class $BeeDatabaseManager {
  final _$BeeDatabase _db;
  $BeeDatabaseManager(this._db);
  $$LedgersTableTableManager get ledgers =>
      $$LedgersTableTableManager(_db, _db.ledgers);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$RecurringTransactionsTableTableManager get recurringTransactions =>
      $$RecurringTransactionsTableTableManager(_db, _db.recurringTransactions);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$TransactionTagsTableTableManager get transactionTags =>
      $$TransactionTagsTableTableManager(_db, _db.transactionTags);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db, _db.budgets);
  $$TransactionAttachmentsTableTableManager get transactionAttachments =>
      $$TransactionAttachmentsTableTableManager(
          _db, _db.transactionAttachments);
  $$LocalChangesTableTableManager get localChanges =>
      $$LocalChangesTableTableManager(_db, _db.localChanges);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$BillingJobsTableTableManager get billingJobs =>
      $$BillingJobsTableTableManager(_db, _db.billingJobs);
  $$BillingCasesTableTableManager get billingCases =>
      $$BillingCasesTableTableManager(_db, _db.billingCases);
  $$BillingAutomationTasksTableTableManager get billingAutomationTasks =>
      $$BillingAutomationTasksTableTableManager(
          _db, _db.billingAutomationTasks);
  $$BillingUserTasksTableTableManager get billingUserTasks =>
      $$BillingUserTasksTableTableManager(_db, _db.billingUserTasks);
  $$BillingPreparedAttachmentsTableTableManager
      get billingPreparedAttachments =>
          $$BillingPreparedAttachmentsTableTableManager(
              _db, _db.billingPreparedAttachments);
  $$BillingOutboxTableTableManager get billingOutbox =>
      $$BillingOutboxTableTableManager(_db, _db.billingOutbox);
  $$BillingCaseArtifactsTableTableManager get billingCaseArtifacts =>
      $$BillingCaseArtifactsTableTableManager(_db, _db.billingCaseArtifacts);
}
