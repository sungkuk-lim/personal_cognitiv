import 'package:flutter/material.dart';

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
  final String? userId;
  final bool isLocalOnly;

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
    this.userId,
    this.isLocalOnly = false,
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
      userId: map['user_id']?.toString(),
      isLocalOnly: map['is_local_only'] == true,
    );
  }

  Memory copyWith({bool? isLocalOnly, String? id}) {
    return Memory(
      id: id ?? this.id,
      content: content,
      summary: summary,
      entities: entities,
      createdAt: createdAt,
      type: type,
      category: category,
      subCategory: subCategory,
      embedding: embedding,
      lat: lat,
      lng: lng,
      userId: userId,
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
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
      'is_local_only': true,
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
