import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'graph_layout.dart';

/// 위성 kindPrefix → GraphNodeKind · 색 — 관계망 10대 카테고리.
GraphNodeKind graphNodeKindForSatellitePrefix(String kindPrefix) {
  return switch (kindPrefix) {
    'person' => GraphNodeKind.person,
    'pet' => GraphNodeKind.pet,
    'place' => GraphNodeKind.place,
    'organization' => GraphNodeKind.organization,
    'event' => GraphNodeKind.event,
    'activity' => GraphNodeKind.activity,
    'content' => GraphNodeKind.content,
    'interest' => GraphNodeKind.interest,
    'food' => GraphNodeKind.food,
    'hobby' => GraphNodeKind.hobby,
    'goal' => GraphNodeKind.goal,
    'emotion' => GraphNodeKind.emotion,
    _ => GraphNodeKind.activity,
  };
}

Color graphColorForSatellitePrefix(String kindPrefix) {
  return graphNodeKindColor(graphNodeKindForSatellitePrefix(kindPrefix));
}

int graphSatelliteMaxForPrefix(String kindPrefix) {
  return switch (kindPrefix) {
    'person' => 12,
    'pet' => 6,
    'place' => 3,
    'organization' => 6,
    'event' => 3,
    'activity' => 3,
    'content' => 2,
    'interest' => 3,
    'food' => 2,
    'hobby' => 2,
    'goal' => 1,
    'emotion' => 2,
    _ => 2,
  };
}

String graphSatelliteKindLabel(String kindPrefix, String localeCode) {
  if (localeCode == 'ko') {
    return switch (kindPrefix) {
      'person' => '사람',
      'pet' => '반려견',
      'place' => '장소',
      'organization' => '조직',
      'event' => '이벤트',
      'activity' => '활동',
      'content' => '콘텐츠',
      'interest' => '관심사',
      'food' => '음식',
      'hobby' => '취미',
      'goal' => '목표',
      'emotion' => '감정',
      _ => '태그',
    };
  }
  return switch (kindPrefix) {
    'person' => 'Person',
    'pet' => 'Pet',
    'place' => 'Place',
    'organization' => 'Organization',
    'event' => 'Event',
    'activity' => 'Activity',
    'content' => 'Content',
    'interest' => 'Interest',
    'food' => 'Food',
    'hobby' => 'Hobby',
    'goal' => 'Goal',
    'emotion' => 'Emotion',
    _ => 'Tag',
  };
}
