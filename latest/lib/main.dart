import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

// ─── YOUR FIREBASE CONFIG ───────────────────────────────────────────
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'AIzaSyDvgJICpWwGo0rAN-asYGc9RpeK7inLznc',
      appId: '1:781788885501:web:b5e095a0f6d5ab3bb454394',
      messagingSenderId: '781788885501',
      projectId: 'aura-6894',
      authDomain: 'aura-6894.firebaseapp.com',
      storageBucket: 'aura-6894.firebasestorage.app',
    );
  }
}

// ─── FIREBASE SERVICE ───────────────────────────────────────────────
class FirebaseService {
  static bool _initialized = false;
  static bool _isAvailable = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      print("🔥 Initializing Firebase...");
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _isAvailable = true;
      print("✅ Firebase initialized successfully");
    } catch (e) {
      print("❌ Firebase init failed: $e");
      print("⚠️ Running in DEMO mode");
      _isAvailable = false;
    }
    _initialized = true;
  }

  static bool get isAvailable => _initialized && _isAvailable;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("🚀 AURA AI starting...");

  await FirebaseService.initialize();
  runApp(const AuraApp());
}

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const BootSequence(),
    );
  }
}

// ─── VOICE SERVICE (Simulated) ──────────────────────────────────────
class VoiceService {
  static String _selectedVoice = "female";

  static Future<void> init() async {
    print("Voice service initialized");
  }

  static Future<void> setVoice(String gender) async {
    _selectedVoice = gender;
    print("Voice set to: $gender");
  }

  static String get currentVoice => _selectedVoice;

  static Future<void> speak(String text) async {
    print("🗣️ AURA (${_selectedVoice == "female" ? "♀" : "♂"}): $text");
  }

  static Future<String?> listen() async {
    print("🎤 Listening...");
    await Future.delayed(const Duration(seconds: 2));
    return "What is Python?";
  }
}

// ─── BADGE SYSTEM ───────────────────────────────────────────────────
enum BadgeLevel { none, bronze, silver, gold, superGold }

class Badge {
  final BadgeLevel level;
  final String name;
  final Color color;
  final String icon;
  final double minScore;
  final double maxScore;

  const Badge({
    required this.level,
    required this.name,
    required this.color,
    required this.icon,
    required this.minScore,
    required this.maxScore,
  });
}

final List<Badge> badges = [
  Badge(
    level: BadgeLevel.bronze,
    name: "Bronze",
    color: const Color(0xFFCD7F32),
    icon: "🥉",
    minScore: 50,
    maxScore: 60,
  ),
  Badge(
    level: BadgeLevel.silver,
    name: "Silver",
    color: const Color(0xFFC0C0C0),
    icon: "🥈",
    minScore: 61,
    maxScore: 80,
  ),
  Badge(
    level: BadgeLevel.gold,
    name: "Gold",
    color: const Color(0xFFFFD700),
    icon: "🥇",
    minScore: 81,
    maxScore: 99,
  ),
  Badge(
    level: BadgeLevel.superGold,
    name: "SUPER GOLD",
    color: const Color(0xFFFFD700),
    icon: "👑✨",
    minScore: 100,
    maxScore: 100,
  ),
];

Badge getBadgeFromScore(double score) {
  if (score >= 100) return badges[3];
  if (score >= 81) return badges[2];
  if (score >= 61) return badges[1];
  if (score >= 50) return badges[0];
  return Badge(
    level: BadgeLevel.none,
    name: "No Badge",
    color: Colors.grey,
    icon: "⚪",
    minScore: 0,
    maxScore: 49,
  );
}

// ─── COURSE STRUCTURE ──────────────────────────────────────────────
class Topic {
  final String id;
  final String title;
  bool completed;
  double quizScore;
  bool quizPassed;

  Topic({
    required this.id,
    required this.title,
    this.completed = false,
    this.quizScore = 0,
    this.quizPassed = false,
  });
}

class Unit {
  final String id;
  final String title;
  List<Topic> topics;
  bool formativeCompleted;
  double formativeScore;
  bool formativePassed;
  DateTime? examAvailableDate;
  bool examCompleted;
  double examScore;
  bool examPassed;

  Unit({
    required this.id,
    required this.title,
    required this.topics,
    this.formativeCompleted = false,
    this.formativeScore = 0,
    this.formativePassed = false,
    this.examAvailableDate,
    this.examCompleted = false,
    this.examScore = 0,
    this.examPassed = false,
  });
}

class Course {
  final String id;
  final String title;
  final SkillLevel level;
  List<Unit> units;
  bool certificateEarned;
  BadgeLevel finalBadge;
  double finalScore;
  int worldRank;

  Course({
    required this.id,
    required this.title,
    required this.level,
    required this.units,
    this.certificateEarned = false,
    this.finalBadge = BadgeLevel.none,
    this.finalScore = 0,
    this.worldRank = 0,
  });
}

Course createSampleCourse(SkillLevel level) {
  if (level == SkillLevel.beginner) {
    return Course(
      id: "python_basics",
      title: "Python Programming Basics",
      level: level,
      units: [
        Unit(
          id: "unit1",
          title: "Python Fundamentals",
          topics: [
            Topic(id: "topic1", title: "Variables and Data Types"),
            Topic(id: "topic2", title: "Control Flow (if/else)"),
            Topic(id: "topic3", title: "Loops (for/while)"),
          ],
        ),
        Unit(
          id: "unit2",
          title: "Functions and Modules",
          topics: [
            Topic(id: "topic4", title: "Defining Functions"),
            Topic(id: "topic5", title: "Function Parameters"),
            Topic(id: "topic6", title: "Importing Modules"),
          ],
        ),
        Unit(
          id: "unit3",
          title: "Data Structures",
          topics: [
            Topic(id: "topic7", title: "Lists and Tuples"),
            Topic(id: "topic8", title: "Dictionaries"),
            Topic(id: "topic9", title: "Sets"),
          ],
        ),
      ],
    );
  }
  return Course(
    id: "default",
    title: "Course",
    level: level,
    units: [],
  );
}

// ─── QUIZ SERVICE ───────────────────────────────────────────────────
class QuizService {
  static List<Map<String, dynamic>> generateQuiz(String topic) {
    return [
      {
        'question': 'What is the correct way to create a variable in Python?',
        'options': ['var x = 5', 'x = 5', 'int x = 5', 'let x = 5'],
        'correct': 1,
      },
      {
        'question': 'Which of these is a valid variable name?',
        'options': ['2var', 'my-var', 'my_var', 'my var'],
        'correct': 2,
      },
      {
        'question': 'What is the output of print(2 ** 3)?',
        'options': ['5', '6', '8', '9'],
        'correct': 2,
      },
      {
        'question': 'Which data type is immutable in Python?',
        'options': ['List', 'Dictionary', 'Tuple', 'Set'],
        'correct': 2,
      },
      {
        'question': 'How do you create a function in Python?',
        'options': [
          'function myFunc():',
          'def myFunc():',
          'func myFunc():',
          'create myFunc():'
        ],
        'correct': 1,
      },
    ];
  }

  static double calculateScore(
      List<int> answers, List<Map<String, dynamic>> quiz) {
    int correct = 0;
    for (int i = 0; i < answers.length; i++) {
      if (answers[i] == quiz[i]['correct']) {
        correct++;
      }
    }
    return (correct / quiz.length) * 100;
  }

  static bool isPassed(double score, String assessmentType) {
    switch (assessmentType) {
      case 'quiz':
        return score >= 50;
      case 'formative':
        return score >= 70;
      case 'exam':
        return score >= 80;
      default:
        return false;
    }
  }
}

// ─── ENHANCED PIN STORAGE ───────────────────────────────────────────
class PinStorage {
  static const String _pinKey = 'app_pin';
  static const String _isLockedKey = 'is_locked';
  static const String _rememberMeKey = 'remember_me';
  static const String _savedEmailKey = 'saved_email';
  static const String _savedProviderKey = 'saved_provider';
  static const String _lastUnlockKey = 'last_unlock_time';
  static const String _streakKey = 'learning_streak';
  static const String _lastLearnedKey = 'last_learned_date';
  static const String _xpKey = 'user_xp';
  static const String _completedCoursesKey = 'completed_courses';
  static const String _coursesKey = 'enrolled_courses';
  static const String _notesKey = 'saved_notes';
  static const String _bookmarksKey = 'bookmarks';
  static const String _voicePrefKey = 'voice_preference';

  // ─── VOICE PREFERENCE ───────────────────────────────────────────
  static Future<void> setVoicePreference(String voice) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_voicePrefKey, voice);
    } catch (e) {}
  }

  static Future<String> getVoicePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_voicePrefKey) ?? 'female';
    } catch (e) {
      return 'female';
    }
  }

  // ─── COURSE PROGRESS ────────────────────────────────────────────
  static Future<void> saveCourseProgress(Course course) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      Map<String, dynamic> courseJson = {
        'id': course.id,
        'title': course.title,
        'level': course.level.index,
        'certificateEarned': course.certificateEarned,
        'finalBadge': course.finalBadge.index,
        'finalScore': course.finalScore,
        'worldRank': course.worldRank,
        'units': course.units
            .map((unit) => {
                  'id': unit.id,
                  'title': unit.title,
                  'formativeCompleted': unit.formativeCompleted,
                  'formativeScore': unit.formativeScore,
                  'formativePassed': unit.formativePassed,
                  'examAvailableDate':
                      unit.examAvailableDate?.toIso8601String(),
                  'examCompleted': unit.examCompleted,
                  'examScore': unit.examScore,
                  'examPassed': unit.examPassed,
                  'topics': unit.topics
                      .map((topic) => {
                            'id': topic.id,
                            'title': topic.title,
                            'completed': topic.completed,
                            'quizScore': topic.quizScore,
                            'quizPassed': topic.quizPassed,
                          })
                      .toList(),
                })
            .toList(),
      };

      await prefs.setString('course_${course.id}', jsonEncode(courseJson));

      List<String> enrolled = prefs.getStringList(_coursesKey) ?? [];
      if (!enrolled.contains(course.id)) {
        enrolled.add(course.id);
        await prefs.setStringList(_coursesKey, enrolled);
      }
    } catch (e) {}
  }

  static Future<Course?> loadCourse(String courseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? courseJson = prefs.getString('course_$courseId');

      if (courseJson != null) {
        Map<String, dynamic> data = jsonDecode(courseJson);

        List<Unit> units = (data['units'] as List)
            .map((unitData) => Unit(
                  id: unitData['id'],
                  title: unitData['title'],
                  topics: (unitData['topics'] as List)
                      .map((topicData) => Topic(
                            id: topicData['id'],
                            title: topicData['title'],
                            completed: topicData['completed'] ?? false,
                            quizScore: (topicData['quizScore'] ?? 0).toDouble(),
                            quizPassed: topicData['quizPassed'] ?? false,
                          ))
                      .toList(),
                  formativeCompleted: unitData['formativeCompleted'] ?? false,
                  formativeScore: (unitData['formativeScore'] ?? 0).toDouble(),
                  formativePassed: unitData['formativePassed'] ?? false,
                  examAvailableDate: unitData['examAvailableDate'] != null
                      ? DateTime.parse(unitData['examAvailableDate'])
                      : null,
                  examCompleted: unitData['examCompleted'] ?? false,
                  examScore: (unitData['examScore'] ?? 0).toDouble(),
                  examPassed: unitData['examPassed'] ?? false,
                ))
            .toList();

        return Course(
          id: data['id'],
          title: data['title'],
          level: SkillLevel.values[data['level']],
          units: units,
          certificateEarned: data['certificateEarned'] ?? false,
          finalBadge: BadgeLevel.values[data['finalBadge'] ?? 0],
          finalScore: (data['finalScore'] ?? 0).toDouble(),
          worldRank: data['worldRank'] ?? 0,
        );
      }
    } catch (e) {}
    return null;
  }

  static Future<List<String>> getEnrolledCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_coursesKey) ?? [];
    } catch (e) {
      return [];
    }
  }

  // ─── WORLD RANKING ──────────────────────────────────────────────
  static Future<void> updateWorldRank(String courseId, double score) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rankKey = 'rank_$courseId';
      int currentRank = prefs.getInt(rankKey) ?? 1000;

      if (score == 100) {
        await prefs.setInt(rankKey, 1);
      } else if (score >= 95) {
        await prefs.setInt(rankKey, math.max(1, currentRank - 10));
      }
    } catch (e) {}
  }

  static Future<int> getWorldRank(String courseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('rank_$courseId') ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ─── PIN METHODS ─────────────────────────────────────────────────
  static Future<bool> savePin(String pin) async {
    try {
      if (pin.isEmpty || pin.length != 4) {
        print("❌ Cannot save: PIN must be exactly 4 digits");
        return false;
      }

      if (!RegExp(r'^[0-9]+$').hasMatch(pin)) {
        print("❌ Cannot save: PIN must contain only numbers");
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pinKey, pin);
      await prefs.setBool(_isLockedKey, true);
      print("✅ PIN saved successfully: $pin");
      return true;
    } catch (e) {
      debugPrint('⚠️ Pin storage failed: $e');
      return false;
    }
  }

  static Future<bool> verifyPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_pinKey);

      if (stored == null || stored.isEmpty || stored.length != 4) {
        print("⚠️ Invalid PIN found in storage, clearing...");
        await clearPin();
        return false;
      }

      return stored == pin;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> hasPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pin = prefs.getString(_pinKey);

      if (pin == null || pin.isEmpty || pin.length != 4) {
        if (pin != null) {
          await clearPin();
        }
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isLocked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isLockedKey) ?? true;
    } catch (e) {
      return true;
    }
  }

  static Future<void> setLocked(bool locked) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLockedKey, locked);
    } catch (e) {}
  }

  static Future<bool> changePin(String oldPin, String newPin) async {
    try {
      final isValid = await verifyPin(oldPin);
      if (!isValid) return false;

      if (newPin.isEmpty || newPin.length != 4) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pinKey, newPin);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> clearPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pinKey);
      await prefs.remove(_isLockedKey);
      print("✅ PIN cleared");
    } catch (e) {}
  }

  // ─── REMEMBER ME METHODS ─────────────────────────────────────────
  static Future<void> setRememberMe(bool remember,
      {String? email, String? provider}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_rememberMeKey, remember);
      if (remember && email != null) {
        await prefs.setString(_savedEmailKey, email);
        if (provider != null) {
          await prefs.setString(_savedProviderKey, provider);
        }
      } else if (!remember) {
        await prefs.remove(_savedEmailKey);
        await prefs.remove(_savedProviderKey);
      }
    } catch (e) {}
  }

  static Future<bool> getRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_rememberMeKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> getSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_savedEmailKey);
    } catch (e) {
      return null;
    }
  }

  static Future<String?> getSavedProvider() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_savedProviderKey);
    } catch (e) {
      return null;
    }
  }

  // ─── QUICK UNLOCK METHODS ────────────────────────────────────────
  static Future<void> saveUnlockTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastUnlockKey, DateTime.now().millisecondsSinceEpoch);
      print("✅ Unlock time saved");
    } catch (e) {}
  }

  static Future<DateTime?> getLastUnlockTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final time = prefs.getInt(_lastUnlockKey);
      return time != null ? DateTime.fromMillisecondsSinceEpoch(time) : null;
    } catch (e) {
      return null;
    }
  }

  // ─── PROGRESS TRACKING METHODS ───────────────────────────────────
  static Future<void> updateStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDate = prefs.getString(_lastLearnedKey);
      final today = DateTime.now().toIso8601String().split('T')[0];

      int currentStreak = prefs.getInt(_streakKey) ?? 0;
      int currentXP = prefs.getInt(_xpKey) ?? 0;

      if (lastDate == null) {
        await prefs.setInt(_streakKey, 1);
        await prefs.setInt(_xpKey, currentXP + 10);
      } else if (lastDate == today) {
        await prefs.setInt(_xpKey, currentXP + 5);
      } else {
        final yesterday = DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String()
            .split('T')[0];

        if (lastDate == yesterday) {
          currentStreak++;
          await prefs.setInt(_streakKey, currentStreak);
          await prefs.setInt(_xpKey, currentXP + 10 + (currentStreak * 2));
        } else {
          await prefs.setInt(_streakKey, 1);
          await prefs.setInt(_xpKey, currentXP + 10);
        }
      }

      await prefs.setString(_lastLearnedKey, today);
    } catch (e) {}
  }

  static Future<Map<String, int>> getProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int xp = prefs.getInt(_xpKey) ?? 0;
      return {
        'streak': prefs.getInt(_streakKey) ?? 0,
        'xp': xp,
        'level': (xp ~/ 100) + 1,
        'nextLevelXp': 100 - (xp % 100),
      };
    } catch (e) {
      return {'streak': 0, 'xp': 0, 'level': 1, 'nextLevelXp': 100};
    }
  }

  static Future<void> completeCourse(String courseName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> completed = prefs.getStringList(_completedCoursesKey) ?? [];
      if (!completed.contains(courseName)) {
        completed.add(courseName);
        await prefs.setStringList(_completedCoursesKey, completed);
        int currentXP = prefs.getInt(_xpKey) ?? 0;
        await prefs.setInt(_xpKey, currentXP + 50);
        await updateStreak();
      }
    } catch (e) {}
  }

  static Future<List<String>> getCompletedCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_completedCoursesKey) ?? [];
    } catch (e) {
      return [];
    }
  }

  // ─── NOTES & BOOKMARKS METHODS ───────────────────────────────────
  static Future<void> saveNote(String title, String content) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> notes = {};

      final String? notesJson = prefs.getString(_notesKey);
      if (notesJson != null) {
        notes = Map<String, dynamic>.from(jsonDecode(notesJson));
      }

      notes[DateTime.now().toIso8601String()] = {
        'title': title,
        'content': content,
        'date': DateTime.now().toIso8601String(),
      };

      await prefs.setString(_notesKey, jsonEncode(notes));
    } catch (e) {}
  }

  static Future<Map<String, dynamic>> getNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? notesJson = prefs.getString(_notesKey);
      if (notesJson != null) {
        return Map<String, dynamic>.from(jsonDecode(notesJson));
      }
    } catch (e) {}
    return {};
  }

  static Future<void> deleteNote(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? notesJson = prefs.getString(_notesKey);
      if (notesJson != null) {
        Map<String, dynamic> notes =
            Map<String, dynamic>.from(jsonDecode(notesJson));
        notes.remove(key);
        await prefs.setString(_notesKey, jsonEncode(notes));
      }
    } catch (e) {}
  }

  static Future<void> addBookmark(String content) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> bookmarks = prefs.getStringList(_bookmarksKey) ?? [];
      bookmarks.add(content);
      await prefs.setStringList(_bookmarksKey, bookmarks);
    } catch (e) {}
  }

  static Future<List<String>> getBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_bookmarksKey) ?? [];
    } catch (e) {
      return [];
    }
  }
}

// ─── OLLAMA SERVICE ─────────────────────────────────────────────────
class OllamaService {
  static const String _baseUrl = 'http://localhost:11434';
  static const String _model = 'llama3';

  static Future<String> generate({
    required String prompt,
    required String systemPrompt,
    required Function(String chunk) onChunk,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/generate');

    try {
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'model': _model,
        'prompt': prompt,
        'system': systemPrompt,
        'stream': true,
      });

      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Ollama timeout'),
          );

      if (streamedResponse.statusCode != 200) {
        throw Exception(
            'Ollama returned status ${streamedResponse.statusCode}');
      }

      final StringBuffer fullResponse = StringBuffer();

      await for (final chunk in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (chunk.isEmpty) continue;
        try {
          final json = jsonDecode(chunk) as Map<String, dynamic>;
          final text = json['response'] as String? ?? '';
          if (text.isNotEmpty) {
            fullResponse.write(text);
            onChunk(fullResponse.toString());
          }
          if (json['done'] == true) break;
        } catch (_) {}
      }

      return fullResponse.toString();
    } catch (e) {
      return "⚠️ Ollama not running. Start with: ollama serve";
    }
  }

  static String buildSystemPrompt(String levelName, String? selectedCourse) {
    final courseContext = selectedCourse != null
        ? 'The user is currently studying: $selectedCourse. '
        : '';
    return '''You are AURA, an AI learning assistant for IT and programming education.
$courseContext The user's skill level is: $levelName.

Guidelines:
- Tailor your explanations to a $levelName level student.
- Be concise but thorough. Use examples when helpful.
- For code examples, use proper formatting.
- If asked about topics outside IT/programming, gently redirect to tech topics.
- Start responses directly without preamble.
- Keep responses focused and educational.''';
  }

  static Future<bool> isAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/tags'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

// ─── LEVEL MODELS ────────────────────────────────────────────────────
enum SkillLevel { beginner, intermediate, advanced, expert }

class LevelInfo {
  final SkillLevel level;
  final String name;
  final String description;
  final Color color;
  final List<String> courses;

  const LevelInfo({
    required this.level,
    required this.name,
    required this.description,
    required this.color,
    required this.courses,
  });
}

final List<LevelInfo> levels = [
  LevelInfo(
    level: SkillLevel.beginner,
    name: "BEGINNER",
    description: "New to coding? Start here!",
    color: const Color(0xFF39FF14),
    courses: [
      "📚 Introduction to Programming",
      "🐍 Python Basics",
      "🌐 HTML & CSS Fundamentals",
      "📊 Data Structures 101",
      "🔧 Git & GitHub Basics",
    ],
  ),
  LevelInfo(
    level: SkillLevel.intermediate,
    name: "INTERMEDIATE",
    description: "You know the basics, time to level up!",
    color: const Color(0xFF00C8FF),
    courses: [
      "⚡ Advanced Python",
      "🗄️ Database Management",
      "📱 Mobile App Development",
      "🔌 REST APIs & Integration",
      "🐳 Docker Essentials",
    ],
  ),
  LevelInfo(
    level: SkillLevel.advanced,
    name: "ADVANCED",
    description: "Ready for complex systems",
    color: const Color(0xFFD4AF37),
    courses: [
      "🧠 Machine Learning Basics",
      "☁️ Cloud Architecture (AWS/GCP)",
      "🔐 Cybersecurity Fundamentals",
      "📈 System Design",
      "⚙️ DevOps Practices",
    ],
  ),
  LevelInfo(
    level: SkillLevel.expert,
    name: "EXPERT",
    description: "Master-level content",
    color: const Color(0xFF888888),
    courses: [
      "🤖 Advanced AI/ML",
      "🔮 Quantum Computing",
      "🌌 Distributed Systems",
      "🛡️ Advanced Security",
      "🚀 Performance Optimization",
    ],
  ),
];

// ─── LOCK SCREEN with Quick Unlock ─────────────────────────────────
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  const LockScreen({super.key, required this.onUnlock});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late AnimationController _quickUnlockController;

  String _pin = "";
  String _statusMessage = "Enter PIN";
  bool _isSettingPin = false;
  String _newPin = "";
  String _confirmPin = "";

  bool _quickUnlockEnabled = true;
  int _tapCount = 0;
  Timer? _tapTimer;
  DateTime? _lastUnlockTime;
  static const int _quickUnlockTimeout = 30;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);

    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _quickUnlockController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));

    _checkPinExists();
    _loadLastUnlockTime();
  }

  Future<void> _loadLastUnlockTime() async {
    _lastUnlockTime = await PinStorage.getLastUnlockTime();
  }

  Future<void> _saveUnlockTime() async {
    await PinStorage.saveUnlockTime();
  }

  bool get _canQuickUnlock {
    if (_lastUnlockTime == null) return false;
    final difference = DateTime.now().difference(_lastUnlockTime!);
    return difference.inSeconds < _quickUnlockTimeout;
  }

  Future<void> _checkPinExists() async {
    final hasPin = await PinStorage.hasPin();
    setState(() {
      _isSettingPin = !hasPin;
      _statusMessage = hasPin ? "Enter PIN" : "Create a 4-digit PIN";
    });
  }

  void _handleQuickUnlock() {
    if (!_quickUnlockEnabled || !_canQuickUnlock) {
      _showNormalUnlock();
      return;
    }

    _quickUnlockController.forward().then((_) {
      _quickUnlockController.reverse();
    });

    _tapCount++;
    _tapTimer?.cancel();

    if (_tapCount == 1) {
      setState(() {
        _statusMessage = "Tap again to quick unlock";
      });

      _tapTimer = Timer(const Duration(milliseconds: 500), () {
        setState(() {
          _tapCount = 0;
          _statusMessage = "Enter PIN";
        });
      });
    } else if (_tapCount >= 2) {
      _tapTimer?.cancel();
      _tapCount = 0;

      setState(() {
        _statusMessage = "✓ Quick Unlock!";
      });

      Future.delayed(const Duration(milliseconds: 300), () {
        widget.onUnlock();
      });
    }
  }

  void _showNormalUnlock() {
    setState(() {
      _statusMessage =
          _canQuickUnlock ? "Double-tap lock to quick unlock" : "Enter PIN";
    });
  }

  void _onPinDigitPressed(String digit) {
    if (_isSettingPin) {
      if (_newPin.length < 4) {
        setState(() {
          _newPin += digit;
        });

        if (_newPin.length == 4) {
          setState(() {
            _statusMessage = "Confirm PIN";
          });
        }
      } else if (_confirmPin.length < 4 && _newPin.length == 4) {
        setState(() {
          _confirmPin += digit;
        });

        if (_confirmPin.length == 4) {
          _verifyNewPin();
        }
      }
    } else {
      if (_pin.length < 4) {
        setState(() {
          _pin += digit;
        });

        if (_pin.length == 4) {
          _verifyPin();
        }
      }
    }
  }

  void _onDeletePressed() {
    if (_isSettingPin) {
      if (_confirmPin.isNotEmpty) {
        setState(() {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        });
      } else if (_newPin.isNotEmpty) {
        setState(() {
          _newPin = _newPin.substring(0, _newPin.length - 1);
          if (_newPin.length < 4) {
            _statusMessage = "Create a 4-digit PIN";
          }
        });
      }
    } else {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
        });
      }
    }
  }

  Future<void> _verifyNewPin() async {
    if (_newPin.length != 4) {
      setState(() {
        _statusMessage = "PIN must be 4 digits";
        _newPin = "";
        _confirmPin = "";
      });
      _shakeController.forward().then((_) => _shakeController.reset());
      return;
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(_newPin)) {
      setState(() {
        _statusMessage = "PIN must contain only numbers";
        _newPin = "";
        _confirmPin = "";
      });
      _shakeController.forward().then((_) => _shakeController.reset());
      return;
    }

    if (_newPin == _confirmPin) {
      bool saved = await PinStorage.savePin(_newPin);

      if (saved) {
        setState(() {
          _isSettingPin = false;
          _statusMessage = "PIN created! Enter to unlock";
        });
      } else {
        setState(() {
          _statusMessage = "Error saving PIN. Try again";
          _newPin = "";
          _confirmPin = "";
        });
      }
      _shakeController.forward().then((_) => _shakeController.reset());
    } else {
      setState(() {
        _statusMessage = "PINs don't match. Try again";
        _newPin = "";
        _confirmPin = "";
      });
      _shakeController.forward().then((_) => _shakeController.reset());
    }
  }

  Future<void> _verifyPin() async {
    final isValid = await PinStorage.verifyPin(_pin);

    if (isValid) {
      await _saveUnlockTime();
      widget.onUnlock();
    } else {
      setState(() {
        _pin = "";
        _statusMessage = "Wrong PIN. Try again";
      });
      _shakeController.forward().then((_) => _shakeController.reset());
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    _quickUnlockController.dispose();
    _tapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF050A0E),
      body: Stack(
        children: [
          CustomPaint(
            painter: _GridPainter(const Color(0xFF39FF14), false),
            size: size,
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 20 : 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _handleQuickUnlock,
                        child: AnimatedBuilder(
                          animation: Listenable.merge(
                              [_pulseController, _quickUnlockController]),
                          builder: (_, __) {
                            double scale =
                                1.0 + _quickUnlockController.value * 0.2;

                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: isSmallScreen ? 100 : 120,
                                height: isSmallScreen ? 100 : 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      const Color(0xFF39FF14).withOpacity(0.3 +
                                          (_quickUnlockController.value * 0.3)),
                                      const Color(0xFF004010).withOpacity(0.1),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF39FF14)
                                          .withOpacity(
                                              0.3 * _pulseController.value +
                                                  (_quickUnlockEnabled &&
                                                          _canQuickUnlock
                                                      ? 0.2
                                                      : 0)),
                                      blurRadius: 30 +
                                          (_quickUnlockController.value * 20),
                                      spreadRadius: 5 +
                                          (_quickUnlockController.value * 5),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      _isSettingPin
                                          ? Icons.pin
                                          : Icons.lock_outline_rounded,
                                      color: const Color(0xFF39FF14),
                                      size: isSmallScreen ? 50 : 60,
                                    ),
                                    if (_quickUnlockEnabled && _canQuickUnlock)
                                      Positioned(
                                        bottom: 5,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.green.withOpacity(0.8),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            "QUICK",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: isSmallScreen ? 8 : 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _canQuickUnlock
                                ? Colors.green.withOpacity(0.5)
                                : const Color(0xFF39FF14).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color: _canQuickUnlock
                                ? Colors.green
                                : const Color(0xFF39FF14),
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_quickUnlockEnabled &&
                          _lastUnlockTime != null &&
                          _canQuickUnlock)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer, color: Colors.green, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                "Quick unlock: ${_quickUnlockTimeout - DateTime.now().difference(_lastUnlockTime!).inSeconds}s left",
                                style: const TextStyle(
                                    color: Colors.green, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      AnimatedBuilder(
                        animation: _shakeController,
                        builder: (_, __) {
                          return Transform.translate(
                            offset: Offset(
                              10 *
                                  math.sin(
                                      _shakeController.value * 20 * math.pi),
                              0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(4, (index) {
                                bool isFilled = _isSettingPin
                                    ? index < _newPin.length
                                    : index < _pin.length;
                                bool isConfirming = _isSettingPin &&
                                    _newPin.length == 4 &&
                                    index < _confirmPin.length;

                                return Container(
                                  width: 20,
                                  height: 20,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isFilled || isConfirming
                                        ? const Color(0xFF39FF14)
                                        : const Color(0xFF39FF14)
                                            .withOpacity(0.2),
                                    border: Border.all(
                                      color: const Color(0xFF39FF14)
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 30),
                      _buildPinPad(isSmallScreen),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Quick Unlock",
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _quickUnlockEnabled = !_quickUnlockEnabled;
                              });
                            },
                            child: Container(
                              width: 40,
                              height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: _quickUnlockEnabled
                                    ? Colors.green.withOpacity(0.5)
                                    : Colors.grey.withOpacity(0.3),
                              ),
                              child: AnimatedAlign(
                                duration: const Duration(milliseconds: 200),
                                alignment: _quickUnlockEnabled
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  margin: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinPad(bool isSmallScreen) {
    return Column(
      children: [
        Wrap(
          spacing: isSmallScreen ? 15 : 20,
          runSpacing: isSmallScreen ? 15 : 20,
          children: [
            '1',
            '2',
            '3',
            '4',
            '5',
            '6',
            '7',
            '8',
            '9',
          ].map((digit) {
            return _buildPinButton(digit, isSmallScreen);
          }).toList(),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPinButton('0', isSmallScreen),
            const SizedBox(width: 20),
            _buildPinButton('⌫', isSmallScreen, isDelete: true),
          ],
        ),
      ],
    );
  }

  Widget _buildPinButton(String text, bool isSmallScreen,
      {bool isDelete = false}) {
    return GestureDetector(
      onTap: isDelete ? _onDeletePressed : () => _onPinDigitPressed(text),
      child: Container(
        width: isSmallScreen ? 50 : 60,
        height: isSmallScreen ? 50 : 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.05),
          border: Border.all(
            color: const Color(0xFF39FF14).withOpacity(0.3),
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isDelete ? Colors.red : const Color(0xFF39FF14),
              fontSize: isDelete
                  ? (isSmallScreen ? 20 : 24)
                  : (isSmallScreen ? 24 : 28),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── BOOT SEQUENCE with Smart Unlock ────────────────────────────────
class BootSequence extends StatefulWidget {
  const BootSequence({super.key});
  @override
  State<BootSequence> createState() => _BootSequenceState();
}

class _BootSequenceState extends State<BootSequence>
    with SingleTickerProviderStateMixin {
  late AnimationController _bootController;
  String _bootText = "";
  bool _showingLevelSelect = false;
  bool _showLockScreen = false;
  bool _isQuickUnlockAvailable = false;

  final List<String> _bootLines = [
    "> INITIALIZING NEURAL INTERFACE...",
    "> LOADING KERNEL MODULES...",
    "> SCANNING USER PROFILE...",
    "> DETECTING SKILL LEVEL...",
    "> PLEASE SELECT YOUR LEVEL",
  ];

  @override
  void initState() {
    super.initState();
    _bootController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _bootController.forward();
    _checkLockStatus();
  }

  Future<void> _checkLockStatus() async {
    final hasPin = await PinStorage.hasPin();
    final lastUnlock = await PinStorage.getLastUnlockTime();

    if (lastUnlock != null) {
      final difference = DateTime.now().difference(lastUnlock);
      if (difference.inSeconds < 30) {
        _isQuickUnlockAvailable = true;
      }
    }

    setState(() {
      _showLockScreen = hasPin && !_isQuickUnlockAvailable;
    });

    if (!_showLockScreen) {
      _simulateBoot();
    }
  }

  Future<void> _simulateBoot() async {
    for (int i = 0; i < _bootLines.length; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) setState(() => _bootText += "${_bootLines[i]}\n");
    }
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _showingLevelSelect = true);
  }

  void _selectLevel(SkillLevel level) {
    setState(() {
      _bootText +=
          "\n> LEVEL SELECTED: ${level.name.toUpperCase()}\n> MOUNTING IDENTITY DISK...";
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => IdentityDisk(selectedLevel: level),
          ),
        );
      }
    });
  }

  void _onUnlock() {
    PinStorage.saveUnlockTime();
    setState(() {
      _showLockScreen = false;
    });
    _simulateBoot();
  }

  @override
  void dispose() {
    _bootController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showLockScreen) {
      return LockScreen(onUnlock: _onUnlock);
    }

    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF050A0E),
      body: Stack(
        children: [
          _buildBackground(),
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(const Color(0xFF39FF14), false),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 20 : 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isQuickUnlockAvailable)
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flash_on,
                                    color: Colors.green, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  "Quick Unlock Active! (30s)",
                                  style: TextStyle(color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          _bootText,
                          style: TextStyle(
                            color: const Color(0xFF39FF14),
                            fontFamily: 'monospace',
                            fontSize: isSmallScreen ? 12 : 14,
                            height: 2,
                          ),
                        ),
                        if (_showingLevelSelect) ...[
                          SizedBox(height: isSmallScreen ? 30 : 40),
                          ...List.generate(levels.length, (index) {
                            final level = levels[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: GestureDetector(
                                onTap: () => _selectLevel(level.level),
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      EdgeInsets.all(isSmallScreen ? 12 : 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                        color: level.color.withOpacity(0.5),
                                        width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                          color: level.color.withOpacity(0.2),
                                          blurRadius: 20,
                                          spreadRadius: 2)
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: isSmallScreen ? 40 : 50,
                                        height: isSmallScreen ? 40 : 50,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: level.color.withOpacity(0.2),
                                          border: Border.all(
                                              color: level.color, width: 2),
                                        ),
                                        child: Center(
                                          child: Text(level.name[0],
                                              style: TextStyle(
                                                  color: level.color,
                                                  fontSize:
                                                      isSmallScreen ? 20 : 24,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                      SizedBox(width: isSmallScreen ? 12 : 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(level.name,
                                                style: TextStyle(
                                                    color: level.color,
                                                    fontSize:
                                                        isSmallScreen ? 16 : 18,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 2)),
                                            const SizedBox(height: 4),
                                            Text(level.description,
                                                style: TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: isSmallScreen
                                                        ? 10
                                                        : 12)),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.arrow_forward_ios,
                                          color: level.color,
                                          size: isSmallScreen ? 16 : 20),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        Positioned(
          left: -50,
          top: 100,
          child: _bgTerminalWindow(
              width: size.width * 0.3, height: size.height * 0.4),
        ),
        Positioned(
          right: -50,
          bottom: 100,
          child: _bgVSCodeWindow(
              width: size.width * 0.35, height: size.height * 0.45),
        ),
      ],
    );
  }

  Widget _bgTerminalWindow({required double width, required double height}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117).withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF30363D), width: 1),
          ),
        ),
      ),
    );
  }

  Widget _bgVSCodeWindow({required double width, required double height}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E).withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF313244), width: 1),
          ),
        ),
      ),
    );
  }
}

// ─── IDENTITY DISK (LOGIN) ───────────────────────────────────────────
class IdentityDisk extends StatefulWidget {
  final SkillLevel selectedLevel;
  const IdentityDisk({super.key, required this.selectedLevel});
  @override
  State<IdentityDisk> createState() => _IdentityDiskState();
}

class _IdentityDiskState extends State<IdentityDisk>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _spinController;

  bool _isAuthenticating = false;
  String? _selectedProvider;
  bool _isNewUser = false;
  bool _rememberMe = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  final List<Map<String, dynamic>> _authProviders = [
    {'name': 'Email', 'icon': Icons.email, 'color': Colors.blue},
    {'name': 'Phone', 'icon': Icons.phone, 'color': Colors.green},
    {'name': 'Google', 'icon': Icons.g_mobiledata, 'color': Colors.red},
    {'name': 'Apple', 'icon': Icons.apple, 'color': Colors.cyan},
    {'name': 'GitHub', 'icon': Icons.code, 'color': Colors.purple},
    {'name': 'Microsoft', 'icon': Icons.window, 'color': Colors.orange},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
    _spinController =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat();

    _checkSavedCredentials();
  }

  Future<void> _checkSavedCredentials() async {
    final rememberMe = await PinStorage.getRememberMe();
    if (rememberMe) {
      final savedEmail = await PinStorage.getSavedEmail();
      final savedProvider = await PinStorage.getSavedProvider();

      if (savedEmail != null && savedProvider == 'Email') {
        setState(() {
          _emailController.text = savedEmail;
          _selectedProvider = 'Email';
          _rememberMe = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _spinController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _authenticate() async {
    if (_selectedProvider == null || _isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    try {
      switch (_selectedProvider) {
        case 'Email':
          await _signInWithEmail();
          break;
        case 'Phone':
          await _signInWithPhone();
          break;
        case 'Google':
          await _signInWithGoogle();
          break;
        case 'Apple':
          await _signInWithApple();
          break;
        case 'GitHub':
          await _signInWithGitHub();
          break;
        case 'Microsoft':
          await _signInWithMicrosoft();
          break;
      }
    } catch (e) {
      _showError('> ERROR: ${e.toString()}');
      setState(() => _isAuthenticating = false);
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      _showError('Enter email and password');
      setState(() => _isAuthenticating = false);
      return;
    }

    print("📧 Attempting login with email: $email");

    try {
      if (!FirebaseService.isAvailable) {
        print("🔐 DEMO MODE: Email auth simulated");
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          _goToHub('$email [DEMO]');
        }
        return;
      }

      UserCredential cred;
      if (_isNewUser) {
        print("📝 Creating new user...");
        cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: pass,
        );
        if (name.isNotEmpty) {
          await cred.user?.updateDisplayName(name);
        }
        print("✅ User created successfully");
      } else {
        print("🔑 Logging in existing user...");
        cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: pass,
        );
        print("✅ Login successful");
      }

      if (_rememberMe) {
        await PinStorage.setRememberMe(true, email: email, provider: 'Email');
      }

      if (mounted) {
        _goToHub(cred.user?.displayName ?? cred.user?.email ?? 'User');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'Invalid email format';
          break;
        case 'user-not-found':
          errorMessage = 'No user found with this email. Please register.';
          break;
        case 'wrong-password':
          errorMessage = 'Wrong password';
          break;
        case 'email-already-in-use':
          errorMessage = 'Email already registered. Please login.';
          break;
        case 'weak-password':
          errorMessage = 'Password too weak. Use at least 6 characters';
          break;
        default:
          errorMessage = 'Authentication failed: ${e.code}';
      }
      _showError(errorMessage);
      setState(() => _isAuthenticating = false);
    } catch (e) {
      _showError('Authentication failed: ${e.toString()}');
      setState(() => _isAuthenticating = false);
    }
  }

  Future<void> _signInWithPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showError('Enter phone number with country code (e.g., +1234567890)');
      setState(() => _isAuthenticating = false);
      return;
    }

    print("📱 Attempting phone auth: $phone");

    if (!FirebaseService.isAvailable) {
      print("🔐 DEMO MODE: Phone auth simulated");
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        _goToHub('$phone [DEMO]');
      }
      return;
    }

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          print("✅ Auto-verification completed");
          final userCredential =
              await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) {
            _goToHub(userCredential.user?.phoneNumber ?? 'Phone User');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          print("❌ Phone auth failed: ${e.code}");
          setState(() => _isAuthenticating = false);
          _showError('Phone verification failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) async {
          print("📨 Code sent, waiting for OTP");
          setState(() => _isAuthenticating = false);

          final otp = await _showOtpDialog();
          if (otp == null || otp.length != 6) return;

          setState(() => _isAuthenticating = true);
          try {
            final credential = PhoneAuthProvider.credential(
              verificationId: verificationId,
              smsCode: otp,
            );
            final userCredential =
                await FirebaseAuth.instance.signInWithCredential(credential);
            print("✅ Phone login successful");
            if (mounted) {
              _goToHub(userCredential.user?.phoneNumber ?? 'Phone User');
            }
          } catch (e) {
            _showError('Invalid OTP code');
            setState(() => _isAuthenticating = false);
          }
        },
        codeAutoRetrievalTimeout: (_) {
          setState(() => _isAuthenticating = false);
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      print("❌ Phone auth error: $e");
      setState(() => _isAuthenticating = false);
      _showError('Phone auth error');
    }
  }

  Future<void> _signInWithGoogle() async {
    print("🌐 Attempting Google sign-in...");

    if (!FirebaseService.isAvailable) {
      print("🔐 DEMO MODE: Google auth simulated");
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        _goToHub('Google User [DEMO]');
      }
      return;
    }

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        print("❌ User cancelled Google sign-in");
        setState(() => _isAuthenticating = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      print("✅ Google login successful");

      if (mounted) {
        _goToHub(userCredential.user?.displayName ?? 'Google User');
      }
    } catch (e) {
      print("❌ Google sign-in error: $e");
      _showError('Google sign-in failed');
      setState(() => _isAuthenticating = false);
    }
  }

  Future<void> _signInWithApple() async {
    print("🍎 Attempting Apple sign-in...");

    if (!FirebaseService.isAvailable) {
      print("🔐 DEMO MODE: Apple auth simulated");
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        _goToHub('Apple User [DEMO]');
      }
      return;
    }

    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oAuthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(oAuthCredential);
      print("✅ Apple login successful");

      if (mounted) {
        _goToHub(userCredential.user?.displayName ?? 'Apple User');
      }
    } catch (e) {
      print("❌ Apple sign-in error: $e");
      _showError('Apple sign-in failed');
      setState(() => _isAuthenticating = false);
    }
  }

  Future<void> _signInWithGitHub() async {
    print("🐙 Attempting GitHub sign-in...");

    if (!FirebaseService.isAvailable) {
      print("🔐 DEMO MODE: GitHub auth simulated");
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        _goToHub('GitHub User [DEMO]');
      }
      return;
    }

    try {
      final githubProvider = GithubAuthProvider();
      final userCredential =
          await FirebaseAuth.instance.signInWithProvider(githubProvider);
      print("✅ GitHub login successful");

      if (mounted) {
        _goToHub(userCredential.user?.displayName ?? 'GitHub User');
      }
    } catch (e) {
      print("❌ GitHub sign-in error: $e");
      _showError('GitHub sign-in failed');
      setState(() => _isAuthenticating = false);
    }
  }

  Future<void> _signInWithMicrosoft() async {
    print("💼 Attempting Microsoft sign-in...");

    if (!FirebaseService.isAvailable) {
      print("🔐 DEMO MODE: Microsoft auth simulated");
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        _goToHub('Microsoft User [DEMO]');
      }
      return;
    }

    try {
      final microsoftProvider = MicrosoftAuthProvider();
      final userCredential =
          await FirebaseAuth.instance.signInWithProvider(microsoftProvider);
      print("✅ Microsoft login successful");

      if (mounted) {
        _goToHub(userCredential.user?.displayName ?? 'Microsoft User');
      }
    } catch (e) {
      print("❌ Microsoft sign-in error: $e");
      _showError('Microsoft sign-in failed');
      setState(() => _isAuthenticating = false);
    }
  }

  Future<String?> _showOtpDialog() async {
    final level = levels.firstWhere((l) => l.level == widget.selectedLevel);
    String? enteredOtp;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1117),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('ENTER OTP CODE',
            style: TextStyle(
                color: level.color,
                letterSpacing: 2,
                fontSize: 14,
                fontFamily: 'monospace')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SMS sent to ${_phoneController.text}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Pinput(
              length: 6,
              defaultPinTheme: PinTheme(
                width: 46,
                height: 52,
                textStyle: TextStyle(
                    color: level.color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
                decoration: BoxDecoration(
                  border: Border.all(color: level.color.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(10),
                  color: level.color.withOpacity(0.05),
                ),
              ),
              focusedPinTheme: PinTheme(
                width: 46,
                height: 52,
                textStyle: TextStyle(
                    color: level.color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
                decoration: BoxDecoration(
                  border: Border.all(color: level.color, width: 2),
                  borderRadius: BorderRadius.circular(10),
                  color: level.color.withOpacity(0.1),
                ),
              ),
              onCompleted: (pin) => enteredOtp = pin,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: level.color, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('VERIFY'),
          ),
        ],
      ),
    );
    return enteredOtp;
  }

  void _goToHub(String displayName) {
    PinStorage.setLocked(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AuraMainHub(
          selectedLevel: widget.selectedLevel,
          loginMethod: displayName,
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(
                color: Colors.white, fontFamily: 'monospace', fontSize: 12)),
        backgroundColor: const Color(0xFF1A0505),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = levels.firstWhere((l) => l.level == widget.selectedLevel);
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF050A0E),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: Listenable.merge(
                              [_pulseController, _spinController]),
                          builder: (_, __) {
                            return Transform.rotate(
                              angle: _spinController.value * 2 * math.pi,
                              child: Container(
                                width: isSmallScreen ? 120 : 150,
                                height: isSmallScreen ? 120 : 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      level.color,
                                      level.color.withBlue(100),
                                      Colors.black
                                    ],
                                    stops: const [0.0, 0.45, 1.0],
                                  ),
                                  border: Border.all(
                                      color: level.color.withOpacity(0.65),
                                      width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: level.color.withOpacity(
                                          0.3 + 0.2 * _pulseController.value),
                                      blurRadius: 40,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    level.name[0],
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSmallScreen ? 48 : 60,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                            color: level.color.withOpacity(0.8),
                                            blurRadius: 20),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: isSmallScreen ? 16 : 20),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 16 : 20,
                              vertical: isSmallScreen ? 8 : 10),
                          decoration: BoxDecoration(
                            color: level.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                            border:
                                Border.all(color: level.color.withOpacity(0.3)),
                          ),
                          child: Text(level.name,
                              style: TextStyle(
                                  color: level.color,
                                  fontSize: isSmallScreen ? 12 : 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2)),
                        ),
                        SizedBox(height: isSmallScreen ? 20 : 30),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Column(
                            children: [
                              const Text("AUTHENTICATE",
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      letterSpacing: 2)),
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: isSmallScreen ? 8 : 10,
                                runSpacing: isSmallScreen ? 8 : 10,
                                children: _authProviders.map((provider) {
                                  final bool isSelected =
                                      _selectedProvider == provider['name'];
                                  return GestureDetector(
                                    onTap: () => setState(() =>
                                        _selectedProvider = provider['name']),
                                    child: Container(
                                      width: isSmallScreen ? 45 : 50,
                                      height: isSmallScreen ? 45 : 50,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? (provider['color'] as Color)
                                                .withOpacity(0.3)
                                            : Colors.white.withOpacity(0.05),
                                        border: Border.all(
                                          color: isSelected
                                              ? provider['color']
                                              : Colors.white24,
                                          width: isSelected ? 2 : 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                    color: (provider['color']
                                                            as Color)
                                                        .withOpacity(0.5),
                                                    blurRadius: 15,
                                                    spreadRadius: 2)
                                              ]
                                            : null,
                                      ),
                                      child: Icon(provider['icon'],
                                          color: isSelected
                                              ? provider['color']
                                              : Colors.white54,
                                          size: isSmallScreen ? 20 : 24),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),
                              if (_selectedProvider == 'Email') ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _tabButton(
                                        'LOGIN',
                                        !_isNewUser,
                                        () =>
                                            setState(() => _isNewUser = false),
                                        level.color),
                                    const SizedBox(width: 8),
                                    _tabButton(
                                        'REGISTER',
                                        _isNewUser,
                                        () => setState(() => _isNewUser = true),
                                        level.color),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_isNewUser)
                                  _inputField(
                                      controller: _nameController,
                                      hint: "Display Name (optional)"),
                                if (_isNewUser) const SizedBox(height: 10),
                                _inputField(
                                    controller: _emailController,
                                    hint: "Email",
                                    keyboardType: TextInputType.emailAddress),
                                const SizedBox(height: 10),
                                _inputField(
                                    controller: _passwordController,
                                    hint: "Password",
                                    obscure: true),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberMe,
                                      onChanged: (value) {
                                        setState(() {
                                          _rememberMe = value ?? false;
                                        });
                                      },
                                      activeColor: level.color,
                                      checkColor: Colors.black,
                                    ),
                                    const Text("Remember me",
                                        style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12)),
                                  ],
                                ),
                              ] else if (_selectedProvider == 'Phone') ...[
                                _inputField(
                                    controller: _phoneController,
                                    hint: "+1234567890",
                                    keyboardType: TextInputType.phone),
                                const SizedBox(height: 8),
                                const Text("SMS with 6-digit code will be sent",
                                    style: TextStyle(
                                        color: Colors.white38, fontSize: 10),
                                    textAlign: TextAlign.center),
                              ] else if (_selectedProvider != null) ...[
                                Container(
                                  padding:
                                      EdgeInsets.all(isSmallScreen ? 12 : 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _authProviders.firstWhere((p) =>
                                            p['name'] ==
                                            _selectedProvider)['icon'],
                                        color: Colors.white70,
                                        size: isSmallScreen ? 18 : 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                          "Tap button to open $_selectedProvider",
                                          style: TextStyle(
                                              color: Colors.white70,
                                              fontSize:
                                                  isSmallScreen ? 12 : 13)),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              GestureDetector(
                                onTap: _selectedProvider != null &&
                                        !_isAuthenticating
                                    ? _authenticate
                                    : null,
                                child: AnimatedOpacity(
                                  opacity:
                                      _selectedProvider != null ? 1.0 : 0.4,
                                  duration: const Duration(milliseconds: 300),
                                  child: Container(
                                    width: double.infinity,
                                    height: isSmallScreen ? 44 : 48,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [
                                        level.color,
                                        level.color.withBlue(150),
                                      ]),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                            color: level.color.withOpacity(0.5),
                                            blurRadius: 20,
                                            spreadRadius: 2),
                                      ],
                                    ),
                                    child: Center(
                                      child: _isAuthenticating
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                        Colors.white),
                                              ))
                                          : Text(
                                              _selectedProvider == 'Email'
                                                  ? (_isNewUser
                                                      ? "CREATE ACCOUNT"
                                                      : "SIGN IN")
                                                  : _selectedProvider == 'Phone'
                                                      ? "SEND CODE"
                                                      : "AUTHENTICATE",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize:
                                                    isSmallScreen ? 13 : 14,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _tabButton(
      String label, bool active, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? color : Colors.white24, width: active ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? color : Colors.white38,
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                letterSpacing: 1)),
      ),
    );
  }

  Widget _buildBackground() {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        Positioned(
            left: -50,
            top: 50,
            child: _bgBox(
                width: size.width * 0.25,
                height: size.height * 0.3,
                color: const Color(0xFF0D1117))),
        Positioned(
            right: -50,
            bottom: 50,
            child: _bgBox(
                width: size.width * 0.3,
                height: size.height * 0.35,
                color: const Color(0xFF1E1E2E))),
      ],
    );
  }

  Widget _bgBox(
      {required double width, required double height, required Color color}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12, width: 1),
          ),
        ),
      ),
    );
  }
}

// ─── VIBE THEMES ─────────────────────────────────────────────────────
class VibeTheme {
  final String name;
  final Color primary;
  final Color secondary;
  final Color bg;
  final bool isLight;
  const VibeTheme({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.bg,
    this.isLight = false,
  });
}

final List<VibeTheme> vibeThemes = [
  const VibeTheme(
      name: "Dark\nObsidian",
      primary: Color(0xFF888888),
      secondary: Color(0xFF222222),
      bg: Color(0xFF050A0E)),
  const VibeTheme(
      name: "White\nPorcelain",
      primary: Color(0xFF1A56DB),
      secondary: Color(0xFF3B82F6),
      bg: Color(0xFFF0F4FB),
      isLight: true),
  const VibeTheme(
      name: "Matrix\nGreen",
      primary: Color(0xFF39FF14),
      secondary: Color(0xFF004010),
      bg: Color(0xFF000800)),
  const VibeTheme(
      name: "Luxury\nGold",
      primary: Color(0xFFD4AF37),
      secondary: Color(0xFF7A5C00),
      bg: Color(0xFF080600)),
];

// ─── QUIZ DIALOG WIDGET ────────────────────────────────────────────
class QuizDialog extends StatefulWidget {
  final String topic;
  final String assessmentType;
  final List<Map<String, dynamic>> questions;
  final Function(double score, bool passed, Badge badge) onComplete;

  const QuizDialog({
    super.key,
    required this.topic,
    required this.assessmentType,
    required this.questions,
    required this.onComplete,
  });

  @override
  State<QuizDialog> createState() => _QuizDialogState();
}

class _QuizDialogState extends State<QuizDialog> {
  int _currentQuestion = 0;
  List<int> _answers = [];
  bool _quizCompleted = false;
  double _finalScore = 0;

  @override
  void initState() {
    super.initState();
    _answers = List.filled(widget.questions.length, -1);
  }

  @override
  Widget build(BuildContext context) {
    if (_quizCompleted) {
      bool passed = QuizService.isPassed(_finalScore, widget.assessmentType);
      Badge badge = getBadgeFromScore(_finalScore);

      return AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "${widget.assessmentType.toUpperCase()} COMPLETE",
          style: TextStyle(
            color: passed ? Colors.green : Colors.red,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Your Score: ${_finalScore.toStringAsFixed(1)}%",
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: badge.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: badge.color),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    badge.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    badge.name,
                    style: TextStyle(
                      color: badge.color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              passed
                  ? "✅ PASSED! You can proceed."
                  : "❌ NOT PASSED. Try again!",
              style: TextStyle(
                color: passed ? Colors.green : Colors.red,
                fontSize: 12,
              ),
            ),
            if (widget.assessmentType == 'formative' && passed)
              const Text(
                "Exam available in 3 days!",
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            if (widget.assessmentType == 'exam' && passed && _finalScore == 100)
              const Text(
                "🏆 SUPER GOLD! You're #1 in the world!",
                style: TextStyle(color: Color(0xFFFFD700), fontSize: 12),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onComplete(_finalScore, passed, badge);
            },
            child: const Text("Continue"),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        "${widget.assessmentType.toUpperCase()} - ${widget.topic}",
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Question ${_currentQuestion + 1}/${widget.questions.length}",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Text(
              widget.questions[_currentQuestion]['question'],
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 20),
            ...List.generate(4, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _answers[_currentQuestion] = index;
                    });

                    if (_currentQuestion < widget.questions.length - 1) {
                      setState(() {
                        _currentQuestion++;
                      });
                    } else {
                      _finalScore = QuizService.calculateScore(
                          _answers, widget.questions);
                      setState(() {
                        _quizCompleted = true;
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _answers[_currentQuestion] == index
                          ? Colors.blue.withOpacity(0.3)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _answers[_currentQuestion] == index
                            ? Colors.blue
                            : Colors.white24,
                      ),
                    ),
                    child: Text(
                      widget.questions[_currentQuestion]['options'][index],
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── CERTIFICATE WIDGET ─────────────────────────────────────────────
class CertificateWidget extends StatelessWidget {
  final String courseName;
  final String userName;
  final Badge badge;
  final DateTime date;

  const CertificateWidget({
    super.key,
    required this.courseName,
    required this.userName,
    required this.badge,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            badge.color.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
            badge.color.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: badge.color, width: 3),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: badge.color.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "🎓 CERTIFICATE OF ACHIEVEMENT",
            style: TextStyle(
              color: badge.color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "This is to certify that",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(
            userName,
            style: TextStyle(
              color: badge.color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "has successfully completed",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(
            courseName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                badge.icon,
                style: const TextStyle(fontSize: 30),
              ),
              const SizedBox(width: 10),
              Text(
                badge.name,
                style: TextStyle(
                  color: badge.color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "Date: ${date.day}/${date.month}/${date.year}",
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
          if (badge.level == BadgeLevel.superGold) ...[
            const SizedBox(height: 10),
            const Text(
              "🏆 WORLD RANK #1 🏆",
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── MAIN HUB with ALL FEATURES ─────────────────────────────────────
class AuraMainHub extends StatefulWidget {
  final SkillLevel selectedLevel;
  final String loginMethod;
  const AuraMainHub({
    super.key,
    required this.selectedLevel,
    required this.loginMethod,
  });
  @override
  State<AuraMainHub> createState() => _AuraMainHubState();
}

class _AuraMainHubState extends State<AuraMainHub>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _ringSpinController;
  late AnimationController _revealController;
  late AnimationController _orbitController;
  late AnimationController _searchSpinController;

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _noteTitleController = TextEditingController();
  final TextEditingController _noteContentController = TextEditingController();

  bool _isSearching = false;
  bool _isCompact = false;
  String _currentAnswer = "";
  int _selectedTheme = 3;
  int? _openPanel;
  String? _selectedCourse;
  final List<String> _chatHistory = [];

  bool _ollamaAvailable = false;
  bool _ollamaChecked = false;

  late final LevelInfo _userLevel;
  late Course _currentCourse;
  String _selectedVoice = "female";

  String _selectedLanguage = "English";
  final List<String> _languages = [
    "English",
    "French",
    "Spanish",
    "German",
    "Chinese"
  ];

  // Notes and Bookmarks
  Map<String, dynamic> _notes = {};
  List<String> _bookmarks = [];

  VibeTheme get _currentVibe => vibeThemes[_selectedTheme];
  Color get _accent => _currentVibe.primary;
  Color get _themeBg => _currentVibe.bg;
  bool get _isLight => _currentVibe.isLight;

  Color get _textPrimary => _isLight ? const Color(0xFF0D1B2A) : Colors.white;
  Color get _textSub => _isLight ? const Color(0xFF334155) : Colors.white54;
  Color get _textFaint => _isLight ? const Color(0xFF64748B) : Colors.white38;
  Color get _panelBorder => _isLight
      ? const Color(0xFF1A56DB).withOpacity(0.4)
      : _accent.withOpacity(0.35);
  Color get _codeBg =>
      _isLight ? const Color(0xFFE8F0FE) : Colors.white.withOpacity(0.04);
  Color get _codeTextColor =>
      _isLight ? const Color(0xFF0D2A5E) : Colors.white70;
  Color get _inputBg =>
      _isLight ? Colors.white : Colors.white.withOpacity(0.06);
  Color get _inputBorder =>
      _isLight ? _accent.withOpacity(0.55) : Colors.white.withOpacity(0.18);
  Color get _rowBg =>
      _isLight ? const Color(0xFFDBEAFE) : Colors.white.withOpacity(0.07);

  @override
  void initState() {
    super.initState();
    _userLevel = levels.firstWhere((l) => l.level == widget.selectedLevel);
    _currentCourse = createSampleCourse(widget.selectedLevel);

    _loadSavedCourse();
    VoiceService.init();

    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _ringSpinController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();
    _revealController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _orbitController =
        AnimationController(vsync: this, duration: const Duration(seconds: 30))
          ..repeat();
    _searchSpinController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    setState(() {
      _currentAnswer =
          "> Welcome, ${widget.loginMethod}!\n> Level: ${_userLevel.name}\n> Checking Ollama...";
    });

    _checkOllama();
    _loadNotes();
    _loadBookmarks();
    _loadVoicePreference();
  }

  Future<void> _loadSavedCourse() async {
    Course? saved = await PinStorage.loadCourse(_currentCourse.id);
    if (saved != null) {
      setState(() {
        _currentCourse = saved;
      });
    }
  }

  Future<void> _loadVoicePreference() async {
    _selectedVoice = await PinStorage.getVoicePreference();
    await VoiceService.setVoice(_selectedVoice);
  }

  Future<void> _loadNotes() async {
    final notes = await PinStorage.getNotes();
    setState(() {
      _notes = notes;
    });
  }

  Future<void> _loadBookmarks() async {
    final bookmarks = await PinStorage.getBookmarks();
    setState(() {
      _bookmarks = bookmarks;
    });
  }

  Future<void> _checkOllama() async {
    final available = await OllamaService.isAvailable();
    if (mounted) {
      setState(() {
        _ollamaAvailable = available;
        _ollamaChecked = true;
        _currentAnswer = available
            ? "> Welcome, ${widget.loginMethod}!\n> Level: ${_userLevel.name}\n> ✅ Ollama connected!\n> Ask me anything!"
            : "> Welcome, ${widget.loginMethod}!\n> Level: ${_userLevel.name}\n> ⚠️ Ollama not detected.\n> To enable AI:\n>   1. Run: ollama serve\n>   2. Pull: ollama pull llama3";
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringSpinController.dispose();
    _revealController.dispose();
    _orbitController.dispose();
    _searchSpinController.dispose();
    _textController.dispose();
    _noteTitleController.dispose();
    _noteContentController.dispose();
    super.dispose();
  }

  // ─── VOICE ASSISTANT FEATURE ────────────────────────────────────
  Future<void> _handleVoiceAssistant() async {
    setState(() {
      _isSearching = true;
      _currentAnswer =
          "> AURA: Hello! I'm your learning assistant. How can I help you today?";
    });

    await VoiceService.speak(
        "Hello! I'm AURA, your learning assistant. How can I help you?");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text("Choose Voice", style: TextStyle(color: _accent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.female, color: Colors.pink),
              title: const Text("Female Voice",
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text("Warm and friendly",
                  style: TextStyle(color: Colors.white54)),
              onTap: () async {
                Navigator.pop(context);
                _selectedVoice = "female";
                await PinStorage.setVoicePreference("female");
                await VoiceService.setVoice("female");
                await VoiceService.speak(
                    "How can I assist you with your learning today?");

                String? voiceInput = await VoiceService.listen();
                if (voiceInput != null) {
                  setState(() {
                    _textController.text = voiceInput;
                  });
                  _runSearch();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.male, color: Colors.blue),
              title: const Text("Male Voice",
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text("Deep and confident",
                  style: TextStyle(color: Colors.white54)),
              onTap: () async {
                Navigator.pop(context);
                _selectedVoice = "male";
                await PinStorage.setVoicePreference("male");
                await VoiceService.setVoice("male");
                await VoiceService.speak("Ready to learn? I'm here to help!");

                String? voiceInput = await VoiceService.listen();
                if (voiceInput != null) {
                  setState(() {
                    _textController.text = voiceInput;
                  });
                  _runSearch();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── COURSE LEARNING METHODS ─────────────────────────────────────
  void _startQuiz(Topic topic, Unit unit) {
    var questions = QuizService.generateQuiz(topic.title);

    showDialog(
      context: context,
      builder: (_) => QuizDialog(
        topic: topic.title,
        assessmentType: "quiz",
        questions: questions,
        onComplete: (score, passed, badge) async {
          setState(() {
            topic.quizScore = score;
            topic.quizPassed = passed;
            if (passed) {
              topic.completed = true;
            }
          });

          await PinStorage.saveCourseProgress(_currentCourse);
          await PinStorage.updateStreak();

          if (passed) {
            VoiceService.speak(
                "Congratulations! You passed with ${score.toStringAsFixed(0)}% and earned a ${badge.name} badge!");
          } else {
            VoiceService.speak(
                "You scored ${score.toStringAsFixed(0)}%. Keep practicing and try again!");
          }
        },
      ),
    );
  }

  void _startFormative(Unit unit) {
    var questions = QuizService.generateQuiz("${unit.title} Formative");

    showDialog(
      context: context,
      builder: (_) => QuizDialog(
        topic: unit.title,
        assessmentType: "formative",
        questions: questions,
        onComplete: (score, passed, badge) async {
          setState(() {
            unit.formativeScore = score;
            unit.formativePassed = passed;
            if (passed) {
              unit.formativeCompleted = true;
              unit.examAvailableDate =
                  DateTime.now().add(const Duration(days: 3));
            }
          });

          await PinStorage.saveCourseProgress(_currentCourse);

          if (passed) {
            VoiceService.speak(
                "Excellent! You passed the formative assessment. Your exam will be available in 3 days.");
          }
        },
      ),
    );
  }

  void _startExam(Unit unit) {
    var questions = QuizService.generateQuiz("${unit.title} Exam");

    showDialog(
      context: context,
      builder: (_) => QuizDialog(
        topic: unit.title,
        assessmentType: "exam",
        questions: questions,
        onComplete: (score, passed, badge) async {
          setState(() {
            unit.examScore = score;
            unit.examPassed = passed;
            if (passed) {
              unit.examCompleted = true;
            }
          });

          bool allUnitsPassed = _currentCourse.units.every((u) => u.examPassed);
          if (allUnitsPassed && !_currentCourse.certificateEarned) {
            double totalScore = _currentCourse.units
                    .map((u) => u.examScore)
                    .reduce((a, b) => a + b) /
                _currentCourse.units.length;
            Badge finalBadge = getBadgeFromScore(totalScore);

            setState(() {
              _currentCourse.certificateEarned = true;
              _currentCourse.finalBadge = finalBadge.level;
              _currentCourse.finalScore = totalScore;
            });

            if (totalScore == 100) {
              await PinStorage.updateWorldRank(_currentCourse.id, totalScore);
              int rank = await PinStorage.getWorldRank(_currentCourse.id);
              setState(() {
                _currentCourse.worldRank = rank;
              });
              VoiceService.speak(
                  "INCREDIBLE! You scored 100% and achieved SUPER GOLD! You're now ranked #1 in the world!");
            } else {
              VoiceService.speak(
                  "Congratulations! You've completed the course with a ${finalBadge.name} badge!");
            }
          }

          await PinStorage.saveCourseProgress(_currentCourse);
        },
      ),
    );
  }

  void _showExamWaitDialog(Unit unit) {
    if (unit.examAvailableDate == null) return;

    int daysLeft = unit.examAvailableDate!.difference(DateTime.now()).inDays;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text("Exam Locked", style: TextStyle(color: _userLevel.color)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock, color: Colors.orange, size: 40),
            const SizedBox(height: 10),
            Text(
              "Exam will be available in",
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              "$daysLeft days",
              style: TextStyle(
                color: _userLevel.color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Use this time to review and practice!",
              style: TextStyle(color: Colors.white54, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showCertificate() {
    User? firebaseUser;
    String userName = widget.loginMethod;

    try {
      firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        userName = firebaseUser.displayName ??
            firebaseUser.email ??
            widget.loginMethod;
      }
    } catch (e) {}

    Badge finalBadge = badges.firstWhere(
      (b) => b.level == _currentCourse.finalBadge,
      orElse: () => badges[0],
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: CertificateWidget(
          courseName: _currentCourse.title,
          userName: userName,
          badge: finalBadge,
          date: DateTime.now(),
        ),
      ),
    );
  }

  Widget _buildLearningPanel() {
    return _glassPanel(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _currentCourse.title,
                style: TextStyle(
                  color: _userLevel.color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.school, color: _userLevel.color, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          ..._currentCourse.units.asMap().entries.map((unitEntry) {
            int unitIndex = unitEntry.key;
            Unit unit = unitEntry.value;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: unit.formativePassed
                            ? Colors.green
                            : _userLevel.color.withOpacity(0.3),
                      ),
                      child: Center(
                        child: unit.formativePassed
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 12)
                            : Text("${unitIndex + 1}",
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        unit.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...unit.topics.asMap().entries.map((topicEntry) {
                  int topicIndex = topicEntry.key;
                  Topic topic = topicEntry.value;

                  return Padding(
                    padding: const EdgeInsets.only(left: 28, bottom: 6),
                    child: GestureDetector(
                      onTap: () {
                        if (!topic.completed) {
                          _startQuiz(topic, unit);
                        }
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: topic.quizPassed
                                  ? Colors.green
                                  : Colors.white.withOpacity(0.1),
                              border: Border.all(
                                color: topic.quizPassed
                                    ? Colors.green
                                    : Colors.white24,
                              ),
                            ),
                            child: topic.quizPassed
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 10)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              topic.title,
                              style: TextStyle(
                                color: topic.quizPassed
                                    ? Colors.green
                                    : Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          if (topic.quizPassed)
                            Text(
                              "${topic.quizScore.toStringAsFixed(0)}%",
                              style: const TextStyle(
                                  color: Colors.green, fontSize: 8),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                if (unit.topics.every((t) => t.quizPassed)) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: GestureDetector(
                      onTap: () {
                        if (!unit.formativeCompleted && !unit.formativePassed) {
                          _startFormative(unit);
                        } else if (unit.formativePassed &&
                            !unit.examCompleted) {
                          if (unit.examAvailableDate != null &&
                              DateTime.now().isAfter(unit.examAvailableDate!)) {
                            _startExam(unit);
                          } else {
                            _showExamWaitDialog(unit);
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _userLevel.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _userLevel.color),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              unit.formativePassed
                                  ? Icons.assignment_turned_in
                                  : Icons.assignment,
                              color: _userLevel.color,
                              size: 14,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                unit.formativePassed
                                    ? "Formative Passed (${unit.formativeScore.toStringAsFixed(0)}%)"
                                    : "Take Formative Assessment",
                                style: TextStyle(
                                  color: _userLevel.color,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            if (unit.formativePassed && !unit.examCompleted)
                              Text(
                                unit.examAvailableDate == null
                                    ? "Exam in 3 days"
                                    : "Exam Ready!",
                                style: TextStyle(
                                  color: unit.examAvailableDate == null
                                      ? Colors.orange
                                      : Colors.green,
                                  fontSize: 8,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            );
          }),
          if (_currentCourse.certificateEarned) ...[
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showCertificate,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _userLevel.color.withOpacity(0.3),
                      _userLevel.color.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _userLevel.color),
                ),
                child: Row(
                  children: [
                    Icon(Icons.card_membership, color: _userLevel.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Certificate Earned!",
                            style: TextStyle(
                              color: _userLevel.color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Tap to view",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward,
                        color: _userLevel.color, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _selectCourse(String course) {
    setState(() {
      _selectedCourse = course;
      _currentAnswer =
          "> Course selected: $course\n> Ask me anything about this course!";
    });
    PinStorage.completeCourse(course);
    _revealController.reverse();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _revealController.forward();
    });
  }

  void _runSearch() async {
    final query = _textController.text.trim();
    if (query.isEmpty || _isSearching) return;

    _chatHistory.add("> You: $query");

    setState(() {
      _isSearching = true;
      _currentAnswer = "";
      _openPanel = null;
    });

    _revealController.reverse();
    _textController.clear();
    _orbitController.stop();
    _searchSpinController.repeat();

    if (!_ollamaAvailable) {
      final available = await OllamaService.isAvailable();
      setState(() => _ollamaAvailable = available);
    }

    await Future.delayed(const Duration(milliseconds: 300));
    _searchSpinController.stop();
    _searchSpinController.reset();
    _orbitController.repeat();
    setState(() => _isSearching = false);
    _revealController.forward();

    if (!_ollamaAvailable) {
      setState(() {
        _currentAnswer =
            "> ⚠️ Ollama is not running.\n> Start with: ollama serve\n> Then: ollama pull llama3\n>\n> Your question: \"$query\"";
      });
      return;
    }

    final systemPrompt =
        OllamaService.buildSystemPrompt(_userLevel.name, _selectedCourse);
    setState(() => _currentAnswer = "> Thinking...");

    try {
      await OllamaService.generate(
        prompt: query,
        systemPrompt: systemPrompt,
        onChunk: (chunk) {
          if (mounted) setState(() => _currentAnswer = chunk);
        },
      );
      _chatHistory.add(_currentAnswer);
      await PinStorage.updateStreak();
      VoiceService.speak("Here's what I found about $query");
    } catch (e) {
      setState(() {
        _currentAnswer = e.toString();
        _ollamaAvailable = false;
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Copied to clipboard!"),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _saveAsNote() {
    _noteTitleController.text =
        "Note ${DateTime.now().toString().substring(0, 16)}";
    _noteContentController.text = _currentAnswer;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text("Save as Note", style: TextStyle(color: _accent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _noteTitleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Title",
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _accent.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _accent),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteContentController,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Content",
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _accent.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _accent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await PinStorage.saveNote(
                _noteTitleController.text,
                _noteContentController.text,
              );
              Navigator.pop(context);
              _loadNotes();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Note saved!")),
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _addBookmark() {
    PinStorage.addBookmark(_currentAnswer);
    _loadBookmarks();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Bookmark added!")),
    );
  }

  void _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
    } catch (_) {}
    await PinStorage.setLocked(true);
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BootSequence()),
        (_) => false,
      );
    }
  }

  void _changePin() {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text("Change PIN", style: TextStyle(color: _accent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPinController,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Current PIN",
                hintStyle: const TextStyle(color: Colors.white38),
              ),
            ),
            TextField(
              controller: newPinController,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "New PIN",
                hintStyle: const TextStyle(color: Colors.white38),
              ),
            ),
            TextField(
              controller: confirmPinController,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Confirm PIN",
                hintStyle: const TextStyle(color: Colors.white38),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPinController.text != confirmPinController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("New PINs don't match")),
                );
                return;
              }

              final success = await PinStorage.changePin(
                  oldPinController.text, newPinController.text);

              if (success) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("PIN changed successfully")),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Current PIN is incorrect")),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final isLargeScreen = size.width >= 900;

    double orbSize = _isCompact ? 120 : (isSmallScreen ? 250 : 300);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      color: _themeBg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (details.delta.dx > 10) setState(() => _isCompact = true);
                if (details.delta.dx < -10) setState(() => _isCompact = false);
              },
              onTap: () {
                if (_openPanel != null) setState(() => _openPanel = null);
              },
              behavior: HitTestBehavior.translucent,
              child: Stack(
                children: [
                  if (!_isCompact) Positioned.fill(child: _buildBackground()),
                  if (!_isCompact)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GridPainter(_accent, _isLight),
                      ),
                    ),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: size.width * 0.03, vertical: 14),
                      child: isSmallScreen && !_isCompact
                          ? _buildMobileLayout(orbSize)
                          : _buildDesktopLayout(orbSize),
                    ),
                  ),
                  if (!_isCompact && _openPanel != null) ...[
                    if (_openPanel == 0)
                      Positioned(
                          left: 0,
                          top: constraints.maxHeight * 0.3,
                          child: _buildVibeThemesPanel()),
                    if (_openPanel == 1)
                      Positioned(
                          right: 0,
                          top: constraints.maxHeight * 0.1,
                          child: _buildProfilePanel()),
                    if (_openPanel == 2)
                      Positioned(
                          right: 0,
                          top: constraints.maxHeight * 0.5,
                          child: _buildCoursesPanel()),
                    if (_openPanel == 3)
                      Positioned(
                          right: 0,
                          top: constraints.maxHeight * 0.2,
                          child: _buildNotesPanel()),
                    if (_openPanel == 4)
                      Positioned(
                          left: 0,
                          top: constraints.maxHeight * 0.3,
                          child: _buildLearningPanel()),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout(double orbSize) {
    return Column(
      children: [
        _buildTopSystemInfo(),
        const SizedBox(height: 20),
        Expanded(flex: 3, child: Center(child: _buildMainOrb(orbSize))),
        const SizedBox(height: 20),
        Expanded(flex: 4, child: _buildThoughtStream()),
        const SizedBox(height: 12),
        _buildInputBar(),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildDesktopLayout(double orbSize) {
    return Column(
      children: [
        _buildTopSystemInfo(),
        const Spacer(),
        Center(child: _buildMainOrb(orbSize)),
        const Spacer(),
        _buildThoughtStream(),
        const SizedBox(height: 12),
        _buildInputBar(),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildBackground() {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        Positioned(
          left: -18,
          top: 0,
          bottom: 0,
          child: Center(
              child: _bgTerminalWindow(
                  width: size.width * 0.2, height: size.height * 0.5)),
        ),
        Positioned(
          right: -18,
          top: 0,
          bottom: 0,
          child: Center(
              child: _bgVSCodeWindow(
                  width: size.width * 0.22, height: size.height * 0.55)),
        ),
      ],
    );
  }

  Widget _bgTerminalWindow({required double width, required double height}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117).withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF30363D), width: 1),
          ),
        ),
      ),
    );
  }

  Widget _bgVSCodeWindow({required double width, required double height}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E).withOpacity(0.88),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF313244), width: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSystemInfo() {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isCompact ? "AURA" : "System Pulse",
              style: TextStyle(
                color: _textPrimary,
                fontSize: _isCompact ? 16 : (isSmallScreen ? 18 : 22),
                fontWeight: FontWeight.w300,
                letterSpacing: 3,
                shadows: [
                  Shadow(color: _accent.withOpacity(0.5), blurRadius: 14)
                ],
              ),
            ),
            const Spacer(),
            Row(
              children: [
                GestureDetector(
                  onTap: _handleVoiceAssistant,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _selectedVoice == "female"
                          ? Colors.pink.withOpacity(0.2)
                          : Colors.blue.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedVoice == "female"
                            ? Colors.pink
                            : Colors.blue,
                      ),
                    ),
                    child: Icon(
                      _selectedVoice == "female" ? Icons.female : Icons.male,
                      color: _selectedVoice == "female"
                          ? Colors.pink
                          : Colors.blue,
                      size: 16,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _signOut,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.logout, color: Colors.red, size: 12),
                        SizedBox(width: 4),
                        Text("Sign Out",
                            style: TextStyle(color: Colors.red, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (!_isCompact) ...[
          SizedBox(height: isSmallScreen ? 4 : 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 16,
                    vertical: isSmallScreen ? 4 : 6),
                decoration: BoxDecoration(
                  color: _userLevel.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _userLevel.color.withOpacity(0.3)),
                ),
                child: Text(
                  "${_userLevel.name} • ${widget.loginMethod}",
                  style: TextStyle(
                    color: _userLevel.color,
                    fontSize: isSmallScreen ? 8 : 10,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              if (_ollamaChecked)
                GestureDetector(
                  onTap: _checkOllama,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 8 : 10,
                        vertical: isSmallScreen ? 4 : 6),
                    decoration: BoxDecoration(
                      color: _ollamaAvailable
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _ollamaAvailable
                              ? Colors.green.withOpacity(0.4)
                              : Colors.red.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  _ollamaAvailable ? Colors.green : Colors.red),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _ollamaAvailable ? "llama3" : "offline",
                          style: TextStyle(
                              color:
                                  _ollamaAvailable ? Colors.green : Colors.red,
                              fontSize: isSmallScreen ? 7 : 8,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMainOrb(double orbSize) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    double satelliteDistance = orbSize / 2 - (isSmallScreen ? 20 : 25);
    double satelliteSize = isSmallScreen ? 30 : 36;

    return SizedBox(
      width: orbSize,
      height: orbSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!_isCompact) ...[
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => Container(
                width: orbSize + 40 + 15 * _pulseController.value,
                height: orbSize + 40 + 15 * _pulseController.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _accent.withOpacity(0.3 * _pulseController.value),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color:
                            _accent.withOpacity(0.2 * _pulseController.value),
                        blurRadius: 30,
                        spreadRadius: 5),
                  ],
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _ringSpinController,
              builder: (_, __) => Transform.rotate(
                angle: _ringSpinController.value * 2 * math.pi,
                child: Container(
                  width: orbSize - 20,
                  height: orbSize - 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: _accent.withOpacity(0.4), width: 1.5),
                  ),
                ),
              ),
            ),
          ],
          AnimatedBuilder(
            animation:
                Listenable.merge([_pulseController, _searchSpinController]),
            builder: (_, __) {
              final s = _isCompact
                  ? 100.0
                  : (orbSize * 0.6) + 8.0 * _pulseController.value;
              final spinAngle = _searchSpinController.value * 2 * math.pi;
              final matrix = Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(spinAngle)
                ..rotateX(math.sin(spinAngle) * 0.2);

              Color sphereColor = _accent;
              Color sphereHighlight =
                  _isLight ? Colors.white : sphereColor.withOpacity(0.8);
              Color textColor = _isLight ? Colors.black : Colors.white;

              return Transform(
                alignment: Alignment.center,
                transform: matrix,
                child: GestureDetector(
                  onTap: _handleVoiceAssistant,
                  child: Container(
                    width: s,
                    height: s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.30, -0.35),
                        colors: [
                          sphereHighlight.withOpacity(0.9),
                          sphereColor,
                          _isLight ? Colors.white : Colors.black,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: sphereColor.withOpacity(0.5),
                            blurRadius: 40,
                            spreadRadius: 3),
                        BoxShadow(
                            color: Colors.black.withOpacity(0.8),
                            blurRadius: 20),
                        BoxShadow(
                            color: Colors.white.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(-5, -5)),
                      ],
                    ),
                    child: Center(
                      child: _isSearching
                          ? Icon(Icons.autorenew_rounded,
                              color: Colors.white, size: orbSize * 0.12)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _selectedVoice == "female"
                                      ? Icons.female
                                      : Icons.male,
                                  color: Colors.white,
                                  size: orbSize * 0.08,
                                ),
                                Text(
                                  _userLevel.name[0],
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: orbSize * 0.1,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                          color: sphereColor.withOpacity(0.8),
                                          blurRadius: 16)
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (!_isCompact)
            AnimatedBuilder(
              animation: _orbitController,
              builder: (_, __) {
                final angle = _orbitController.value * 2 * math.pi;
                return Stack(
                  children: List.generate(5, (i) {
                    final a = angle + i * (math.pi / 2.5);
                    final dx = math.cos(a) * satelliteDistance;
                    final dy = math.sin(a) * satelliteDistance;
                    final icons = [
                      Icons.palette_outlined,
                      Icons.person_outline,
                      Icons.menu_book_outlined,
                      Icons.note_alt_outlined,
                      Icons.school, // Added for learning panel
                    ];
                    return Positioned(
                      left: orbSize / 2 + dx - satelliteSize / 2,
                      top: orbSize / 2 + dy - satelliteSize / 2,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _openPanel = _openPanel == i ? null : i;
                        }),
                        child: Container(
                          width: satelliteSize,
                          height: satelliteSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              _userLevel.color.withOpacity(0.4),
                              _userLevel.color.withOpacity(0.1),
                              Colors.black,
                            ]),
                            border: Border.all(
                                color: _userLevel.color.withOpacity(0.6),
                                width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                  color: _userLevel.color.withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 1),
                            ],
                          ),
                          child: Icon(icons[i],
                              color: Colors.white, size: satelliteSize * 0.5),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
        ],
      ),
    );
  } // ← This brace closes _buildMainOrb method

  Widget _buildThoughtStream() {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return FadeTransition(
      opacity: _revealController,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _selectedCourse ?? "Thought Stream",
                style: TextStyle(
                  color: _userLevel.color,
                  fontSize: isSmallScreen ? 12 : 13,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                        color: _userLevel.color.withOpacity(0.6), blurRadius: 8)
                  ],
                ),
              ),
              const Spacer(),
              if (_currentAnswer.isNotEmpty && !_currentAnswer.contains("⚠️"))
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.copy, color: _textSub, size: 14),
                      onPressed: () => _copyToClipboard(_currentAnswer),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.bookmark_border,
                          color: _textSub, size: 14),
                      onPressed: _addBookmark,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.save, color: _textSub, size: 14),
                      onPressed: _saveAsNote,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              if (_ollamaChecked && _ollamaAvailable)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Text("llama3",
                      style: TextStyle(color: Colors.green, fontSize: 7)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  minHeight: isSmallScreen ? 60 : 80,
                  maxHeight: isSmallScreen ? 150 : 200,
                ),
                padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                decoration: BoxDecoration(
                  color: _codeBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _panelBorder),
                  boxShadow: [
                    BoxShadow(
                        color: _userLevel.color.withOpacity(0.05),
                        blurRadius: 8)
                  ],
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _isSearching
                        ? "> Querying llama3..."
                        : (_currentAnswer.isEmpty
                            ? "> Ready to learn!"
                            : _currentAnswer),
                    style: TextStyle(
                        fontSize: isSmallScreen ? 9 : 10,
                        fontFamily: 'monospace',
                        color: _codeTextColor,
                        height: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: const EdgeInsets.only(left: 14, right: 4, top: 2, bottom: 2),
          decoration: BoxDecoration(
            color: _inputBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _inputBorder, width: _isLight ? 1 : 0.8),
            boxShadow: [
              BoxShadow(color: _accent.withOpacity(0.1), blurRadius: 10)
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  onSubmitted: (_) => _runSearch(),
                  style: TextStyle(
                      color: _textPrimary, fontSize: isSmallScreen ? 11 : 12),
                  decoration: InputDecoration(
                    hintText: _ollamaAvailable
                        ? "Ask about ${_userLevel.name.toLowerCase()}..."
                        : "Start Ollama...",
                    hintStyle: TextStyle(
                        color: _textFaint, fontSize: isSmallScreen ? 11 : 12),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _runSearch,
                child: Container(
                  width: isSmallScreen ? 30 : 34,
                  height: isSmallScreen ? 30 : 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        _userLevel.color,
                        _userLevel.color.withBlue(150)
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: _userLevel.color.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1)
                    ],
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ))
                      : Icon(Icons.send_rounded,
                          color: Colors.white, size: isSmallScreen ? 13 : 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVibeThemesPanel() {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    return _glassPanel(
      width: isSmallScreen ? 130 : 160,
      borderRadiusGeometry: const BorderRadius.only(
          topRight: Radius.circular(14), bottomRight: Radius.circular(14)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Themes",
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: isSmallScreen ? 10 : 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(
                vibeThemes.length,
                (i) => GestureDetector(
                      onTap: () {
                        setState(() => _selectedTheme = i);
                      },
                      child: Container(
                        width: isSmallScreen ? 30 : 35,
                        height: isSmallScreen ? 30 : 35,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-0.3, -0.3),
                            colors: [
                              vibeThemes[i].primary,
                              vibeThemes[i].secondary,
                            ],
                          ),
                          border: Border.all(
                            color: _selectedTheme == i
                                ? (_isLight ? Colors.black : Colors.white)
                                : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: _selectedTheme == i
                              ? [
                                  BoxShadow(
                                      color: vibeThemes[i]
                                          .primary
                                          .withOpacity(0.5),
                                      blurRadius: 8)
                                ]
                              : null,
                        ),
                      ),
                    )),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePanel() {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    User? firebaseUser;
    String displayName = widget.loginMethod;

    try {
      firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        displayName = firebaseUser.displayName ??
            firebaseUser.email ??
            widget.loginMethod;
      }
    } catch (e) {
      firebaseUser = null;
    }

    return _glassPanel(
      width: isSmallScreen ? 240 : 280,
      borderRadiusGeometry: const BorderRadius.only(
          topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Profile",
                    style: TextStyle(
                        color: _textPrimary,
                        fontSize: isSmallScreen ? 11 : 12,
                        fontWeight: FontWeight.bold)),
                Icon(Icons.person_outline, color: _accent, size: 16),
              ],
            ),
            const SizedBox(height: 12),

            // Avatar
            Center(
              child: Column(
                children: [
                  Container(
                    width: isSmallScreen ? 50 : 60,
                    height: isSmallScreen ? 50 : 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        _userLevel.color,
                        _userLevel.color.withBlue(100),
                        Colors.black
                      ]),
                      border: Border.all(
                          color: _userLevel.color.withOpacity(0.6), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                            color: _userLevel.color.withOpacity(0.4),
                            blurRadius: 10)
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _userLevel.name[0],
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 20 : 24,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    displayName.length > 15
                        ? "${displayName.substring(0, 12)}..."
                        : displayName,
                    style: TextStyle(
                        color: _userLevel.color,
                        fontSize: isSmallScreen ? 10 : 11,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Progress Tracker
            FutureBuilder<Map<String, int>>(
              future: PinStorage.getProgress(),
              builder: (context, snapshot) {
                final progress = snapshot.data ??
                    {'streak': 0, 'xp': 0, 'level': 1, 'nextLevelXp': 100};

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _userLevel.color.withOpacity(0.15),
                        _userLevel.color.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: _userLevel.color.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildProgressStat(
                            Icons.local_fire_department,
                            "${progress['streak']}",
                            "Streak",
                            Colors.orange,
                            isSmallScreen,
                          ),
                          _buildProgressStat(
                            Icons.bolt,
                            "${progress['xp']}",
                            "XP",
                            _userLevel.color,
                            isSmallScreen,
                          ),
                          _buildProgressStat(
                            Icons.stars,
                            "${progress['level']}",
                            "Level",
                            Colors.purple,
                            isSmallScreen,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (progress['xp']! % 100) / 100,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation(_userLevel.color),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${progress['nextLevelXp']} XP to next level",
                        style: TextStyle(
                          color: _textSub,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Settings
            Text("SETTINGS",
                style: TextStyle(
                    color: _accent,
                    fontSize: isSmallScreen ? 8 : 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            const SizedBox(height: 6),

            _buildSettingsTile(
              icon: Icons.lock_outline_rounded,
              title: "Change PIN",
              onTap: _changePin,
              isSmallScreen: isSmallScreen,
            ),

            const SizedBox(height: 6),

            Container(
              padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
              decoration: BoxDecoration(
                color: _rowBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _panelBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.language,
                          color: _accent, size: isSmallScreen ? 14 : 16),
                      const SizedBox(width: 6),
                      Text("Language",
                          style: TextStyle(
                              color: _textPrimary,
                              fontSize: isSmallScreen ? 10 : 11,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: _languages.take(3).map((lang) {
                      bool isSelected = _selectedLanguage == lang;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedLanguage = lang),
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _accent.withOpacity(0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? _accent : _panelBorder,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            lang,
                            style: TextStyle(
                              color: isSelected ? _accent : _textSub,
                              fontSize: isSmallScreen ? 8 : 9,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            GestureDetector(
              onTap: _signOut,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.logout, color: Colors.red, size: 12),
                      SizedBox(width: 4),
                      Text("Sign Out",
                          style: TextStyle(color: Colors.red, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStat(IconData icon, String value, String label,
      Color color, bool isSmallScreen) {
    return Column(
      children: [
        Icon(icon, color: color, size: isSmallScreen ? 14 : 16),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: isSmallScreen ? 12 : 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: _textSub,
            fontSize: isSmallScreen ? 6 : 7,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isSmallScreen,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
        decoration: BoxDecoration(
          color: _rowBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _panelBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: _accent, size: isSmallScreen ? 14 : 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      color: _textPrimary,
                      fontSize: isSmallScreen ? 10 : 11,
                      fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.arrow_forward_ios, color: _textSub, size: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursesPanel() {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    return _glassPanel(
      width: isSmallScreen ? 150 : 180,
      borderRadiusGeometry: const BorderRadius.only(
          topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${_userLevel.name} Courses",
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: isSmallScreen ? 9 : 10,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...List.generate(_userLevel.courses.length, (index) {
            final course = _userLevel.courses[index];
            final isSelected = _selectedCourse == course;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: GestureDetector(
                onTap: () => _selectCourse(course),
                child: Container(
                  padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _userLevel.color.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: isSelected ? _userLevel.color : _panelBorder,
                        width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: isSmallScreen ? 14 : 16,
                        height: isSmallScreen ? 14 : 16,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _userLevel.color.withOpacity(0.15)),
                        child: Center(
                            child: Text("${index + 1}",
                                style: TextStyle(
                                    color: _userLevel.color,
                                    fontSize: isSmallScreen ? 6 : 7))),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          course.length > (isSmallScreen ? 12 : 20)
                              ? "${course.substring(0, isSmallScreen ? 12 : 20)}..."
                              : course,
                          style: TextStyle(
                              color: isSelected ? _userLevel.color : _textSub,
                              fontSize: isSmallScreen ? 7 : 8),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNotesPanel() {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return _glassPanel(
      width: isSmallScreen ? 200 : 240,
      borderRadiusGeometry: const BorderRadius.only(
          topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
      child: DefaultTabController(
        length: 2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Notes",
                    style: TextStyle(
                        color: _textPrimary,
                        fontSize: isSmallScreen ? 10 : 11,
                        fontWeight: FontWeight.bold)),
                Icon(Icons.note_alt, color: _accent, size: 14),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 24,
              child: TabBar(
                indicatorColor: _accent,
                labelColor: _accent,
                unselectedLabelColor: _textSub,
                tabs: const [
                  Tab(text: "Notes", height: 20),
                  Tab(text: "Bookmarks", height: 20),
                ],
                labelStyle: const TextStyle(fontSize: 9),
                unselectedLabelStyle: const TextStyle(fontSize: 9),
              ),
            ),
            SizedBox(
              height: 150,
              child: TabBarView(
                children: [
                  // Notes Tab
                  _notes.isEmpty
                      ? Center(
                          child: Text(
                            "No notes yet",
                            style: TextStyle(color: _textFaint, fontSize: 9),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: _notes.length > 3 ? 3 : _notes.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 0.5, color: Colors.white12),
                          itemBuilder: (_, i) {
                            final key = _notes.keys.elementAt(i);
                            final note = _notes[key];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                note['title'] ?? "Untitled",
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.delete,
                                    color: Colors.red, size: 12),
                                onPressed: () async {
                                  await PinStorage.deleteNote(key);
                                  _loadNotes();
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            );
                          },
                        ),

                  // Bookmarks Tab
                  _bookmarks.isEmpty
                      ? Center(
                          child: Text(
                            "No bookmarks",
                            style: TextStyle(color: _textFaint, fontSize: 9),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount:
                              _bookmarks.length > 3 ? 3 : _bookmarks.length,
                          itemBuilder: (_, i) {
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                _bookmarks[i].length > 30
                                    ? "${_bookmarks[i].substring(0, 30)}..."
                                    : _bookmarks[i],
                                style:
                                    TextStyle(color: _textPrimary, fontSize: 8),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Icon(Icons.bookmark,
                                  color: _accent, size: 10),
                              onTap: () {
                                setState(() {
                                  _currentAnswer = _bookmarks[i];
                                });
                                _openPanel = null;
                              },
                            );
                          },
                        ),
                ],
              ),
            ),
            if (_notes.length > 3 || _bookmarks.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "View all in profile...",
                  style: TextStyle(color: _textFaint, fontSize: 7),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _glassPanel({
    required Widget child,
    double? width,
    BorderRadiusGeometry borderRadiusGeometry =
        const BorderRadius.all(Radius.circular(14)),
  }) {
    return ClipRRect(
      borderRadius: borderRadiusGeometry as BorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _isLight
                ? const Color(0xFFF0F6FF).withOpacity(0.85)
                : const Color(0xFF0A1A10).withOpacity(0.8),
            borderRadius: borderRadiusGeometry,
            border: Border.all(color: _panelBorder, width: _isLight ? 1 : 0.8),
            boxShadow: [
              BoxShadow(color: _accent.withOpacity(0.1), blurRadius: 10),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── CUSTOM PAINTER ─────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  final Color color;
  final bool isLight;
  _GridPainter(this.color, this.isLight);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(isLight ? 0.06 : 0.03)
      ..strokeWidth = 0.3;
    const step = 30.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
