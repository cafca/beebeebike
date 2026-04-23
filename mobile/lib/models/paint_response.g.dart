// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paint_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PaintResponseImpl _$$PaintResponseImplFromJson(Map<String, dynamic> json) =>
    _$PaintResponseImpl(
      createdId: (json['created_id'] as num?)?.toInt(),
      clippedCount: (json['clipped_count'] as num?)?.toInt() ?? 0,
      deletedCount: (json['deleted_count'] as num?)?.toInt() ?? 0,
      canUndo: json['can_undo'] as bool? ?? false,
      canRedo: json['can_redo'] as bool? ?? false,
    );

Map<String, dynamic> _$$PaintResponseImplToJson(_$PaintResponseImpl instance) =>
    <String, dynamic>{
      'created_id': instance.createdId,
      'clipped_count': instance.clippedCount,
      'deleted_count': instance.deletedCount,
      'can_undo': instance.canUndo,
      'can_redo': instance.canRedo,
    };
