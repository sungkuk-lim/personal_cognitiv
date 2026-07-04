import 'package:flutter/material.dart';

import '../utils/embedding_utils.dart';

class Memory {
  final String id;
  final String content;
  final String summary;
  final List<String> entities;
  final DateTime createdAt;
  final String type;
  final String category;
  final String subCategory;
  final List<double>? embedding;
  final double? lat;
  final double? lng;
  final double? recallLat;
  final double? recallLng;
  final String? recallPlaceLabel;
  final bool recallEnabled;
  final String? userId;
  final bool isLocalOnly;
  final String userMemo;

  Memory({
    required this.id,
    required this.content,
    required this.summary,
    required this.entities,
    required this.createdAt,
    this.type = "voice",
    this.category = "Other",
    this.subCategory = "",
    this.embedding,
    this.lat,
    this.lng,
    this.recallLat,
    this.recallLng,
    this.recallPlaceLabel,
    this.recallEnabled = true,
    this.userId,
    this.isLocalOnly = false,
    this.userMemo = "",
  });

  factory Memory.fromMap(Map<String, dynamic> map) {
    return Memory(
      id: map['id'].toString(),
      content: map['content'] ?? "",
      summary: map['summary'] ?? "",
      entities: List<String>.from(map['entities'] ?? []),
      createdAt: DateTime.parse(map['created_at']),
      type: map['type'] ?? "voice",
      category: map['category'] ?? "Other",
      subCategory: map['sub_category'] ?? "",
      lat: map['lat']?.toDouble(),
      lng: map['lng']?.toDouble(),
      recallLat: map['recall_lat']?.toDouble(),
      recallLng: map['recall_lng']?.toDouble(),
      recallPlaceLabel: map['recall_place_label'] as String?,
      recallEnabled: map['recall_enabled'] != false,
      userId: map['user_id']?.toString(),
      isLocalOnly: map['is_local_only'] == true,
      embedding: parseEmbedding(map['embedding']),
      userMemo: (map['user_memo'] as String? ?? '').trim(),
    );
  }

  Memory copyWith({
    bool? isLocalOnly,
    String? id,
    String? content,
    String? summary,
    List<String>? entities,
    DateTime? createdAt,
    String? type,
    String? category,
    String? subCategory,
    List<double>? embedding,
    double? lat,
    double? lng,
    double? recallLat,
    double? recallLng,
    String? recallPlaceLabel,
    bool? recallEnabled,
    String? userMemo,
  }) {
    return Memory(
      id: id ?? this.id,
      content: content ?? this.content,
      summary: summary ?? this.summary,
      entities: entities ?? this.entities,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      embedding: embedding ?? this.embedding,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      recallLat: recallLat ?? this.recallLat,
      recallLng: recallLng ?? this.recallLng,
      recallPlaceLabel: recallPlaceLabel ?? this.recallPlaceLabel,
      recallEnabled: recallEnabled ?? this.recallEnabled,
      userId: userId,
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
      userMemo: userMemo ?? this.userMemo,
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'content': content,
      'summary': summary,
      'entities': entities,
      'type': type,
      'category': category,
      'sub_category': subCategory,
      'created_at': createdAt.toIso8601String(),
      'lat': lat,
      'lng': lng,
      if (recallLat != null) 'recall_lat': recallLat,
      if (recallLng != null) 'recall_lng': recallLng,
      if (recallPlaceLabel != null && recallPlaceLabel!.trim().isNotEmpty)
        'recall_place_label': recallPlaceLabel,
      if (!recallEnabled) 'recall_enabled': false,
      'is_local_only': true,
      if (userMemo.isNotEmpty) 'user_memo': userMemo,
      if (embedding != null) 'embedding': embedding,
    };
  }

  Map<String, dynamic> toMap({String? userId}) {
    return {
      'content': content,
      'summary': summary,
      'entities': entities,
      'embedding': embedding,
      'type': type,
      'category': category,
      'sub_category': subCategory,
      'created_at': createdAt.toIso8601String(),
      'lat': lat,
      'lng': lng,
      if (recallLat != null) 'recall_lat': recallLat,
      if (recallLng != null) 'recall_lng': recallLng,
      if (recallPlaceLabel != null && recallPlaceLabel!.trim().isNotEmpty)
        'recall_place_label': recallPlaceLabel,
      if (!recallEnabled) 'recall_enabled': false,
      if (userMemo.isNotEmpty) 'user_memo': userMemo,
      'user_id': ?userId,
    };
  }

  Color get categoryColor {
    switch (category) {
      case 'Food':
        return Colors.orange;
      case 'Social':
        return Colors.pink;
      case 'Study':
        return Colors.blue;
      case 'Work':
        return Colors.indigo;
      case 'Health':
        return Colors.red;
      case 'Travel':
        return Colors.teal;
      case 'Finance':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }
}
