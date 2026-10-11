// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_dao.dart';

// ignore_for_file: type=lint
mixin _$ListDaoMixin on DatabaseAccessor<AppDatabase> {
  $TaskListsTable get taskLists => attachedDatabase.taskLists;
  ListDaoManager get managers => ListDaoManager(this);
}

class ListDaoManager {
  final _$ListDaoMixin _db;
  ListDaoManager(this._db);
  $$TaskListsTableTableManager get taskLists =>
      $$TaskListsTableTableManager(_db.attachedDatabase, _db.taskLists);
}
