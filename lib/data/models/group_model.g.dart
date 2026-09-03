// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GroupModelAdapter extends TypeAdapter<GroupModel> {
  @override
  final int typeId = 2;

  @override
  GroupModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GroupModel(
      id: fields[0] as String,
      name: fields[1] as String,
      portrait: fields[2] as String?,
      introduction: fields[3] as String?,
      creatorId: fields[4] as String,
      memberCount: fields[5] as int,
      maxMemberCount: fields[6] as int?,
      createTime: fields[7] as int,
      memberIds: (fields[8] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, GroupModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.portrait)
      ..writeByte(3)
      ..write(obj.introduction)
      ..writeByte(4)
      ..write(obj.creatorId)
      ..writeByte(5)
      ..write(obj.memberCount)
      ..writeByte(6)
      ..write(obj.maxMemberCount)
      ..writeByte(7)
      ..write(obj.createTime)
      ..writeByte(8)
      ..write(obj.memberIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
