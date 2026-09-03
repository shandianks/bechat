// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConversationModelAdapter extends TypeAdapter<ConversationModel> {
  @override
  final int typeId = 3;

  @override
  ConversationModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConversationModel(
      targetId: fields[0] as String,
      conversationType: fields[1] as int,
      title: fields[2] as String?,
      portrait: fields[3] as String?,
      lastMessageContent: fields[4] as String?,
      lastMessageTime: fields[5] as int,
      unreadCount: fields[6] as int,
      draft: fields[7] as String?,
      mentionedCount: fields[8] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ConversationModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.targetId)
      ..writeByte(1)
      ..write(obj.conversationType)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.portrait)
      ..writeByte(4)
      ..write(obj.lastMessageContent)
      ..writeByte(5)
      ..write(obj.lastMessageTime)
      ..writeByte(6)
      ..write(obj.unreadCount)
      ..writeByte(7)
      ..write(obj.draft)
      ..writeByte(8)
      ..write(obj.mentionedCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
