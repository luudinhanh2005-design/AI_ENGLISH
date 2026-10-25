import 'package:flutter_test/flutter_test.dart';

import 'package:english_ai/features/placement/data/models/placement_models.dart';

void main() {
  test('PlacementConfigModel parses modes and labels', () {
    final config = PlacementConfigModel.fromJson({
      'version': '2.0.0',
      'description': 'blueprint',
      'skill_labels': {'listening': 'Nghe'},
      'modes': {
        'quick': {
          'label': 'Quick',
          'description': 'fast',
          'skills': ['listening', 'reading'],
          'stages': 2,
          'items_per_stage': 4,
          'time_limit_seconds': 1200,
          'writing_tasks': 0,
          'speaking_tasks': 0,
        },
      },
      'cut_scores': {'B2': 0.0},
      'level_labels': {'B1': 'Intermediate'},
      'level_descriptions_vi': {'B1': 'Mo ta'},
      'exam_mapping': {'note': 'reference'},
      'can_do': {'B1': ['Can do something']},
    });

    expect(config.version, '2.0.0');
    expect(config.modes['quick']!.totalItems, 16);
    expect(config.skillLabel('listening'), 'Nghe');
    expect(config.levelLabel('B1'), 'Intermediate');
  });

  test('PlacementResultModel parses skill and can-do maps', () {
    final result = PlacementResultModel.fromJson({
      'result_id': 'r1',
      'session_id': 's1',
      'mode': 'quick',
      'target_exam': 'ielts',
      'blueprint_version': '2.0.0',
      'completed_at': '2026-10-24T00:00:00Z',
      'overall': {
        'level': 'B1',
        'theta': 0.1,
        'se': 0.4,
        'level_range': ['B1', 'B1'],
        'confidence': 'medium',
        'confidence_vi': 'Trung bình',
        'level_label': 'Intermediate',
        'description_vi': 'Mo ta',
      },
      'skills': {
        'listening': {
          'label': 'Nghe',
          'level': 'B1',
          'theta': 0.2,
          'se': 0.3,
          'level_range': ['B1', 'B1'],
          'type': 'receptive',
          'correct': 6,
          'total': 8,
          'percent': 75,
          'weight': 0.25,
          'can_do': ['Understand simple conversations'],
        },
      },
      'strengths': [],
      'weaknesses': [],
      'profile_consistency': 'consistent',
      'recommendation': 'Keep practicing',
      'roadmap': [],
      'exam_equivalents': {'ielts': '4.0-5.0'},
      'can_do': {
        'listening': ['Understand simple conversations'],
      },
      'review': [],
      'xp_awarded': 80,
    });

    expect(result.overall.level, 'B1');
    expect(result.skills['listening']!.correct, 6);
    expect(result.canDo['listening'], ['Understand simple conversations']);
    expect(result.xpAwarded, 80);
  });
}
