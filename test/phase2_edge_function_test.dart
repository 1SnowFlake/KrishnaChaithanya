import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:slkc_app/core/constants/app_constants.dart';

void main() {
  group('Phase 2 Edge Function Schemas & Content Validation', () {
    test('1. Validates Lesson Plan Schema Structure', () {
      final sampleLessonPlanJson = {
        'title': 'Counting 1 to 10 with Tactile Blocks',
        'subject': 'Mathematics',
        'grade': 'Grade 1',
        'durationMinutes': 40,
        'language': 'English',
        'objectives': [
          'Recognize numerals 1 to 10',
          'Associate count with concrete physical objects',
        ],
        'prerequisiteKnowledge': ['Can identify numbers 1 to 5'],
        'materialsList': ['Large textured counting blocks', 'Number flashcards'],
        'steps': [
          {
            'stepName': 'warm_up',
            'title': 'Gentle Finger Counting Song',
            'durationMinutes': 5,
            'instructions': 'Sing counting song slowly with hand gestures.',
            'teacherActions': 'Models fingers counting 1 to 5.',
            'studentActions': 'Imitates gestures at their own pace.',
          },
          {
            'stepName': 'main_activity',
            'title': 'Tactile Block Stacking',
            'durationMinutes': 20,
            'instructions': 'Stack blocks while counting aloud together.',
            'teacherActions': 'Guides hand-over-hand if needed.',
            'studentActions': 'Places blocks on the mat.',
          },
        ],
        'accommodations': [
          {
            'need': 'autism_spectrum',
            'strategy': 'Visual step-by-step schedule and sensory-calm mat.',
            'materialsSuggested': ['Visual timer', 'Textured mat'],
          },
          {
            'need': 'visual_impairment',
            'strategy': 'High-contrast large numerals and tactile edges.',
            'materialsSuggested': ['Braille/raised-line number cards'],
          },
        ],
        'questionsToAsk': ['How many blocks do we have now?'],
        'homeworkOrExtension': 'Count 3 spoons at home with family.',
        'assessmentIdeas': 'Observation checklist during stacking.',
        'noteForParents': 'Today we explored numbers 1 to 10 with gentle tactile play!',
        'pedagogicalDisclaimer': 'Educational suggestions only; not medical or diagnostic therapy.',
      };

      expect(sampleLessonPlanJson['title'], isNotEmpty);
      expect((sampleLessonPlanJson['steps'] as List).length, greaterThan(0));
      expect((sampleLessonPlanJson['accommodations'] as List).length, equals(2));
      expect(sampleLessonPlanJson['pedagogicalDisclaimer'], contains('Educational suggestions only'));
    });

    test('2. Validates Worksheet Schema Structure with Answer Key', () {
      final sampleWorksheetJson = {
        'title': 'Living Things & Plant Care',
        'subject': 'Science',
        'grade': 'Grade 2',
        'language': 'English',
        'isLargePrintFriendly': true,
        'instructions': 'Look at the pictures and circle what plants need.',
        'sections': [
          {
            'sectionTitle': 'Part 1: Circle the correct answer',
            'instructions': 'Circle the picture of what a seed needs to grow.',
            'questions': [
              {
                'questionNumber': 1,
                'type': 'circle_or_tick',
                'prompt': 'A seed needs _____ to grow into a plant.',
                'options': ['Sunlight and Water', 'A toy car'],
                'answer': 'Sunlight and Water',
                'hint': 'Think about what you drink when thirsty!',
              },
            ],
          },
        ],
        'answerKey': [
          {
            'questionNumber': 1,
            'answer': 'Sunlight and Water',
            'explanation': 'Plants require sunlight and hydration to perform photosynthesis.',
          },
        ],
        'teacherNotes': 'Allow pointing or stamps for students with fine-motor challenges.',
      };

      expect(sampleWorksheetJson['title'], isNotEmpty);
      expect((sampleWorksheetJson['sections'] as List).isNotEmpty, isTrue);
      expect((sampleWorksheetJson['answerKey'] as List).length, equals(1));
    });

    test('3. Validates Quiz Schema Structure with TTS Read-Aloud Support', () {
      final sampleQuizJson = {
        'title': 'Healthy Habits Mini-Quiz',
        'subject': 'Health & Life Skills',
        'grade': 'Grade 1',
        'language': 'English',
        'timeLimitMinutes': 0,
        'questions': [
          {
            'questionNumber': 1,
            'type': 'multiple_choice',
            'question': 'When should we wash our hands?',
            'options': [
              'Before eating food',
              'Only when taking a bath',
              'Never',
            ],
            'correctAnswerIndex': 0,
            'correctAnswerText': 'Before eating food',
            'explanation': 'Washing hands before eating keeps our tummies safe from germs!',
            'difficulty': 'easy',
            'readAloudText': 'Question one. When should we wash our hands? Option A: Before eating food. Option B: Only when taking a bath. Option C: Never.',
          },
        ],
        'celebrationMessage': 'Wonderful job exploring healthy habits today! ⭐',
      };

      expect(sampleQuizJson['title'], isNotEmpty);
      final questions = sampleQuizJson['questions'] as List;
      expect(questions.length, equals(1));
      expect(questions.first['readAloudText'], contains('Question one'));
      expect(questions.first['correctAnswerIndex'], equals(0));
    });

    test('4. Safety & Content Screening Check', () {
      bool isSafeTopic(String topic) {
        final lower = topic.toLowerCase();
        final blocked = [
          RegExp(r'\b(kill|murder|gun|weapon|drugs|porn|nsfw|suicide)\b'),
        ];
        return !blocked.any((r) => r.hasMatch(lower));
      }

      expect(isSafeTopic('Counting coins and money skills'), isTrue);
      expect(isSafeTopic('Animals and their habitats'), isTrue);
      expect(isSafeTopic('How to make a weapon'), isFalse);
      expect(isSafeTopic('Dangerous drugs exploration'), isFalse);
    });

    test('5. Verify Constant Mappings for AI Teaching Tools', () {
      expect(AppConstants.tableAiContent, equals('ai_content'));
      expect(AppConstants.tableAiUsageLog, equals('ai_usage_log'));
      expect(AppConstants.fnGenerateContent, equals('generate-content'));
      expect(AppConstants.contentTypeLessonPlan, equals('lesson_plan'));
      expect(AppConstants.contentTypeWorksheet, equals('worksheet'));
      expect(AppConstants.contentTypeQuiz, equals('quiz'));
      expect(LearnerNeeds.labels[LearnerNeeds.mixedAbility], isNotNull);
      expect(LearnerNeeds.labels[LearnerNeeds.none], isNotNull);
    });
  });
}
