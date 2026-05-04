import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'in_app_browser.dart';

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
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        await Firebase.initializeApp();
      }
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
  static final FlutterTts _tts = FlutterTts();
  static String _selectedVoice = "female";
  static String _locale = 'en-US';
  static bool _initialized = false;
  static bool _voiceApplied = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.setLanguage(_locale);
      _initialized = true;
    } catch (_) {
      // Keep fallback behavior (prints) if platform doesn't support TTS.
      _initialized = true;
    }
  }

  static Future<void> setLocale(String locale) async {
    final trimmed = locale.trim();
    if (trimmed.isEmpty) return;
    _locale = trimmed;
    _voiceApplied = false;
    if (!_initialized) await init();
    try {
      await _tts.setLanguage(_locale);
    } catch (_) {}
  }

  static Future<void> setVoice(String gender) async {
    _selectedVoice = gender;
    _voiceApplied = false;
    if (!_initialized) await init();
    try {
      final g = gender.toLowerCase();
      // Fallback: use pitch to approximate gender when platform voices don't expose it.
      // Many TTS engines don't label voices as "male/female" in the name.
      if (g == 'male') {
        await _tts.setPitch(0.70);
      } else if (g == 'female') {
        await _tts.setPitch(1.25);
      } else {
        await _tts.setPitch(1.0);
      }

      final voices = await _tts.getVoices;
      if (voices is List) {
        Map? picked;
        final localePrefix = _locale.toLowerCase().split('-').first;
        for (final v in voices) {
          if (v is Map) {
            final name = (v['name'] ?? '').toString().toLowerCase();
            final locale = (v['locale'] ?? '').toString().toLowerCase();
            if (!locale.startsWith(localePrefix)) continue;
            final voiceGender = (v['gender'] ?? '').toString().toLowerCase();
            if (g == 'female' &&
                (voiceGender.contains('female') ||
                    name.contains('female') ||
                    name.contains('woman') ||
                    name.contains('zira') ||
                    name.contains('susan') ||
                    name.contains('samantha'))) {
              picked = v;
              break;
            }
            if (g == 'male' &&
                (voiceGender.contains('male') ||
                    name.contains('male') ||
                    name.contains('man') ||
                    name.contains('david') ||
                    name.contains('mark') ||
                    name.contains('alex') ||
                    name.contains('daniel'))) {
              picked = v;
              break;
            }
          }
        }
        // If we still didn't find a gendered voice, pick the first matching-locale voice.
        picked ??= voices.cast<dynamic>().firstWhere(
              (v) =>
                  v is Map &&
                  ((v['locale'] ?? '')
                      .toString()
                      .toLowerCase()
                      .startsWith(localePrefix)),
              orElse: () => null,
            );
        if (picked != null) {
          await _tts.setVoice({'name': picked['name'], 'locale': picked['locale']});
        }
      }
      _voiceApplied = true;
    } catch (_) {}
  }

  static String get currentVoice => _selectedVoice;

  static Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    if (!_initialized) await init();
    try {
      try {
        await _tts.setLanguage(_locale);
      } catch (_) {}
      // Re-apply pitch/voice on each speak because some engines reset these values.
      if (!_voiceApplied) {
        await setVoice(_selectedVoice);
      } else {
        final g = _selectedVoice.toLowerCase();
        if (g == 'male') {
          await _tts.setPitch(0.70);
        } else if (g == 'female') {
          await _tts.setPitch(1.25);
        } else {
          await _tts.setPitch(1.0);
        }
      }
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      print("AURA ($_selectedVoice): $text");
    }
  }

  static Future<void> stop() async {
    if (!_initialized) return;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  static Future<String?> listen() async {
    // Legacy stub; the app now uses `speech_to_text` for real microphone input
    // via voice chat on Android/iOS. Returning null prevents accidental
    // auto-filling the input field with placeholder text.
    return null;
  }
}

// ─── TIME / TIMER / REMINDER ─────────────────────────────────────────
class TimeTools {
  static DateTime nowLocal() => DateTime.now().toLocal();

  static String formatNow() {
    final n = nowLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final offset = n.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hh = two(offset.inHours.abs());
    final mm = two(offset.inMinutes.abs() % 60);
    return '${n.year}-${two(n.month)}-${two(n.day)} ${two(n.hour)}:${two(n.minute)}:${two(n.second)} (UTC$sign$hh:$mm)';
  }

  static bool isTimeQuery(String q) {
    final s = q.trim().toLowerCase();
    return s.contains('time') ||
        s.contains('date') ||
        s.contains('day') ||
        s.contains('clock') ||
        RegExp(r'\\bwhat\\s+time\\b').hasMatch(s) ||
        RegExp(r'\\bwhat\\s+date\\b').hasMatch(s);
  }

  static Duration? parseDuration(String q) {
    final s = q.toLowerCase();
    final matches = RegExp(
      r'(\\d+)\\s*(seconds?|secs?|s|minutes?|mins?|m|hours?|hrs?|h|days?|d)\\b',
    ).allMatches(s);
    if (matches.isEmpty) return null;
    int seconds = 0;
    for (final m in matches) {
      final value = int.tryParse(m.group(1) ?? '');
      if (value == null || value <= 0) continue;
      final unit = (m.group(2) ?? '').toLowerCase();
      if (unit.startsWith('s')) seconds += value;
      if (unit.startsWith('m')) seconds += value * 60;
      if (unit.startsWith('h')) seconds += value * 3600;
      if (unit.startsWith('d')) seconds += value * 86400;
    }
    if (seconds <= 0) return null;
    return Duration(seconds: seconds);
  }

  static bool looksLikeTimer(String q) {
    final s = q.toLowerCase();
    return s.contains('timer') ||
        s.contains('countdown') ||
        s.contains('count down') ||
        RegExp(r'\\b(remind me|in)\\b').hasMatch(s) ||
        RegExp(r'\\bfor\\s+\\d+\\s*(s|sec|secs|seconds|m|min|mins|minutes|h|hr|hrs|hours|d|day|days)\\b')
            .hasMatch(s);
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb || Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      _initialized = false;
      return;
    }
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: android);
      await _plugin.initialize(initSettings);
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();
    if (!_initialized) return;
    try {
      const androidDetails = AndroidNotificationDetails(
        'aura_reminders',
        'AURA Reminders',
        channelDescription: 'Timers and reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      const details = NotificationDetails(android: androidDetails);
      await _plugin.show(id, title, body, details);
    } catch (_) {}
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
  String? studyUrl;
  bool completed;
  bool studied;
  double quizScore;
  bool quizPassed;

  Topic({
    required this.id,
    required this.title,
    this.studyUrl,
    this.completed = false,
    this.studied = false,
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
  bool finalExamUnlocked;
  bool finalExamCompleted;
  bool finalExamPassed;
  double finalExamScore;

  Course({
    required this.id,
    required this.title,
    required this.level,
    required this.units,
    this.certificateEarned = false,
    this.finalBadge = BadgeLevel.none,
    this.finalScore = 0,
    this.worldRank = 0,
    this.finalExamUnlocked = false,
    this.finalExamCompleted = false,
    this.finalExamPassed = false,
    this.finalExamScore = 0,
  });
}

class CatalogCourse {
  final String id;
  final String title;
  final String level;
  final String providerUrl;
  final List<String> unitTitles;
  final Map<String, List<String>> unitTopics;

  CatalogCourse({
    required this.id,
    required this.title,
    required this.level,
    required this.providerUrl,
    required this.unitTitles,
    required this.unitTopics,
  });

  factory CatalogCourse.fromJson(Map<String, dynamic> json) {
    final unitTitles = (json['unitTitles'] as List?)?.cast<String>() ?? const [];

    final level = (json['level'] ?? 'beginner').toString().toLowerCase().trim();
    final providerUrl = (json['providerUrl'] ?? '').toString().trim();

    final unitTopicsRaw = json['unitTopics'];
    final Map<String, List<String>> unitTopics = {};
    if (unitTopicsRaw is Map) {
      for (final entry in unitTopicsRaw.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is List) {
          unitTopics[key] = value.map((e) => e.toString()).toList();
        }
      }
    } else if (unitTopicsRaw is List) {
      // In `assets/data/course_catalog.json`, `unitTopics` is a List<List<String>> aligned with `unitTitles`.
      for (int i = 0; i < unitTitles.length && i < unitTopicsRaw.length; i++) {
        final value = unitTopicsRaw[i];
        if (value is List) {
          unitTopics[unitTitles[i]] = value.map((e) => e.toString()).toList();
        }
      }
    }

    return CatalogCourse(
      id: json['id']?.toString() ?? json['title']?.toString() ?? 'unknown',
      title: json['title']?.toString() ?? 'Untitled',
      level: level,
      providerUrl: providerUrl,
      unitTitles: unitTitles,
      unitTopics: unitTopics,
    );
  }
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
    title: "Select a course",
    level: level,
    units: [
      Unit(
        id: "unit_select",
        title: "Choose a Course",
        topics: [
          Topic(id: "topic_select", title: "Tap a course to start learning"),
        ],
      ),
    ],
  );
}

// ─── QUIZ SERVICE ───────────────────────────────────────────────────
class QuizService {
  static List<Map<String, dynamic>> generateQuiz({
    required String courseTitle,
    required String topicTitle,
    String assessmentType = 'quiz',
    int count = 5,
  }) {
    final seed = _stableSeed('$courseTitle::$topicTitle::$assessmentType');
    final rand = math.Random(seed);

    final domain = _detectDomain(courseTitle, topicTitle);
    final bank = _questionBank(domain, topicTitle, assessmentType);

    final selected = List<_Question>.from(bank);
    selected.shuffle(rand);

    final n = math.min(count, selected.length);
    return List.generate(n, (i) => selected[i].toMap(rand));
  }

  static int _stableSeed(String s) {
    int h = 2166136261;
    for (final unit in s.codeUnits) {
      h ^= unit;
      h = (h * 16777619) & 0x7fffffff;
    }
    return h;
  }

  static String _detectDomain(String courseTitle, String topicTitle) {
    final t = '${courseTitle.toLowerCase()} ${topicTitle.toLowerCase()}';
    if (t.contains('python')) return 'python';
    if (t.contains('html')) return 'html';
    if (t.contains('css')) return 'css';
    if (t.contains('javascript') || t.contains('js')) return 'javascript';
    if (t.contains('git') || t.contains('github')) return 'git';
    if (t.contains('sql') || t.contains('database')) return 'sql';
    if (t.contains('docker')) return 'docker';
    if (t.contains('api') || t.contains('rest')) return 'api';
    if (t.contains('security') || t.contains('cyber')) return 'security';
    if (t.contains('cloud') || t.contains('aws') || t.contains('gcp')) {
      return 'cloud';
    }
    if (t.contains('devops')) return 'devops';
    if (t.contains('mobile') || t.contains('android') || t.contains('flutter')) {
      return 'mobile';
    }
    if (t.contains('machine learning') || t.contains('ml')) return 'ml';
    return 'general';
  }

  static List<_Question> _questionBank(
    String domain,
    String topicTitle,
    String assessmentType,
  ) {
    final topic = topicTitle.toLowerCase();

    List<_Question> base;
    switch (domain) {
      case 'python':
        base = [
          _Question(
            question: 'Which line correctly assigns a value to a variable?',
            correct: 'x = 5',
            distractors: ['var x = 5', 'int x = 5', 'x := 5'],
          ),
          _Question(
            question: 'Which data type is immutable in Python?',
            correct: 'Tuple',
            distractors: ['List', 'Dictionary', 'Set'],
          ),
          _Question(
            question: 'How do you define a function in Python?',
            correct: 'def my_func():',
            distractors: ['function my_func():', 'func my_func():', 'define my_func():'],
          ),
          _Question(
            question: 'What does `len(my_list)` return?',
            correct: 'Number of elements in the list',
            distractors: ['Sum of elements', 'Last element', 'List capacity'],
          ),
          _Question(
            question: 'Which keyword starts a loop over a sequence?',
            correct: 'for',
            distractors: ['loop', 'repeat', 'foreach'],
          ),
        ];

        if (topic.contains('variable') || topic.contains('data type')) {
          base.addAll([
            _Question(
              question: 'Which is a valid variable name in Python?',
              correct: 'my_var',
              distractors: ['2var', 'my-var', 'my var'],
            ),
            _Question(
              question: 'Which converts a value to an integer?',
              correct: 'int(value)',
              distractors: ['integer(value)', 'toInt(value)', 'parseInt(value)'],
            ),
          ]);
        }

        if (topic.contains('string')) {
          base.addAll([
            _Question(
              question: 'How do you get the length of a string `s`?',
              correct: 'len(s)',
              distractors: ['s.length', 'length(s)', 'count(s)'],
            ),
            _Question(
              question: 'What does `"hi".upper()` return?',
              correct: 'HI',
              distractors: ['hi', 'Hi', 'hI'],
            ),
          ]);
        }

        if (topic.contains('loop')) {
          base.addAll([
            _Question(
              question: 'Which loop repeats while a condition is true?',
              correct: 'while',
              distractors: ['during', 'repeat', 'until'],
            ),
          ]);
        }
        break;

      case 'html':
        base = [
          _Question(
            question: 'What does HTML stand for?',
            correct: 'HyperText Markup Language',
            distractors: [
              'HighText Markdown Language',
              'Hyperlink Markup Language',
              'Home Tool Markup Language'
            ],
          ),
          _Question(
            question: 'Which tag is used for the largest heading?',
            correct: '<h1>',
            distractors: ['<head>', '<h6>', '<heading>'],
          ),
          _Question(
            question: 'Which attribute specifies a link URL?',
            correct: 'href',
            distractors: ['src', 'link', 'url'],
          ),
          _Question(
            question: 'Which tag inserts a line break?',
            correct: '<br>',
            distractors: ['<lb>', '<break>', '<p>'],
          ),
          _Question(
            question: 'Which tag is used to create a list item?',
            correct: '<li>',
            distractors: ['<ul>', '<ol>', '<list>'],
          ),
        ];
        break;

      case 'css':
        base = [
          _Question(
            question: 'What does CSS stand for?',
            correct: 'Cascading Style Sheets',
            distractors: [
              'Creative Style System',
              'Computer Style Sheets',
              'Colorful Style Sheets'
            ],
          ),
          _Question(
            question: 'Which selector targets an element by id?',
            correct: '#myId',
            distractors: ['.myId', 'myId', '*myId'],
          ),
          _Question(
            question: 'Which property changes text color?',
            correct: 'color',
            distractors: ['font-color', 'text-color', 'foreground'],
          ),
          _Question(
            question: 'Which property sets the space inside an element?',
            correct: 'padding',
            distractors: ['margin', 'border', 'gap'],
          ),
          _Question(
            question: 'Which unit is relative to the font size?',
            correct: 'em',
            distractors: ['px', 'cm', 'pt'],
          ),
        ];
        break;

      case 'javascript':
        base = [
          _Question(
            question: 'Which keyword declares a block-scoped variable?',
            correct: 'let',
            distractors: ['var', 'define', 'int'],
          ),
          _Question(
            question: 'Which is a strict equality operator?',
            correct: '===',
            distractors: ['==', '=', '=>'],
          ),
          _Question(
            question: 'How do you write a function named `sum`?',
            correct: 'function sum() {}',
            distractors: ['def sum():', 'func sum() {}', 'sum => {}'],
          ),
          _Question(
            question: 'Which method converts JSON string to an object?',
            correct: 'JSON.parse(...)',
            distractors: ['JSON.stringify(...)', 'toJSON(...)', 'parseJSON(...)'],
          ),
          _Question(
            question: 'Which statement handles errors?',
            correct: 'try/catch',
            distractors: ['if/else', 'switch', 'for/while'],
          ),
        ];
        break;

      case 'git':
        base = [
          _Question(
            question: 'Which command records changes in the repository history?',
            correct: 'git commit',
            distractors: ['git push', 'git clone', 'git init'],
          ),
          _Question(
            question: 'Which command downloads changes from a remote without merging?',
            correct: 'git fetch',
            distractors: ['git pull', 'git push', 'git merge'],
          ),
          _Question(
            question: 'What is a branch?',
            correct: 'An independent line of development',
            distractors: ['A remote server', 'A commit message', 'A file type'],
          ),
          _Question(
            question: 'Which command shows current changes?',
            correct: 'git status',
            distractors: ['git log', 'git diff --cached', 'git remote -v'],
          ),
          _Question(
            question: 'Which command creates a new branch named `feature`?',
            correct: 'git switch -c feature',
            distractors: ['git checkout feature --new', 'git branch --new feature', 'git new feature'],
          ),
        ];
        break;

      case 'sql':
        base = [
          _Question(
            question: 'Which SQL statement is used to read data?',
            correct: 'SELECT',
            distractors: ['UPDATE', 'DELETE', 'INSERT'],
          ),
          _Question(
            question: 'Which clause filters rows?',
            correct: 'WHERE',
            distractors: ['ORDER BY', 'GROUP BY', 'LIMIT'],
          ),
          _Question(
            question: 'Which keyword sorts results?',
            correct: 'ORDER BY',
            distractors: ['SORT', 'GROUP BY', 'ARRANGE'],
          ),
          _Question(
            question: 'What does a primary key do?',
            correct: 'Uniquely identifies a row',
            distractors: ['Encrypts a table', 'Duplicates data', 'Creates an index only'],
          ),
          _Question(
            question: 'Which join returns matching rows from both tables?',
            correct: 'INNER JOIN',
            distractors: ['LEFT JOIN', 'RIGHT JOIN', 'FULL OUTER JOIN'],
          ),
        ];
        break;

      case 'api':
        base = [
          _Question(
            question: 'What does REST commonly use to identify resources?',
            correct: 'URLs (endpoints)',
            distractors: ['Databases', 'Threads', 'Sockets only'],
          ),
          _Question(
            question: 'Which HTTP method is typically used to create a resource?',
            correct: 'POST',
            distractors: ['GET', 'PUT', 'DELETE'],
          ),
          _Question(
            question: 'Which status code means “Not Found”?',
            correct: '404',
            distractors: ['200', '201', '500'],
          ),
          _Question(
            question: 'What format is commonly used in APIs?',
            correct: 'JSON',
            distractors: ['MP3', 'DOCX', 'PNG'],
          ),
          _Question(
            question: 'What does authentication prove?',
            correct: 'Who you are',
            distractors: ['What you can do', 'How fast you are', 'What device you use'],
          ),
        ];
        break;

      case 'docker':
        base = [
          _Question(
            question: 'What is a Docker image?',
            correct: 'A template used to create containers',
            distractors: ['A running container', 'A virtual machine', 'A source code repository'],
          ),
          _Question(
            question: 'Which file commonly defines how to build an image?',
            correct: 'Dockerfile',
            distractors: ['docker.json', 'compose.yaml only', 'image.lock'],
          ),
          _Question(
            question: 'Which command builds an image?',
            correct: 'docker build',
            distractors: ['docker run', 'docker push', 'docker start'],
          ),
          _Question(
            question: 'Which command lists running containers?',
            correct: 'docker ps',
            distractors: ['docker images', 'docker logs', 'docker exec'],
          ),
          _Question(
            question: 'What does port mapping do?',
            correct: 'Exposes a container port to the host',
            distractors: ['Encrypts traffic', 'Stores secrets', 'Compiles code'],
          ),
        ];
        break;

      case 'security':
        base = [
          _Question(
            question: 'What is phishing?',
            correct: 'Tricking users to reveal sensitive info',
            distractors: ['Encrypting files', 'Fixing bugs', 'Compressing data'],
          ),
          _Question(
            question: 'What does MFA add?',
            correct: 'An additional verification step',
            distractors: ['A bigger password', 'A faster CPU', 'A new browser'],
          ),
          _Question(
            question: 'What is encryption used for?',
            correct: 'Protecting data confidentiality',
            distractors: ['Increasing file size', 'Deleting logs', 'Making apps faster'],
          ),
          _Question(
            question: 'Least privilege means:',
            correct: 'Give only necessary access',
            distractors: ['Give admin access', 'Give no access', 'Share credentials'],
          ),
          _Question(
            question: 'A strong password should be:',
            correct: 'Long and unique',
            distractors: ['Short and memorable', 'Same everywhere', 'Only numbers'],
          ),
        ];
        break;

      case 'cloud':
        base = [
          _Question(
            question: 'What is scalability in cloud computing?',
            correct: 'Ability to handle increased load',
            distractors: ['Ability to change colors', 'Ability to delete data', 'Ability to print reports'],
          ),
          _Question(
            question: 'What is a common benefit of cloud services?',
            correct: 'Pay-as-you-go pricing',
            distractors: ['No internet needed', 'Always free', 'Runs only on one device'],
          ),
          _Question(
            question: 'What is object storage best for?',
            correct: 'Storing files/blobs (images, backups)',
            distractors: ['Executing code', 'Running CPUs only', 'Managing keyboards'],
          ),
          _Question(
            question: 'What is a region?',
            correct: 'A geographic area with data centers',
            distractors: ['A user account', 'A programming language', 'A database table'],
          ),
          _Question(
            question: 'What does “high availability” aim for?',
            correct: 'Minimizing downtime',
            distractors: ['More colors', 'More ads', 'Less security'],
          ),
        ];
        break;

      case 'devops':
        base = [
          _Question(
            question: 'What is CI (Continuous Integration)?',
            correct: 'Automatically building/testing merged code',
            distractors: ['Manually editing servers', 'A database tool', 'A design pattern'],
          ),
          _Question(
            question: 'What is CD (Continuous Delivery/Deployment)?',
            correct: 'Automating release of changes',
            distractors: ['Copying documents', 'Creating designs', 'Compressing data'],
          ),
          _Question(
            question: 'What does monitoring help with?',
            correct: 'Detecting issues and performance problems',
            distractors: ['Writing code', 'Designing UI', 'Creating passwords'],
          ),
          _Question(
            question: 'Infrastructure as Code means:',
            correct: 'Managing infra via versioned configuration',
            distractors: ['Writing apps only', 'Buying hardware', 'Avoiding automation'],
          ),
          _Question(
            question: 'A common deployment strategy is:',
            correct: 'Blue/green deployment',
            distractors: ['Red/yellow deployment', 'Push/pull deployment', 'Up/down deployment'],
          ),
        ];
        break;

      case 'mobile':
        base = [
          _Question(
            question: 'What does a “widget” represent in Flutter?',
            correct: 'A piece of UI',
            distractors: ['A database', 'A server', 'A file system'],
          ),
          _Question(
            question: 'Which method builds the UI in Flutter?',
            correct: 'build()',
            distractors: ['render()', 'draw()', 'compose()'],
          ),
          _Question(
            question: 'What does hot reload do?',
            correct: 'Updates UI without restarting the app',
            distractors: ['Deletes cache', 'Publishes the app', 'Creates an APK'],
          ),
          _Question(
            question: 'What is an APK?',
            correct: 'Android application package',
            distractors: ['Apple kit', 'A database file', 'A Linux bundle'],
          ),
          _Question(
            question: 'Which file lists Flutter dependencies?',
            correct: 'pubspec.yaml',
            distractors: ['package.json', 'requirements.txt', 'build.gradle only'],
          ),
        ];
        break;

      case 'ml':
        base = [
          _Question(
            question: 'What is supervised learning?',
            correct: 'Learning from labeled examples',
            distractors: ['Learning without data', 'Only using images', 'Random guessing'],
          ),
          _Question(
            question: 'What is overfitting?',
            correct: 'Model performs well on training but poorly on new data',
            distractors: ['Model is too small', 'Model never trains', 'Model has no labels'],
          ),
          _Question(
            question: 'What is a feature?',
            correct: 'An input variable used by a model',
            distractors: ['A bug', 'A database', 'A server'],
          ),
          _Question(
            question: 'What does “accuracy” measure?',
            correct: 'Correct predictions / total predictions',
            distractors: ['Training speed', 'Model size', 'Number of features'],
          ),
          _Question(
            question: 'What is a common train/test split for?',
            correct: 'Evaluating generalization',
            distractors: ['Making data smaller', 'Encrypting data', 'Removing labels'],
          ),
        ];
        break;

      default:
        base = [
          _Question(
            question: 'Which approach is best for learning a new topic?',
            correct: 'Practice and review concepts regularly',
            distractors: ['Memorize once and stop', 'Avoid examples', 'Skip fundamentals'],
          ),
          _Question(
            question: 'What helps you debug faster?',
            correct: 'Reproduce the issue and read error messages',
            distractors: ['Guess randomly', 'Change many things at once', 'Ignore logs'],
          ),
          _Question(
            question: 'A good study habit is:',
            correct: 'Small consistent sessions',
            distractors: ['Cramming once a month', 'Never taking breaks', 'Only watching videos'],
          ),
          _Question(
            question: 'Which is a good way to retain knowledge?',
            correct: 'Spaced repetition',
            distractors: ['One long session', 'No practice', 'Only reading'],
          ),
          _Question(
            question: 'When you get stuck, you should:',
            correct: 'Break the problem into smaller parts',
            distractors: ['Quit immediately', 'Delete the project', 'Avoid asking questions'],
          ),
        ];
        break;
    }

    // For "formative" and "exam", mix in some broader questions by duplicating
    // the base set and shuffling later (selection happens in generateQuiz).
    if (assessmentType != 'quiz') {
      base = [...base, ...base];
    }
    return base;
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
      case 'final':
        return score >= 85;
      default:
        return false;
    }
  }
}

class _Question {
  final String question;
  final String correct;
  final List<String> distractors;

  const _Question({
    required this.question,
    required this.correct,
    required this.distractors,
  });

  Map<String, dynamic> toMap(math.Random rand) {
    final options = <String>[correct, ...distractors];
    options.shuffle(rand);
    return {
      'question': question,
      'options': options,
      'correct': options.indexOf(correct),
    };
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
  static const String _speakAnswersKey = 'speak_answers';
  static const String _aiEngineKey = 'ai_engine';
  static const String _groqApiKey = 'groq_api_key';
  static const String _geminiApiKey = 'gemini_api_key';
  static const String _claudeApiKey = 'claude_api_key';
  static const String _groqModelKey = 'groq_model_v1';
  static const String _openAiModelKey = 'openai_model_v1';
  static const String _geminiModelKey = 'gemini_model_v1';
  static const String _claudeModelKey = 'claude_model_v1';
  static const String _conversationStyleKey = 'conversation_style';
  static const String _imageProviderKey = 'image_provider';
  static const String _openAiApiKey = 'openai_api_key';
  static const String _webSearchEnabledKey = 'web_search_enabled';
  static const String _serperApiKey = 'serper_api_key';
  static const String _moodModeKey = 'mood_mode';
  static const String _chatByContextKey = 'chat_by_context_v1';
  static const String _chatContextKey = 'chat_context_key_v1';
  static const String _chatSummaryByContextKey = 'chat_summary_by_context_v1';
  static const String _lastSelectedLevelKey = 'last_selected_level_v1';

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

  static Future<void> setLastSelectedLevel(SkillLevel level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSelectedLevelKey, level.name);
    } catch (_) {}
  }

  static Future<SkillLevel?> getLastSelectedLevel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_lastSelectedLevelKey);
      if (raw == null || raw.trim().isEmpty) return null;
      return SkillLevel.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => SkillLevel.beginner,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> setSpeakAnswers(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_speakAnswersKey, enabled);
    } catch (e) {}
  }

  static Future<bool> getSpeakAnswers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_speakAnswersKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> setAiEngine(String engine) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_aiEngineKey, engine);
    } catch (e) {}
  }

  static Future<String?> getAiEngine() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_aiEngineKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> setGroqApiKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_groqApiKey, key);
    } catch (e) {}
  }

  static Future<String?> getGroqApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_groqApiKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> setGeminiApiKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_geminiApiKey, key);
    } catch (e) {}
  }

  static Future<String?> getGeminiApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_geminiApiKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> setClaudeApiKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_claudeApiKey, key);
    } catch (e) {}
  }

  static Future<String?> getClaudeApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_claudeApiKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> setGroqModel(String model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_groqModelKey, model);
    } catch (_) {}
  }

  static Future<String?> getGroqModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_groqModelKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setOpenAiModel(String model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_openAiModelKey, model);
    } catch (_) {}
  }

  static Future<String?> getOpenAiModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_openAiModelKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setGeminiModel(String model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_geminiModelKey, model);
    } catch (_) {}
  }

  static Future<String?> getGeminiModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_geminiModelKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setClaudeModel(String model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_claudeModelKey, model);
    } catch (_) {}
  }

  static Future<String?> getClaudeModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_claudeModelKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setConversationStyle(String style) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_conversationStyleKey, style);
    } catch (e) {}
  }

  static Future<String?> getConversationStyle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_conversationStyleKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> setImageProvider(String provider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_imageProviderKey, provider);
    } catch (e) {}
  }

  static Future<String?> getImageProvider() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_imageProviderKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> setOpenAiApiKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_openAiApiKey, key);
    } catch (e) {}
  }

  static Future<String?> getOpenAiApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_openAiApiKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> setWebSearchEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_webSearchEnabledKey, enabled);
    } catch (e) {}
  }

  static Future<bool> getWebSearchEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_webSearchEnabledKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> setSerperApiKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_serperApiKey, key);
    } catch (e) {}
  }

  static Future<String?> getSerperApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_serperApiKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> setMoodMode(String mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_moodModeKey, mode);
    } catch (e) {}
  }

  static Future<String?> getMoodMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_moodModeKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> setChatContextKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chatContextKey, key);
    } catch (e) {}
  }

  static Future<String> getChatContextKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_chatContextKey) ?? 'general';
    } catch (e) {
      return 'general';
    }
  }

  static Future<void> saveChatByContext(Map<String, List<String>> chats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        chats.map((k, v) => MapEntry(k, v)),
      );
      await prefs.setString(_chatByContextKey, encoded);
    } catch (e) {}
  }

  static Future<Map<String, List<String>>> loadChatByContext() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chatByContextKey);
      if (raw == null || raw.isEmpty) return {'general': <String>[]};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {'general': <String>[]};
      final out = <String, List<String>>{};
      for (final entry in decoded.entries) {
        final k = entry.key.toString();
        final v = entry.value;
        if (v is List) {
          out[k] = v.map((e) => e.toString()).toList();
        }
      }
      out.putIfAbsent('general', () => <String>[]);
      return out;
    } catch (e) {
      return {'general': <String>[]};
    }
  }

  static Future<void> saveChatSummaryByContext(
      Map<String, String> summaries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chatSummaryByContextKey, jsonEncode(summaries));
    } catch (_) {}
  }

  static Future<Map<String, String>> loadChatSummaryByContext() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chatSummaryByContextKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
      );
    } catch (_) {
      return {};
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
        'finalExamUnlocked': course.finalExamUnlocked,
        'finalExamCompleted': course.finalExamCompleted,
        'finalExamPassed': course.finalExamPassed,
        'finalExamScore': course.finalExamScore,
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
                            'studyUrl': topic.studyUrl,
                            'completed': topic.completed,
                            'studied': topic.studied,
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
                            studyUrl: (topicData['studyUrl'] ?? '').toString().trim().isEmpty
                                ? null
                                : topicData['studyUrl'].toString(),
                            completed: topicData['completed'] ?? false,
                            studied: topicData['studied'] ?? false,
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
          finalExamUnlocked: data['finalExamUnlocked'] ?? false,
          finalExamCompleted: data['finalExamCompleted'] ?? false,
          finalExamPassed: data['finalExamPassed'] ?? false,
          finalExamScore: (data['finalExamScore'] ?? 0).toDouble(),
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

  static String buildSystemPrompt(
    String levelName,
    String? selectedCourse, {
    required String style,
    bool forceCasual = false,
    String? moodInstruction,
    String? availableLevels,
    String? appGuide,
    String? preferredLanguage,
  }) {
    final courseContext = selectedCourse != null
        ? 'The user is currently studying: $selectedCourse. '
        : '';
    final toneBlock = (style == 'study' && !forceCasual)
        ? 'Tone: Be professional, helpful, structured, and teacher-like when needed.'
        : 'Tone: Be professional, friendly, and concise (avoid slang).';
    final moodBlock = (moodInstruction == null || moodInstruction.trim().isEmpty)
        ? ''
        : '\n$moodInstruction';
    final levelsBlock = (availableLevels == null || availableLevels.trim().isEmpty)
        ? ''
        : '\nAvailable skill levels in this app: $availableLevels.';
    final guideBlock = (appGuide == null || appGuide.trim().isEmpty)
        ? ''
        : '\n\nApp guide (use this to help the user navigate the app when they ask):\n$appGuide';
    final languageBlock =
        (preferredLanguage == null || preferredLanguage.trim().isEmpty)
            ? ''
            : '\n\nDefault reply language: $preferredLanguage.';
    return '''You are AURA, the assistant inside the Aura app.
$courseContext The user's current skill level is: $levelName.$levelsBlock
$toneBlock
$moodBlock
$guideBlock
$languageBlock

Important:
- Default to answering directly. Don’t explain basic words unless asked.
- Do not use slang (e.g., don’t call the user “bro”). Keep it serious and helpful.
- Do not invent app features or settings. If you’re unsure, say you’re not sure and ask 1 short question.
- When asked about skill levels, only use the levels listed above (don’t add/remove levels).
- If the user asks to change their skill level, instruct them to use the app’s `Level` button and pick one of the available levels.
- You can also help with general real-world questions (life, work, learning). If the request is ambiguous, ask 1 short question.
- Identity rules:
  - Do NOT expand “AURA” into an acronym. The app name is just “AURA”.
  - Do NOT say you are “a machine learning model”, “ChatGPT”, or talk about your training data.
  - Do NOT claim the user is an “advanced user” or change their level; if asked, repeat exactly: $levelName.
- Language rules:
  - Reply in the user’s language; if unclear, use the default reply language.
  - If the user asks “let’s speak <language>”, switch to that language immediately and keep using it.

Guidelines:
- If the question is about learning, tailor explanations to a $levelName level student.
- Be concise but thorough. Use examples when helpful.
- For code examples, use proper formatting.
- Don’t invent missing context. If the user’s request is ambiguous, make a reasonable assumption and answer; only ask 1 short clarifying question if you truly cannot proceed.
- If the user has typos or unclear wording, infer the most likely intent and answer directly. If still ambiguous, offer 2–4 likely interpretations and ask the user to pick one.
- If the user asks for something unsafe or illegal, refuse briefly and offer a safer alternative.
- Start responses directly without preamble.''';
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

// ─── GROQ SERVICE (Cloud) ────────────────────────────────────────────
class GroqService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1';
  static const String _defaultModel = 'llama-3.1-8b-instant';

  static Future<String> generate({
    required String apiKey,
    required String prompt,
    required String systemPrompt,
    List<Map<String, String>>? messages,
    String model = _defaultModel,
    required Function(String chunk) onChunk,
  }) async {
    final uri = Uri.parse('$_baseUrl/chat/completions');

    try {
      int attempt = 0;
      while (true) {
        attempt++;
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $apiKey';
      request.body = jsonEncode({
        'model': model,
        'stream': true,
        'temperature': 0.4,
        'messages': (messages != null && messages.isNotEmpty)
            ? messages
            : [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': prompt},
              ],
      });

      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Groq timeout'),
          );

      if (streamedResponse.statusCode == 401) {
        throw Exception('Invalid Groq API key');
      }
      if (streamedResponse.statusCode == 429) {
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 600 * attempt));
          continue;
        }
        throw Exception('Groq rate limit reached. Please wait and try again.');
      }
      if (streamedResponse.statusCode < 200 || streamedResponse.statusCode >= 300) {
        throw Exception('Groq returned status ${streamedResponse.statusCode}');
      }

      final StringBuffer fullResponse = StringBuffer();

      await for (final rawLine in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;
        if (line == 'data: [DONE]') break;
        if (!line.startsWith('data: ')) continue;
        final data = line.substring('data: '.length);
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final choices = json['choices'];
          if (choices is List && choices.isNotEmpty) {
            final delta = (choices.first as Map<String, dynamic>)['delta'];
            if (delta is Map<String, dynamic>) {
              final content = delta['content'];
              if (content is String && content.isNotEmpty) {
                fullResponse.write(content);
                onChunk(fullResponse.toString());
              }
            }
          }
        } catch (_) {}
      }

      return fullResponse.toString();
      }
    } on SocketException catch (_) {
      throw Exception(
        'Network error: unable to reach Groq (check internet/DNS).',
      );
    } on TimeoutException catch (_) {
      throw Exception('Groq request timed out. Try again.');
    } catch (e) {
      rethrow;
    }
  }
}

// ─── OPENAI CHAT (Cloud) ─────────────────────────────────────────────
class OpenAiChatService {
  static const String _baseUrl = 'https://api.openai.com/v1';

  static Future<String> generate({
    required String apiKey,
    required String prompt,
    required String systemPrompt,
    List<Map<String, String>>? messages,
    String model = 'gpt-4.1-mini',
    required Function(String chunk) onChunk,
  }) async {
    final uri = Uri.parse('$_baseUrl/chat/completions');
    try {
      int attempt = 0;
      while (true) {
        attempt++;
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $apiKey';
      request.body = jsonEncode({
        'model': model,
        'stream': true,
        'temperature': 0.4,
        'messages': (messages != null && messages.isNotEmpty)
            ? messages
            : [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': prompt},
              ],
      });

      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 45),
            onTimeout: () => throw TimeoutException('OpenAI timeout'),
          );

      if (streamedResponse.statusCode == 401) {
        throw Exception('Invalid OpenAI API key');
      }
      if (streamedResponse.statusCode == 429) {
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 700 * attempt));
          continue;
        }
        throw Exception('OpenAI rate limit reached. Please wait and try again.');
      }
      if (streamedResponse.statusCode < 200 || streamedResponse.statusCode >= 300) {
        throw Exception('OpenAI returned status ${streamedResponse.statusCode}');
      }

      final StringBuffer fullResponse = StringBuffer();
      await for (final rawLine in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;
        if (line == 'data: [DONE]') break;
        if (!line.startsWith('data: ')) continue;
        final data = line.substring('data: '.length);
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final choices = json['choices'];
          if (choices is List && choices.isNotEmpty) {
            final delta = (choices.first as Map<String, dynamic>)['delta'];
            if (delta is Map<String, dynamic>) {
              final content = delta['content'];
              if (content is String && content.isNotEmpty) {
                fullResponse.write(content);
                onChunk(fullResponse.toString());
              }
            }
          }
        } catch (_) {}
      }
      return fullResponse.toString();
      }
    } on SocketException catch (_) {
      throw Exception('Network error: unable to reach OpenAI (check internet/DNS).');
    } on TimeoutException catch (_) {
      throw Exception('OpenAI request timed out. Try again.');
    }
  }
}

// ─── GEMINI CHAT (Cloud) ─────────────────────────────────────────────
class GeminiChatService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const String _defaultModel = 'gemini-1.5-flash';

  static Future<String> generate({
    required String apiKey,
    required String prompt,
    required String systemPrompt,
    String model = _defaultModel,
  }) async {
    final uri = Uri.parse('$_baseUrl/models/$model:generateContent?key=$apiKey');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': '$systemPrompt\n\n$prompt'}
                  ]
                }
              ],
              'generationConfig': {'temperature': 0.4},
            }),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Gemini timeout'),
          );

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Invalid Gemini API key');
      }
      if (response.statusCode == 429) {
        throw Exception('Gemini rate limit reached. Please try again.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Gemini returned status ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw Exception('Unexpected Gemini response');
      final candidates = decoded['candidates'];
      if (candidates is! List || candidates.isEmpty) return '';
      final content = (candidates.first as Map)['content'];
      if (content is! Map) return '';
      final parts = content['parts'];
      if (parts is! List || parts.isEmpty) return '';
      final text = (parts.first as Map)['text'];
      return text is String ? text : '';
    } on SocketException catch (_) {
      throw Exception('Network error: unable to reach Gemini (check internet/DNS).');
    } on TimeoutException catch (_) {
      throw Exception('Gemini request timed out. Try again.');
    }
  }
}

// ─── CLAUDE (Anthropic) CHAT (Cloud) ─────────────────────────────────
class ClaudeChatService {
  static const String _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const String _defaultModel = 'claude-3-5-sonnet-20240620';

  static Future<String> generate({
    required String apiKey,
    required String prompt,
    required String systemPrompt,
    String model = _defaultModel,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode({
              'model': model,
              'max_tokens': 1024,
              'temperature': 0.4,
              'system': systemPrompt,
              'messages': [
                {'role': 'user', 'content': prompt}
              ],
            }),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Claude timeout'),
          );

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Invalid Claude API key');
      }
      if (response.statusCode == 429) {
        throw Exception('Claude rate limit reached. Please try again.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Claude returned status ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw Exception('Unexpected Claude response');
      final content = decoded['content'];
      if (content is! List || content.isEmpty) return '';
      final first = content.first;
      if (first is! Map) return '';
      final text = first['text'];
      return text is String ? text : '';
    } on SocketException catch (_) {
      throw Exception('Network error: unable to reach Claude (check internet/DNS).');
    } on TimeoutException catch (_) {
      throw Exception('Claude request timed out. Try again.');
    }
  }
}

// ─── OPENAI IMAGE GENERATION (Cloud) ─────────────────────────────────
class OpenAiImageService {
  static const String _baseUrl = 'https://api.openai.com/v1';

  static Future<Uint8List> generatePngBytes({
    required String apiKey,
    required String prompt,
    String model = 'gpt-image-1',
    String size = '1024x1024',
  }) async {
    final uri = Uri.parse('$_baseUrl/images/generations');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'prompt': prompt,
            'size': size,
            'response_format': 'b64_json',
          }),
        )
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw TimeoutException('OpenAI image timeout'),
        );

    if (response.statusCode == 401) {
      throw Exception('Invalid OpenAI API key');
    }
    if (response.statusCode == 429) {
      throw Exception('OpenAI rate limit reached. Please wait and try again.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('OpenAI returned status ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw Exception('Unexpected OpenAI response');
    final data = decoded['data'];
    if (data is! List || data.isEmpty) throw Exception('OpenAI returned no image');
    final first = data.first;
    if (first is! Map) throw Exception('Unexpected OpenAI image payload');
    final b64 = first['b64_json'];
    if (b64 is! String || b64.isEmpty) throw Exception('OpenAI image data missing');
    return base64Decode(b64);
  }
}

// ─── OPENAI VISION (Cloud) ───────────────────────────────────────────
class OpenAiVisionService {
  static const String _baseUrl = 'https://api.openai.com/v1';

  static Future<String> describe({
    required String apiKey,
    required String prompt,
    required List<_UserAttachment> images,
    String model = 'gpt-4.1-mini',
  }) async {
    if (images.isEmpty) throw Exception('No images attached');
    final uri = Uri.parse('$_baseUrl/chat/completions');

    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
      ...images.map((img) {
        final mime = img.mimeType.isNotEmpty ? img.mimeType : 'image/png';
        final b64 = base64Encode(img.bytes);
        return {
          'type': 'image_url',
          'image_url': {'url': 'data:$mime;base64,$b64'}
        };
      }),
    ];

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'temperature': 0.4,
            'messages': [
              {
                'role': 'system',
                'content':
                    'You are AURA. Be direct and helpful. If the user asks what is in the image, describe it clearly and answer their question.'
              },
              {'role': 'user', 'content': content},
            ],
          }),
        )
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw TimeoutException('OpenAI vision timeout'),
        );

    if (response.statusCode == 401) {
      throw Exception('Invalid OpenAI API key');
    }
    if (response.statusCode == 429) {
      throw Exception('OpenAI rate limit reached. Please wait and try again.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('OpenAI returned status ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw Exception('Unexpected OpenAI response');
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw Exception('OpenAI returned no choices');
    }
    final msg = (choices.first as Map)['message'];
    if (msg is! Map) throw Exception('Unexpected OpenAI message');
    final contentText = msg['content'];
    if (contentText is String) return contentText;
    throw Exception('Unexpected OpenAI content');
  }
}

// ─── WEB SEARCH (Serper.dev) ─────────────────────────────────────────
class SerperSearchService {
  static const String _endpoint = 'https://google.serper.dev/search';

  static Future<List<Map<String, String>>> search({
    required String apiKey,
    required String query,
    int maxResults = 5,
  }) async {
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-API-KEY': apiKey,
            },
            body: jsonEncode({
              'q': query,
              'num': maxResults,
            }),
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw TimeoutException('Web search timeout'),
          );
    } on SocketException catch (_) {
      throw Exception(
          'Network error: unable to run web search (check internet/DNS).');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Invalid web search API key');
    }
    if (response.statusCode == 429) {
      throw Exception('Web search rate limit reached. Please try again.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Web search returned status ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return const [];
    final organic = decoded['organic'];
    if (organic is! List) return const [];

    final results = <Map<String, String>>[];
    for (final item in organic) {
      if (item is! Map) continue;
      final title = (item['title'] ?? '').toString().trim();
      final link = (item['link'] ?? '').toString().trim();
      final snippet = (item['snippet'] ?? '').toString().trim();
      if (link.isEmpty) continue;
      results.add({
        'title': title.isEmpty ? link : title,
        'link': link,
        'snippet': snippet,
      });
      if (results.length >= maxResults) break;
    }
    return results;
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
    final isSmallScreen = size.shortestSide < 600;

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
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
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
  final bool forceLevelSelect;
  const BootSequence({super.key, this.forceLevelSelect = false});
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

  Future<bool> _tryAutoResume() async {
    final lastLevel = await PinStorage.getLastSelectedLevel();
    if (lastLevel == null) return false;

    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }

    if (!mounted) return false;
    if (user != null) {
      final name = (user.displayName?.trim().isNotEmpty ?? false)
          ? user.displayName!.trim()
          : (user.email?.trim().isNotEmpty ?? false)
              ? user.email!.trim()
              : 'User';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AuraMainHub(selectedLevel: lastLevel, loginMethod: name),
        ),
      );
      return true;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IdentityDisk(selectedLevel: lastLevel),
      ),
    );
    return true;
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
      if (!widget.forceLevelSelect) {
        final resumed = await _tryAutoResume();
        if (resumed) return;
      }
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
    unawaited(PinStorage.setLastSelectedLevel(level));
    setState(() {
      _bootText +=
          "\n> LEVEL SELECTED: ${level.name.toUpperCase()}\n> MOUNTING IDENTITY DISK...";
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.of(context).push(
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
    final isSmallScreen = size.shortestSide < 600;

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
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
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
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  final List<Map<String, dynamic>> _authProviders = [
    {'name': 'Email', 'icon': Icons.email, 'color': Colors.blue},
    {'name': 'Google', 'icon': Icons.g_mobiledata, 'color': Colors.red},
  ];

  @override
  void initState() {
    super.initState();
    unawaited(PinStorage.setLastSelectedLevel(widget.selectedLevel));
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
      } else {
        await PinStorage.setRememberMe(false);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _spinController.dispose();
    _emailController.dispose();
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
        case 'Google':
          await _signInWithGoogle();
          break;
        default:
          _showError('Unsupported auth provider');
          setState(() => _isAuthenticating = false);
          return;
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
    final isSmallScreen = size.shortestSide < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF050A0E),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, left: 10),
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    if (navigator.canPop()) {
                      navigator.pop();
                      return;
                    }
                    navigator.pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const BootSequence(forceLevelSelect: true),
                      ),
                    );
                  },
                  icon: Icon(Icons.arrow_back, color: level.color),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 10),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: level.color,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: level.color.withOpacity(0.35)),
                    ),
                  ),
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    if (navigator.canPop()) {
                      navigator.pop();
                      return;
                    }
                    navigator.pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const BootSequence(forceLevelSelect: true),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Level'),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
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
            if (widget.assessmentType == 'final' && passed)
              const Text(
                "🎓 Certificate unlocked!",
                style: TextStyle(color: Colors.green, fontSize: 12),
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

class _UserAttachment {
  final String name;
  final String mimeType;
  final Uint8List bytes;

  const _UserAttachment({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  bool get isImage => mimeType.startsWith('image/');
}

class _AuraMainHubState extends State<AuraMainHub>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late AnimationController _ringSpinController;
  late AnimationController _revealController;
  late AnimationController _orbitController;
  late AnimationController _searchSpinController;

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _noteTitleController = TextEditingController();
  final TextEditingController _noteContentController = TextEditingController();
  final List<_UserAttachment> _attachments = [];
  final ScrollController _chatScrollController = ScrollController();

  bool _isSearching = false;
  Timer? _searchWatchdog;
  bool _isSpeaking = false;
  int _activeRequestId = 0;
  bool _isCompact = false;
  String _currentAnswer = "";
  int _selectedTheme = 3;
  int? _openPanel;
  String? _selectedCourse;
  Map<String, List<String>> _chatByContext = {'general': <String>[]};
  Map<String, String> _chatSummaryByContext = {};
  String _chatContextKey = 'general';
  List<String> get _chatHistory => _chatByContext[_chatContextKey]!;
  String get _chatSummary => _chatSummaryByContext[_chatContextKey] ?? '';

  List<Map<String, String>> _buildOpenAiStyleMessages({
    required String systemPrompt,
    required String userPrompt,
    int maxTurns = 8,
  }) {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    final entries = _chatHistory;
    final startIndex = entries.length - (maxTurns * 2);
    final slice = entries.sublist(startIndex < 0 ? 0 : startIndex);

    for (final item in slice) {
      final trimmed = item.trim();
      if (trimmed.startsWith('> You:')) {
        messages.add({
          'role': 'user',
          'content': trimmed.replaceFirst('> You:', '').trim(),
        });
      } else if (trimmed.startsWith('Sources:')) {
        messages.add({'role': 'system', 'content': trimmed});
      } else if (trimmed.isNotEmpty && !trimmed.startsWith('>')) {
        messages.add({'role': 'assistant', 'content': trimmed});
      }
    }

    messages.add({'role': 'user', 'content': userPrompt});
    return messages;
  }

  bool _isHelpRequest(String raw) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return false;
    return q == 'help' ||
        q == 'guide' ||
        q == 'how to use' ||
        q == 'how to use aura' ||
        q == 'aura help' ||
        q == 'aura guide' ||
        q == 'menu' ||
        q == 'commands' ||
        q == 'what can you do' ||
        q == 'what can you do?' ||
        q.startsWith('help ') ||
        q.startsWith('guide ') ||
        q.contains('how do i use') ||
        q.contains('how to use this app') ||
        q.contains('what can you do');
  }

  String _localeForLanguageName(String name) {
    switch (name.trim().toLowerCase()) {
      case 'french':
        return 'fr-FR';
      case 'spanish':
        return 'es-ES';
      case 'german':
        return 'de-DE';
      case 'chinese':
        return 'zh-CN';
      default:
        return 'en-US';
    }
  }

  String _normalizedLanguageName(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.contains('french') || s.contains('français') || s.contains('francais')) {
      return 'French';
    }
    if (s.contains('spanish') || s.contains('español') || s.contains('espanol')) {
      return 'Spanish';
    }
    if (s.contains('german') || s.contains('deutsch')) {
      return 'German';
    }
    if (s.contains('chinese') || s.contains('mandarin') || s.contains('中文')) {
      return 'Chinese';
    }
    if (s.contains('english') || s.contains('anglais')) {
      return 'English';
    }
    return _selectedLanguage;
  }

  bool _isLanguageSwitchRequest(String raw) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return false;
    if (RegExp(r'\\b(speak|talk|chat)\\b').hasMatch(q) &&
        (q.contains('english') ||
            q.contains('french') ||
            q.contains('spanish') ||
            q.contains('german') ||
            q.contains('chinese') ||
            q.contains('français') ||
            q.contains('francais') ||
            q.contains('español') ||
            q.contains('espanol') ||
            q.contains('deutsch') ||
            q.contains('中文') ||
            q.contains('mandarin'))) {
      return true;
    }
    if (q.startsWith("let's speak") || q.startsWith('lets speak')) return true;
    return false;
  }

  Future<void> _applySelectedLanguage(String languageName) async {
    final locale = _localeForLanguageName(languageName);
    if (!mounted) return;
    setState(() => _selectedLanguage = languageName);
    await VoiceService.setLocale(locale);
  }

  bool _isAboutAuraRequest(String raw) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return false;
    return q == 'about' ||
        q == 'about aura' ||
        q == 'who are you' ||
        q == 'who are you?' ||
        q == 'what is aura' ||
        q == 'what is aura?' ||
        q == 'what are you' ||
        q == 'what are you?' ||
        q.contains('about yourself') ||
        q.contains('introduce yourself');
  }

  String _aboutAuraText() {
    final course = (_selectedCourse == null || _selectedCourse!.trim().isEmpty)
        ? 'None selected'
        : _selectedCourse!.trim();
    return [
      'I’m AURA — your assistant inside the Aura app.',
      '',
      'I can help you:',
      '- Learn topics at your current level (${_userLevel.name})',
      '- Answer general questions (work, life, study, planning)',
      '- Use app features (levels, courses, voice, web search, exports)',
      '',
      'Current setup:',
      '- Level: ${_userLevel.name}',
      '- Course: $course',
      '- Engine: $_aiEngine',
      '',
      'Tip: say “help” anytime to see the app guide.',
    ].join('\n');
  }

  String _appGuideText() {
    final levelsList = levels.map((l) => l.name).join(', ');
    final course = (_selectedCourse == null || _selectedCourse!.trim().isEmpty)
        ? 'None selected'
        : _selectedCourse!.trim();
    final web = _webSearchEnabled ? 'On' : 'Off';
    final voice = _voiceChatEnabled ? 'Voice chat: On' : 'Voice chat: Off';
    final speak = _speakAnswers ? 'Speak answers: On' : 'Speak answers: Off';

    return [
      'Aura quick guide',
      '',
      'Status',
      '- Level: ${_userLevel.name} (available: $levelsList)',
      '- Course: $course',
      '- Engine: $_aiEngine',
      '- Web search: $web',
      '- $voice, $speak',
      '',
      'Navigation',
      '- Use the back arrow (top-left) to go back.',
      '- Use the `Level` button (top-right on level screens) to change level.',
      '',
      'Chat',
      '- Ask anything (learning, productivity, life questions).',
      '- For best answers: include goal, context, and what you already tried.',
      '- Attach screenshots/files when relevant.',
      '',
      'Voice',
      '- Tap the voice icon to talk hands-free (if enabled).',
      '- Toggle speaker icon to make Aura read answers aloud.',
      '',
      'AI settings',
      '- Tap the tune icon to set engine, API keys, models, mood/style, and web search.',
      '',
      'Tools',
      '- Image generation: type “generate image: …”.',
      '- Reminders/timers: ask “set a timer for 10 minutes” or “remind me at 6pm”.',
      '- Notes/bookmarks: ask Aura to draft content, then save/export from the menu.',
      '',
      'Exports',
      '- Use download icon → export chat to TXT/MD/PDF/JSON.',
    ].join('\n');
  }

  Future<void> _showGuideDialog() async {
    final guide = _appGuideText();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1117),
        title: const Text('Aura guide', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: SelectableText(
            guide,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  bool _ollamaAvailable = false;
  bool _ollamaChecked = false;

  late final LevelInfo _userLevel;
  late Course _currentCourse;
  String _selectedVoice = "female";
  Map<String, CatalogCourse> _catalogByTitle = {};
  List<CatalogCourse> _catalogCourses = const [];
  bool _speakAnswers = false;
  String _aiEngine = 'groq';
  String _groqApiKey = '';
  String _groqModel = 'llama-3.1-8b-instant';
  String _conversationStyle = 'chill'; // 'chill' | 'study'
  String _imageProvider = 'openai'; // only 'openai' for now
  String _openAiApiKey = '';
  String _openAiModel = 'gpt-4.1-mini';
  String _geminiApiKey = '';
  String _geminiModel = 'gemini-1.5-flash';
  String _claudeApiKey = '';
  String _claudeModel = 'claude-3-5-sonnet-20240620';
  bool _isOnline = true;
  bool _webSearchEnabled = false;
  String _serperApiKey = '';
  String _moodMode = 'auto'; // auto | supportive | funny | serious
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _voiceChatEnabled = false;
  bool _isListening = false;
  int _nextAlarmId = 1;
  final Map<int, Timer> _activeAlarms = {};
  DateTime? _lastBackPressAt;

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
    WidgetsBinding.instance.addObserver(this);
    _userLevel = levels.firstWhere((l) => l.level == widget.selectedLevel);
    _currentCourse = createSampleCourse(widget.selectedLevel);

    _loadCatalog();
    _loadSavedCourse();
    VoiceService.init();
    NotificationService.init();

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
          "> Welcome, ${widget.loginMethod}!\n> Level: ${_userLevel.name}\n> Initializing AI...";
    });

    _checkOllama();
    _loadNotes();
    _loadBookmarks();
    _loadVoicePreference();
    _loadAnswerSpeakPreference();
    _loadAiPrefs();
    _loadChatState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Avoid speaking in background and prevent stuck states when app is paused.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_stopAssistant());
    }
  }

  Future<bool> _onBackPressed() async {
    // Close panels first.
    if (_openPanel != null) {
      setState(() => _openPanel = null);
      return false;
    }

    // If assistant is busy, stop it.
    if (_isSpeaking || _isSearching || _voiceChatEnabled) {
      await _stopAssistant();
      return false;
    }

    // Double-tap back to exit (Android).
    if (kIsWeb || Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return true;
    }
    final now = DateTime.now();
    final last = _lastBackPressAt;
    _lastBackPressAt = now;
    if (last == null || now.difference(last) > const Duration(seconds: 2)) {
      _toast('Tap back again to exit');
      return false;
    }
    SystemNavigator.pop();
    return true;
  }

  String _contextKeyForCourse(String? course) {
    if (course == null || course.trim().isEmpty) return 'general';
    return 'course:${_normalizeCourseTitle(course)}';
  }

  Future<void> _loadChatState() async {
    final chats = await PinStorage.loadChatByContext();
    final key = await PinStorage.getChatContextKey();
    final summaries = await PinStorage.loadChatSummaryByContext();
    if (!mounted) return;
    setState(() {
      _chatByContext = chats;
      _chatSummaryByContext = summaries;
      _chatContextKey = chats.containsKey(key) ? key : 'general';
      _chatByContext.putIfAbsent(_chatContextKey, () => <String>[]);
    });
    await _loadChatStateFromCloudIfAvailable();
    _scrollChatToBottom();
  }

  Future<void> _persistChatsLocal() async {
    await PinStorage.saveChatByContext(_chatByContext);
    await PinStorage.saveChatSummaryByContext(_chatSummaryByContext);
    await PinStorage.setChatContextKey(_chatContextKey);
  }

  void _queuePersistChats({bool syncCloud = true}) {
    unawaited(() async {
      try {
        await _persistChatsLocal();
      } catch (_) {}
      if (!syncCloud) return;
      try {
        await _syncCurrentChatToCloud().timeout(const Duration(seconds: 3));
      } catch (_) {}
    }());
  }

  Future<void> _persistChats({bool syncCloud = true}) async {
    await _persistChatsLocal();
    if (!syncCloud) return;
    unawaited(() async {
      try {
        await _syncCurrentChatToCloud().timeout(const Duration(seconds: 3));
      } catch (_) {}
    }());
  }

  Future<void> _syncCurrentChatToCloud() async {
    if (!FirebaseService.isAvailable) return;
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }
    if (user == null) return;

    final key = _chatContextKey;
    final history = List<String>.from(_chatByContext[key] ?? const <String>[]);
    try {
      final doc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chats')
          .doc(key);
      await doc.set(
        {
          'contextKey': key,
          'updatedAt': FieldValue.serverTimestamp(),
          'messages': history,
        },
        SetOptions(merge: true),
      );
    } on SocketException catch (_) {
      // Offline/DNS issues: ignore, UI must not block.
    } on TimeoutException catch (_) {
      // Ignore slow network.
    } catch (_) {}
  }

  Future<void> _loadChatStateFromCloudIfAvailable() async {
    if (!FirebaseService.isAvailable) return;
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }
    if (user == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chats')
          .orderBy('updatedAt', descending: true)
          .limit(25)
          .get();

      if (!mounted) return;
      setState(() {
        for (final doc in snap.docs) {
          final data = doc.data();
          final key = (data['contextKey'] ?? doc.id).toString();
          final msgs = data['messages'];
          if (msgs is List) {
            _chatByContext[key] = msgs.map((e) => e.toString()).toList();
          }
        }
        _chatByContext.putIfAbsent('general', () => <String>[]);
        _chatByContext.putIfAbsent(_chatContextKey, () => <String>[]);
      });
      await PinStorage.saveChatByContext(_chatByContext);
    } catch (_) {}
  }

  Map<String, dynamic> _courseToJson(Course course) {
    return {
      'id': course.id,
      'title': course.title,
      'level': course.level.index,
      'certificateEarned': course.certificateEarned,
      'finalBadge': course.finalBadge.index,
      'finalScore': course.finalScore,
      'worldRank': course.worldRank,
      'finalExamUnlocked': course.finalExamUnlocked,
      'finalExamCompleted': course.finalExamCompleted,
      'finalExamPassed': course.finalExamPassed,
      'finalExamScore': course.finalExamScore,
      'units': course.units
          .map((unit) => {
                'id': unit.id,
                'title': unit.title,
                'formativeCompleted': unit.formativeCompleted,
                'formativeScore': unit.formativeScore,
                'formativePassed': unit.formativePassed,
                'examAvailableDate': unit.examAvailableDate?.toIso8601String(),
                'examCompleted': unit.examCompleted,
                'examScore': unit.examScore,
                'examPassed': unit.examPassed,
                'topics': unit.topics
                    .map((topic) => {
                          'id': topic.id,
                          'title': topic.title,
                          'studyUrl': topic.studyUrl,
                          'completed': topic.completed,
                          'studied': topic.studied,
                          'quizScore': topic.quizScore,
                          'quizPassed': topic.quizPassed,
                        })
                    .toList(),
              })
          .toList(),
    };
  }

  Future<void> _syncCourseProgressToCloud() async {
    if (!FirebaseService.isAvailable) return;
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('courses')
          .doc(_currentCourse.id)
          .set(
        {
          'updatedAt': FieldValue.serverTimestamp(),
          'course': _courseToJson(_currentCourse),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  Future<void> _saveCourseProgress() async {
    await PinStorage.saveCourseProgress(_currentCourse);
    unawaited(_syncCourseProgressToCloud());
  }

  Future<void> _switchChatContext(String key) async {
    if (!mounted) return;
    setState(() {
      _chatContextKey = key;
      _chatByContext.putIfAbsent(key, () => <String>[]);
      _currentAnswer = '';
    });
    await _persistChats(syncCloud: true);
    _scrollChatToBottom();
  }

  Future<void> _newConversation({bool keepContext = true}) async {
    final base = keepContext ? _chatContextKey : 'general';
    final newKey =
        '$base:${DateTime.now().millisecondsSinceEpoch.toString()}';
    await _switchChatContext(newKey);
  }

  void _scrollChatToBottom() {
    if (!_chatScrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _toggleVoiceChat() async {
    if (kIsWeb || Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      _toast('Voice chat (microphone) is supported on Android/iOS only.');
      return;
    }
    // If voice mode is ON and AURA is currently speaking, treat a tap as "interrupt"
    // (stop speaking and resume listening) instead of turning voice mode off.
    if (_voiceChatEnabled && _isSpeaking) {
      await VoiceService.stop();
      if (!mounted) return;
      setState(() => _isSpeaking = false);
      await _startListening();
      return;
    }
    final next = !_voiceChatEnabled;
    setState(() => _voiceChatEnabled = next);
    if (!next) {
      await _stopListening();
      await VoiceService.stop();
      return;
    }
    await _startListening();
  }

  Future<void> _startListening() async {
    if (_isListening) return;
    if (_isSpeaking) return;
    await VoiceService.stop();
    bool available = false;
    try {
      available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
            // Continuous voice mode: restart listening after any stop.
            if (_voiceChatEnabled && !_isSpeaking && !_isSearching) {
              Future.delayed(const Duration(milliseconds: 250), () {
                if (!mounted) return;
                if (_voiceChatEnabled && !_isSpeaking && !_isSearching) {
                  unawaited(_startListening());
                }
              });
            }
          }
        },
        onError: (_) {
          if (!mounted) return;
          setState(() => _isListening = false);
          if (_voiceChatEnabled && !_isSpeaking && !_isSearching) {
            Future.delayed(const Duration(milliseconds: 400), () {
              if (!mounted) return;
              if (_voiceChatEnabled && !_isSpeaking && !_isSearching) {
                unawaited(_startListening());
              }
            });
          }
        },
      );
    } catch (_) {
      available = false;
    }
    if (!available) {
      _toast('Microphone unavailable');
      setState(() => _voiceChatEnabled = false);
      return;
    }
    if (!mounted) return;
    setState(() => _isListening = true);
    await _speech.listen(
      listenMode: stt.ListenMode.confirmation,
      partialResults: true,
      onResult: (result) {
        if (!mounted) return;
        if (_isSearching) return;
        if (_isSpeaking) return;
        final text = result.recognizedWords.trim();
        if (text.isEmpty) return;
        if (result.finalResult) {
          _speech.stop();
          setState(() => _isListening = false);
          _submitQuery(text, fromVoice: true);
        }
      },
    );
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {}
    if (mounted) setState(() => _isListening = false);
  }

  Future<void> _stopAssistant() async {
    _activeRequestId++;
    _searchWatchdog?.cancel();
    try {
      await _stopListening();
    } catch (_) {}
    try {
      await VoiceService.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _isSearching = false;
      _isSpeaking = false;
    });
    try {
      _searchSpinController.stop();
      _searchSpinController.reset();
      _orbitController.repeat();
      _revealController.forward();
    } catch (_) {}
  }

  Future<void> _loadSavedCourse() async {
    Course? saved = await PinStorage.loadCourse(_currentCourse.id);
    if (saved != null) {
      setState(() {
        _currentCourse = saved;
      });
    }
  }

  String _normalizeCourseTitle(String s) {
    // Strip emoji/decoration and normalize for matching.
    final cleaned = s
        .replaceAll(RegExp(r'^[^\w]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    return cleaned;
  }

  Future<void> _loadCatalog() async {
    try {
      final raw = await rootBundle.loadString('assets/data/course_catalog.json');
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final Map<String, CatalogCourse> byTitle = {};
      final List<CatalogCourse> all = [];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        final course = CatalogCourse.fromJson(item);
        byTitle[_normalizeCourseTitle(course.title)] = course;
        all.add(course);
      }

      if (!mounted) return;
      setState(() {
        _catalogByTitle = byTitle;
        _catalogCourses = all;
      });

      // If this level doesn't have a hardcoded sample course, pick a default from the catalog.
      if (_currentCourse.units.isEmpty ||
          _currentCourse.id == 'default' ||
          _currentCourse.title == 'Select a course') {
        final wanted = widget.selectedLevel.name.toLowerCase();
        final candidates =
            all.where((c) => c.level == wanted).toList(growable: false);
        final chosen = candidates.isNotEmpty ? candidates.first : (all.isNotEmpty ? all.first : null);
        if (chosen != null && mounted) {
          setState(() {
            _currentCourse = _courseFromCatalog(widget.selectedLevel, chosen);
            _selectedCourse = chosen.title;
            _chatContextKey = _contextKeyForCourse(_selectedCourse);
            _chatByContext.putIfAbsent(_chatContextKey, () => <String>[]);
          });
          _queuePersistChats();
        }
      }
    } catch (_) {}
  }

  Course _courseFromCatalog(SkillLevel level, CatalogCourse catalog) {
    final units = <Unit>[];

    for (int unitIndex = 0; unitIndex < catalog.unitTitles.length; unitIndex++) {
      final unitTitle = catalog.unitTitles[unitIndex];
      final topicsRaw = catalog.unitTopics[unitTitle] ?? const <String>[];
      final topics = <Topic>[];

      for (int topicIndex = 0; topicIndex < topicsRaw.length; topicIndex++) {
        final topicTitle = topicsRaw[topicIndex];
        topics.add(
          Topic(
            id: '${catalog.id}_u${unitIndex + 1}_t${topicIndex + 1}',
            title: topicTitle,
            studyUrl: _topicStudyUrl(course: catalog, topicTitle: topicTitle),
          ),
        );
      }

      units.add(
        Unit(
          id: '${catalog.id}_unit_${unitIndex + 1}',
          title: unitTitle,
          topics: topics,
        ),
      );
    }

    return Course(
      id: catalog.id,
      title: catalog.title,
      level: level,
      units: units,
    );
  }

  String? _topicStudyUrl({required CatalogCourse course, required String topicTitle}) {
    // 1) Prefer course provider URL if it looks like a specific topic page (rare).
    // 2) Otherwise use our W3Schools topic mapping + fallback search.
    final direct = _w3schoolsTopicUrl(courseTitle: course.title, topicTitle: topicTitle);
    if (direct != null) return direct;
    final courseBase = _studyUrlForCourse(course.title);
    if (courseBase != null) return courseBase;
    return _w3schoolsSearchUrl('${course.title} $topicTitle');
  }

  Future<void> _loadVoicePreference() async {
    _selectedVoice = await PinStorage.getVoicePreference();
    await VoiceService.setVoice(_selectedVoice);
    await VoiceService.setLocale(_localeForLanguageName(_selectedLanguage));
  }

  Future<void> _loadAnswerSpeakPreference() async {
    final enabled = await PinStorage.getSpeakAnswers();
    if (!mounted) return;
    setState(() => _speakAnswers = enabled);
  }

  Future<void> _loadAiPrefs() async {
    final engine = await PinStorage.getAiEngine();
    final key = await PinStorage.getGroqApiKey();
    final groqModel = await PinStorage.getGroqModel();
    final style = await PinStorage.getConversationStyle();
    final imageProvider = await PinStorage.getImageProvider();
    final openAiKey = await PinStorage.getOpenAiApiKey();
    final openAiModel = await PinStorage.getOpenAiModel();
    final geminiKey = await PinStorage.getGeminiApiKey();
    final geminiModel = await PinStorage.getGeminiModel();
    final claudeKey = await PinStorage.getClaudeApiKey();
    final claudeModel = await PinStorage.getClaudeModel();
    final webEnabled = await PinStorage.getWebSearchEnabled();
    final serperKey = await PinStorage.getSerperApiKey();
    final moodMode = await PinStorage.getMoodMode();
    if (!mounted) return;
    setState(() {
      _aiEngine = engine ?? 'groq';
      _groqApiKey = key ?? '';
      if (groqModel != null && groqModel.trim().isNotEmpty) {
        _groqModel = groqModel.trim();
      }
      _conversationStyle = style ?? 'chill';
      _imageProvider = imageProvider ?? 'openai';
      _openAiApiKey = openAiKey ?? '';
      if (openAiModel != null && openAiModel.trim().isNotEmpty) {
        _openAiModel = openAiModel.trim();
      }
      _geminiApiKey = geminiKey ?? '';
      if (geminiModel != null && geminiModel.trim().isNotEmpty) {
        _geminiModel = geminiModel.trim();
      }
      _claudeApiKey = claudeKey ?? '';
      if (claudeModel != null && claudeModel.trim().isNotEmpty) {
        _claudeModel = claudeModel.trim();
      }
      _webSearchEnabled = webEnabled;
      _serperApiKey = serperKey ?? '';
      _moodMode = moodMode ?? 'auto';
    });
    await _loadAiPrefsFromCloudIfAvailable();
  }

  Future<void> _syncAiPrefsToCloud() async {
    if (!FirebaseService.isAvailable) return;
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'updatedAt': FieldValue.serverTimestamp(),
          'prefs': {
            'aiEngine': _aiEngine,
            'conversationStyle': _conversationStyle,
            'moodMode': _moodMode,
            'webSearchEnabled': _webSearchEnabled,
            'imageProvider': _imageProvider,
            'models': {
              'groq': _groqModel,
              'openai': _openAiModel,
              'gemini': _geminiModel,
              'claude': _claudeModel,
            },
          },
          // ⚠️ Plain-text sync (user requested). Consider encrypting instead.
          'apiKeys': {
            'groq': _groqApiKey,
            'openai': _openAiApiKey,
            'gemini': _geminiApiKey,
            'claude': _claudeApiKey,
            'serper': _serperApiKey,
          },
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  Future<void> _loadAiPrefsFromCloudIfAvailable() async {
    if (!FirebaseService.isAvailable) return;
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data == null) return;

      final prefs = data['prefs'];
      final apiKeys = data['apiKeys'];
      if (!mounted) return;
      setState(() {
        if (prefs is Map) {
          _aiEngine = (prefs['aiEngine'] ?? _aiEngine).toString();
          _conversationStyle =
              (prefs['conversationStyle'] ?? _conversationStyle).toString();
          _moodMode = (prefs['moodMode'] ?? _moodMode).toString();
          _webSearchEnabled = (prefs['webSearchEnabled'] ?? _webSearchEnabled) ==
              true;
          _imageProvider =
              (prefs['imageProvider'] ?? _imageProvider).toString();
          final models = prefs['models'];
          if (models is Map) {
            final groqModel = (models['groq'] ?? '').toString().trim();
            final openAiModel = (models['openai'] ?? '').toString().trim();
            final geminiModel = (models['gemini'] ?? '').toString().trim();
            final claudeModel = (models['claude'] ?? '').toString().trim();
            if (groqModel.isNotEmpty) _groqModel = groqModel;
            if (openAiModel.isNotEmpty) _openAiModel = openAiModel;
            if (geminiModel.isNotEmpty) _geminiModel = geminiModel;
            if (claudeModel.isNotEmpty) _claudeModel = claudeModel;
          }
        }
        if (apiKeys is Map) {
          _groqApiKey = (apiKeys['groq'] ?? _groqApiKey).toString();
          _openAiApiKey = (apiKeys['openai'] ?? _openAiApiKey).toString();
          _geminiApiKey = (apiKeys['gemini'] ?? _geminiApiKey).toString();
          _claudeApiKey = (apiKeys['claude'] ?? _claudeApiKey).toString();
          _serperApiKey = (apiKeys['serper'] ?? _serperApiKey).toString();
        }
      });

      await PinStorage.setAiEngine(_aiEngine);
      await PinStorage.setConversationStyle(_conversationStyle);
      await PinStorage.setMoodMode(_moodMode);
      await PinStorage.setWebSearchEnabled(_webSearchEnabled);
      await PinStorage.setImageProvider(_imageProvider);
      await PinStorage.setGroqApiKey(_groqApiKey);
      await PinStorage.setOpenAiApiKey(_openAiApiKey);
      await PinStorage.setGeminiApiKey(_geminiApiKey);
      await PinStorage.setClaudeApiKey(_claudeApiKey);
      await PinStorage.setSerperApiKey(_serperApiKey);
      await PinStorage.setGroqModel(_groqModel);
      await PinStorage.setOpenAiModel(_openAiModel);
      await PinStorage.setGeminiModel(_geminiModel);
      await PinStorage.setClaudeModel(_claudeModel);
    } catch (_) {}
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
    if (!mounted) return;
    setState(() {
      _ollamaAvailable = false;
      _ollamaChecked = true;
      _currentAnswer =
          "Welcome, ${widget.loginMethod}! Level: ${_userLevel.name}. Ask me anything.";
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchWatchdog?.cancel();
    _pulseController.dispose();
    _ringSpinController.dispose();
    _revealController.dispose();
    _orbitController.dispose();
    _searchSpinController.dispose();
    _textController.dispose();
    _noteTitleController.dispose();
    _noteContentController.dispose();
    for (final t in _activeAlarms.values) {
      t.cancel();
    }
    _chatScrollController.dispose();
    unawaited(VoiceService.stop());
    super.dispose();
  }

  bool _handleTimeAndTimers(String rawQuery) {
    final q = rawQuery.trim();
    if (q.isEmpty) return false;

    final lower = q.toLowerCase();

    if (TimeTools.isTimeQuery(lower)) {
      final answer = 'Local time: ${TimeTools.formatNow()}';
      setState(() {
        _currentAnswer = answer;
        _chatHistory.add(answer);
      });
      _scrollChatToBottom();
      return true;
    }

    if (lower.startsWith('cancel timer') ||
        lower.startsWith('cancel reminder') ||
        lower.startsWith('stop timer') ||
        lower.startsWith('stop reminder')) {
      for (final t in _activeAlarms.values) {
        t.cancel();
      }
      _activeAlarms.clear();
      setState(() {
        _currentAnswer = '✅ Canceled all timers/reminders.';
        _chatHistory.add(_currentAnswer);
      });
      _scrollChatToBottom();
      return true;
    }

    if (TimeTools.looksLikeTimer(lower)) {
      final duration = TimeTools.parseDuration(lower);
      if (duration == null) return false;

      final id = _nextAlarmId++;
      final endsAt = DateTime.now().add(duration).toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      final endStr =
          '${endsAt.year}-${two(endsAt.month)}-${two(endsAt.day)} ${two(endsAt.hour)}:${two(endsAt.minute)}:${two(endsAt.second)}';

      final label = lower.contains('remind')
          ? 'Reminder'
          : (lower.contains('timer') ? 'Timer' : 'Countdown');

      final human = duration.inSeconds < 60
          ? '${duration.inSeconds} seconds'
          : duration.inMinutes < 60
              ? '${duration.inMinutes} minutes'
              : '${duration.inHours} hours';
      setState(() {
        _currentAnswer = '✅ $label set for $human (ends at $endStr).';
        _chatHistory.add(_currentAnswer);
      });
      _scrollChatToBottom();

      _activeAlarms[id]?.cancel();
      _activeAlarms[id] = Timer(duration, () async {
        if (!mounted) return;
        final doneMsg = '⏰ $label done (id: $id).';
        setState(() {
          _currentAnswer = doneMsg;
          _chatHistory.add(doneMsg);
        });
        _scrollChatToBottom();
        await NotificationService.show(
          id: id,
          title: 'AURA $label',
          body: 'Time is up (id: $id)',
        );
      });

      return true;
    }

    return false;
  }

  // ─── VOICE ASSISTANT FEATURE ────────────────────────────────────
  Future<void> _handleVoiceAssistant() async {
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
                if (mounted) {
                  setState(() {
                    _currentAnswer =
                        "Hello! I'm AURA (female). How can I help you today?";
                    _chatHistory.add(_currentAnswer);
                  });
                  _scrollChatToBottom();
                }
                await VoiceService.speak(
                    "Hello! I'm AURA. How can I help you today?");

                String? voiceInput = await VoiceService.listen();
                if (voiceInput != null) {
                  await _submitQuery(voiceInput, fromVoice: true);
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
                if (mounted) {
                  setState(() {
                    _currentAnswer =
                        "Hello! I'm AURA (male). How can I help you today?";
                    _chatHistory.add(_currentAnswer);
                  });
                  _scrollChatToBottom();
                }
                await VoiceService.speak(
                    "Hello! I'm AURA. How can I help you today?");

                String? voiceInput = await VoiceService.listen();
                if (voiceInput != null) {
                  await _submitQuery(voiceInput, fromVoice: true);
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
    unawaited(() async {
      final questions = await _quizQuestionsForTopic(topic: topic, unit: unit);
      if (!mounted) return;
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

            await _saveCourseProgress();
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
    }());
  }

  Future<List<Map<String, dynamic>>> _quizQuestionsForTopic({
    required Topic topic,
    required Unit unit,
  }) async {
    final url = topic.studyUrl?.trim() ?? '';
    if (url.startsWith('http')) {
      try {
        final text = await _fetchStudyText(url);
        final webQuestions = await _generateQuizFromText(
          assessmentType: 'quiz',
          title: '${_currentCourse.title} • ${topic.title}',
          sourceUrl: url,
          studyText: text,
          count: 5,
        );
        if (webQuestions.isNotEmpty) return webQuestions;
      } catch (_) {
        // Fall back to local question bank.
      }
    }
    return QuizService.generateQuiz(
      courseTitle: _currentCourse.title,
      topicTitle: topic.title,
      assessmentType: "quiz",
      count: 5,
    );
  }

  Future<String> _fetchStudyText(String url) async {
    final uri = Uri.parse(url);
    final res = await http
        .get(uri, headers: {'User-Agent': 'AuraAI/1.0'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to fetch study page (${res.statusCode})');
    }
    final html = res.body;
    final noScripts = html
        .replaceAll(
            RegExp(r'<script[^>]*>[\\s\\S]*?<\\/script>',
                caseSensitive: false),
            ' ')
        .replaceAll(
            RegExp(r'<style[^>]*>[\\s\\S]*?<\\/style>',
                caseSensitive: false),
            ' ');
    final text = noScripts
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
    if (text.isEmpty) throw Exception('Study page had no readable text');
    return text.length > 6000 ? text.substring(0, 6000) : text;
  }

  Future<List<Map<String, dynamic>>> _generateQuizFromText({
    required String assessmentType,
    required String title,
    required String sourceUrl,
    required String studyText,
    required int count,
  }) async {
    final system = [
      "You generate multiple-choice quizzes from study text.",
      "Return ONLY valid JSON (no markdown).",
      "Schema: [{\"question\":string,\"options\":[string,string,string,string],\"correct\":0-3}]",
      "Rules: options must be distinct; correct is index into options; base questions strictly on the study text.",
    ].join('\\n');

    final user = [
      "AssessmentType: $assessmentType",
      "Title: $title",
      "Source: $sourceUrl",
      "NumberOfQuestions: $count",
      "",
      "Study text:",
      studyText,
    ].join('\\n');

    final raw =
        await _generateWithSelectedEngine(systemPrompt: system, prompt: user);
    final jsonText = _extractJsonArray(raw);
    final decoded = jsonDecode(jsonText);
    if (decoded is! List) return [];

    final out = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final q = (item['question'] ?? '').toString().trim();
      final opts = item['options'];
      final correct = item['correct'];
      if (q.isEmpty) continue;
      if (opts is! List || opts.length != 4) continue;
      final options = opts.map((e) => e.toString()).toList();
      final c = correct is int ? correct : int.tryParse(correct.toString());
      if (c == null || c < 0 || c > 3) continue;
      out.add({'question': q, 'options': options, 'correct': c});
      if (out.length >= count) break;
    }
    return out;
  }

  String _extractJsonArray(String raw) {
    final s = raw.trim();
    final start = s.indexOf('[');
    final end = s.lastIndexOf(']');
    if (start >= 0 && end > start) return s.substring(start, end + 1);
    return s;
  }

  Future<String> _generateWithSelectedEngine({
    required String systemPrompt,
    required String prompt,
  }) async {
    if (_aiEngine == 'groq') {
      final key = _groqApiKey.trim();
      if (key.isEmpty) throw Exception('Missing Groq API key');
      return GroqService.generate(
        apiKey: key,
        prompt: prompt,
        systemPrompt: systemPrompt,
        model: _groqModel,
        onChunk: (_) {},
      );
    }
    if (_aiEngine == 'openai') {
      final key = _openAiApiKey.trim();
      if (key.isEmpty) throw Exception('Missing OpenAI API key');
      return OpenAiChatService.generate(
        apiKey: key,
        prompt: prompt,
        systemPrompt: systemPrompt,
        model: _openAiModel,
        onChunk: (_) {},
      );
    }
    if (_aiEngine == 'gemini') {
      final key = _geminiApiKey.trim();
      if (key.isEmpty) throw Exception('Missing Gemini API key');
      return GeminiChatService.generate(
        apiKey: key,
        prompt: prompt,
        systemPrompt: systemPrompt,
        model: _geminiModel,
      );
    }
    if (_aiEngine == 'claude') {
      final key = _claudeApiKey.trim();
      if (key.isEmpty) throw Exception('Missing Claude API key');
      return ClaudeChatService.generate(
        apiKey: key,
        prompt: prompt,
        systemPrompt: systemPrompt,
        model: _claudeModel,
      );
    }
    throw Exception('Unknown engine');
  }

  String _w3schoolsSearchUrl(String query) {
    final q = query
        .replaceAll(RegExp(r'[^\w\s\-\+\.]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (q.isEmpty) return 'https://www.w3schools.com/';
    // W3Schools search endpoint (the old `/search/search.asp` 404s).
    return Uri.https('www.w3schools.com', '/search/search.php', {'q': q})
        .toString();
  }

  String? _w3schoolsTopicUrl({required String courseTitle, required String topicTitle}) {
    final course = _normalizeCourseTitle(courseTitle);
    final topic = _normalizeCourseTitle(topicTitle);

    // Python
    if (course.contains('python')) {
      if (topic.contains('variable')) {
        return 'https://www.w3schools.com/python/python_variables.asp';
      }
      if (topic.contains('data type') || topic.contains('datatype')) {
        return 'https://www.w3schools.com/python/python_datatypes.asp';
      }
      if (topic.contains('operator')) {
        return 'https://www.w3schools.com/python/python_operators.asp';
      }
      if (topic.contains('if') || topic.contains('condition')) {
        return 'https://www.w3schools.com/python/python_conditions.asp';
      }
      if (topic.contains('loop') || topic.contains('for') || topic.contains('while')) {
        return 'https://www.w3schools.com/python/python_loops.asp';
      }
      if (topic.contains('function')) {
        return 'https://www.w3schools.com/python/python_functions.asp';
      }
      if (topic.contains('list')) {
        return 'https://www.w3schools.com/python/python_lists.asp';
      }
      if (topic.contains('tuple')) {
        return 'https://www.w3schools.com/python/python_tuples.asp';
      }
      if (topic.contains('set')) {
        return 'https://www.w3schools.com/python/python_sets.asp';
      }
      if (topic.contains('dictionary') || topic.contains('dict')) {
        return 'https://www.w3schools.com/python/python_dictionaries.asp';
      }
      if (topic.contains('class') || topic.contains('object') || topic.contains('oop')) {
        return 'https://www.w3schools.com/python/python_classes.asp';
      }
      if (topic.contains('module') || topic.contains('package')) {
        return 'https://www.w3schools.com/python/python_modules.asp';
      }
      if (topic.contains('file') || topic.contains('io') || topic.contains('read') || topic.contains('write')) {
        return 'https://www.w3schools.com/python/python_file_handling.asp';
      }
      return 'https://www.w3schools.com/python/';
    }

    // JavaScript
    if (course.contains('javascript') || course.contains('js')) {
      if (topic.contains('variable')) return 'https://www.w3schools.com/js/js_variables.asp';
      if (topic.contains('data type') || topic.contains('datatype')) {
        return 'https://www.w3schools.com/js/js_datatypes.asp';
      }
      if (topic.contains('function')) return 'https://www.w3schools.com/js/js_functions.asp';
      if (topic.contains('loop') || topic.contains('for') || topic.contains('while')) {
        return 'https://www.w3schools.com/js/js_loop_for.asp';
      }
      if (topic.contains('if') || topic.contains('condition')) {
        return 'https://www.w3schools.com/js/js_if_else.asp';
      }
      return 'https://www.w3schools.com/js/';
    }

    // HTML / CSS
    if (course.contains('html')) return 'https://www.w3schools.com/html/';
    if (course.contains('css')) return 'https://www.w3schools.com/css/';

    // Databases / SQL
    if (course.contains('sql') || course.contains('database')) {
      return 'https://www.w3schools.com/sql/';
    }

    return null;
  }

  Future<void> _openTopicStudy(Topic topic) async {
    String url = (topic.studyUrl?.trim().isNotEmpty == true)
        ? topic.studyUrl!.trim()
        : '';

    // If enabled, try to find a "best" study URL per topic using web search.
    if (url.isEmpty && _webSearchEnabled && _serperApiKey.trim().isNotEmpty) {
      try {
        final results = await SerperSearchService.search(
          apiKey: _serperApiKey.trim(),
          query: '${_currentCourse.title} ${topic.title} tutorial',
          maxResults: 3,
        );
        final first = results.isNotEmpty ? (results.first['link'] ?? '') : '';
        if (first.trim().isNotEmpty) {
          url = first.trim();
        }
      } catch (_) {
        // Ignore and fall back to built-in mappings.
      }
    }

    url = url.isNotEmpty
        ? url
        : (_w3schoolsTopicUrl(
              courseTitle: _currentCourse.title,
              topicTitle: topic.title,
            ) ??
            _studyUrlForCourse(_currentCourse.title) ??
            _w3schoolsSearchUrl("${_currentCourse.title} ${topic.title}"));

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InAppBrowserPage(title: topic.title, initialUrl: url),
      ),
    );

    if (!mounted) return;
    if (topic.studied) return;

    setState(() {
      topic.studied = true;
      // Persist resolved URL so next time it opens directly.
      if (topic.studyUrl == null || topic.studyUrl!.trim().isEmpty) {
        topic.studyUrl = url;
      }
    });
    await _saveCourseProgress();
  }

  void _startFormative(Unit unit) {
    var questions = QuizService.generateQuiz(
      courseTitle: _currentCourse.title,
      topicTitle: unit.title,
      assessmentType: "formative",
    );

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

          await _saveCourseProgress();

          if (passed) {
            VoiceService.speak(
                "Excellent! You passed the formative assessment. Your exam will be available in 3 days.");
          }
        },
      ),
    );
  }

  void _startExam(Unit unit) {
    var questions = QuizService.generateQuiz(
      courseTitle: _currentCourse.title,
      topicTitle: unit.title,
      assessmentType: "exam",
    );

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
          if (allUnitsPassed && !_currentCourse.finalExamUnlocked) {
            setState(() => _currentCourse.finalExamUnlocked = true);
            VoiceService.speak(
                "Great job! You passed all unit exams. Your FINAL EXAM is now unlocked.");
          }

          await _saveCourseProgress();
        },
      ),
    );
  }

  void _startFinalExam() {
    final questions = QuizService.generateQuiz(
      courseTitle: _currentCourse.title,
      topicTitle: 'Final Exam',
      assessmentType: "final",
      count: 12,
    );

    showDialog(
      context: context,
      builder: (_) => QuizDialog(
        topic: _currentCourse.title,
        assessmentType: "final",
        questions: questions,
        onComplete: (score, passed, badge) async {
          setState(() {
            _currentCourse.finalExamScore = score;
            _currentCourse.finalExamPassed = passed;
            _currentCourse.finalExamCompleted = passed;
          });

          if (passed) {
            final avgUnit = _currentCourse.units.isEmpty
                ? 0.0
                : _currentCourse.units
                        .map((u) => u.examScore)
                        .reduce((a, b) => a + b) /
                    _currentCourse.units.length;
            final totalScore = (avgUnit * 0.7) + (score * 0.3);
            final finalBadge = getBadgeFromScore(totalScore);
            setState(() {
              _currentCourse.certificateEarned = true;
              _currentCourse.finalBadge = finalBadge.level;
              _currentCourse.finalScore = totalScore;
            });

            if (totalScore == 100) {
              await PinStorage.updateWorldRank(_currentCourse.id, totalScore);
              final rank = await PinStorage.getWorldRank(_currentCourse.id);
              setState(() => _currentCourse.worldRank = rank);
              VoiceService.speak(
                  "INCREDIBLE! You got 100% overall and achieved SUPER GOLD! You're now ranked #1 in the world!");
            } else {
              VoiceService.speak(
                  "Congratulations! You passed the final exam and earned a ${finalBadge.name} certificate!");
            }
          } else {
            VoiceService.speak(
                "You didn't pass the final exam yet. Review the course and try again.");
          }

          await _saveCourseProgress();
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CertificateWidget(
              courseName: _currentCourse.title,
              userName: userName,
              badge: finalBadge,
              date: DateTime.now(),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:
                      const Text('Close', style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    final path = await _exportCertificatePdf(
                      courseName: _currentCourse.title,
                      userName: userName,
                      badge: finalBadge,
                      date: DateTime.now(),
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _toast('Saved: $path');
                  },
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download PDF'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _exportCertificatePdf({
    required String courseName,
    required String userName,
    required Badge badge,
    required DateTime date,
  }) async {
    final doc = pw.Document();
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(28),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 3, color: PdfColor.fromInt(0xFF00FF88)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'CERTIFICATE OF ACHIEVEMENT',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 18),
                pw.Text('This is to certify that', style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 10),
                pw.Text(
                  userName,
                  style: pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text('has successfully completed', style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 8),
                pw.Text(
                  courseName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 18),
                pw.Text('Award: ${badge.name}', style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 6),
                pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          );
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final safeCourse = courseName
        .replaceAll(RegExp(r'[^A-Za-z0-9_\\- ]'), '')
        .trim()
        .replaceAll(' ', '_');
    final file =
        File('${dir.path}/aura_certificate_${safeCourse}_$dateStr.pdf');
    await file.writeAsBytes(await doc.save());
    return file.path;
  }

  Widget _buildLearningPanel() {
    final unitTitleColor = _isLight ? _textPrimary : Colors.white;
    final topicTextColor = _isLight ? _textSub : Colors.white70;
    final mutedCircle = _isLight ? Colors.black.withOpacity(0.08) : Colors.white.withOpacity(0.1);
    final mutedBorder = _isLight ? Colors.black26 : Colors.white24;

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
                          color: unitTitleColor,
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
                      onTap: () async => _openTopicStudy(topic),
                      onLongPress: () {
                        if (!topic.studied) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text("Study this topic first, then take the quiz."),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        _startQuiz(topic, unit);
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
                                  : mutedCircle,
                              border: Border.all(
                                color: topic.quizPassed
                                    ? Colors.green
                                    : mutedBorder,
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
                                    : topicTextColor,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          if (topic.studied && !topic.quizPassed)
                            Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.bookmark,
                                  color: topicTextColor, size: 12),
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
          if (!_currentCourse.certificateEarned) ...[
            const SizedBox(height: 6),
            Divider(color: _isLight ? Colors.black12 : Colors.white24),
            const SizedBox(height: 8),
            Builder(builder: (_) {
              final allUnitsPassed =
                  _currentCourse.units.isNotEmpty &&
                      _currentCourse.units.every((u) => u.examPassed);
              final unlocked = _currentCourse.finalExamUnlocked || allUnitsPassed;
              final lastScore = _currentCourse.finalExamScore;

              return GestureDetector(
                onTap: unlocked ? _startFinalExam : null,
                child: Opacity(
                  opacity: unlocked ? 1.0 : 0.55,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          unlocked
                              ? _userLevel.color.withOpacity(0.25)
                              : Colors.white.withOpacity(0.06),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: unlocked ? _userLevel.color : Colors.white24,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          unlocked ? Icons.verified : Icons.lock_outline,
                          color: unlocked ? _userLevel.color : Colors.white54,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                unlocked ? "Final Exam" : "Final Exam (Locked)",
                                style: TextStyle(
                                  color: unlocked ? _userLevel.color : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                unlocked
                                    ? (lastScore > 0
                                        ? "Tap to start • Last score ${lastScore.toStringAsFixed(0)}%"
                                        : "Tap to start your course final exam")
                                    : "Pass all unit exams to unlock",
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (unlocked)
                          Icon(Icons.arrow_forward, color: _userLevel.color, size: 16),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
          if (_currentCourse.certificateEarned) ...[
            Divider(color: _isLight ? Colors.black12 : Colors.white24),
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
    final normalized = _normalizeCourseTitle(course);
    final catalog = _catalogByTitle[normalized];

    setState(() {
      _selectedCourse = course;
      _currentAnswer =
          "> Course selected: $course\n> Ask me anything about this course!";
      if (catalog != null) {
        _currentCourse = _courseFromCatalog(widget.selectedLevel, catalog);
      } else {
        _currentCourse = createSampleCourse(widget.selectedLevel);
      }
    });

    _switchChatContext(_contextKeyForCourse(course));
    _loadSavedCourse();
    PinStorage.completeCourse(course);
    _revealController.reverse();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _revealController.forward();
    });
  }

  void _selectCatalogCourse(CatalogCourse catalog) {
    final title = catalog.title;
    setState(() {
      _selectedCourse = title;
      _currentAnswer =
          "> Course selected: $title\n> Ask me anything about this course!";
      _currentCourse = _courseFromCatalog(widget.selectedLevel, catalog);
    });

    _switchChatContext(_contextKeyForCourse(title));
    _loadSavedCourse();
    PinStorage.completeCourse(title);
    _revealController.reverse();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _revealController.forward();
    });
  }

  void _clearCurrentChat() async {
    if (!mounted) return;
    setState(() {
      _chatByContext[_chatContextKey] = <String>[];
      _currentAnswer = '';
    });
    await _persistChats();
    _scrollChatToBottom();
  }

  String? _studyUrlForCourse(String course) {
    final normalized = course.toLowerCase();

    if (normalized.contains('html')) return 'https://www.w3schools.com/html/';
    if (normalized.contains('css')) return 'https://www.w3schools.com/css/';
    if (normalized.contains('javascript')) {
      return 'https://www.w3schools.com/js/';
    }
    if (normalized.contains('python')) return 'https://www.w3schools.com/python/';
    if (normalized.contains('git')) return 'https://www.w3schools.com/git/';
    if (normalized.contains('database') || normalized.contains('sql')) {
      return 'https://www.w3schools.com/sql/';
    }
    if (normalized.contains('rest') || normalized.contains('api')) {
      return 'https://www.w3schools.com/whatis/whatis_api.asp';
    }

    return null;
  }

  void _openStudyForCourse(String course) {
    final url = _studyUrlForCourse(course);
    if (url == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InAppBrowserPage(title: course, initialUrl: url),
      ),
    );
  }

  bool _isIctQuery(String query) {
    final q = query.toLowerCase();

    // Strong allow-list signals for ICT/programming.
    const keywords = [
      'code',
      'coding',
      'program',
      'programming',
      'developer',
      'software',
      'app',
      'flutter',
      'dart',
      'android',
      'ios',
      'web',
      'website',
      'html',
      'css',
      'javascript',
      'typescript',
      'react',
      'node',
      'python',
      'java',
      'kotlin',
      'c++',
      'c#',
      'sql',
      'database',
      'api',
      'rest',
      'http',
      'json',
      'git',
      'github',
      'docker',
      'linux',
      'windows',
      'macos',
      'cloud',
      'aws',
      'gcp',
      'azure',
      'security',
      'cyber',
      'network',
      'ai',
      'ml',
      'machine learning',
      'bug',
      'error',
      'debug',
      'algorithm',
      'data structure',
      'firebase',
    ];

    for (final k in keywords) {
      if (q.contains(k)) return true;
    }

    // Also allow code-like questions even without keywords.
    final looksLikeCode = RegExp(r'[{}();<>]|==|!=|:=|=>|def |class |import ')
        .hasMatch(query);
    return looksLikeCode;
  }

  bool _isGreeting(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;
    const greetings = {
      'hi',
      'hy',
      'hello',
      'hey',
      'good morning',
      'good afternoon',
      'good evening',
      'how are you',
      'how r you',
      "what's up",
      'thanks',
      'thank you',
    };
    if (greetings.contains(q)) return true;
    if (q.length <= 20 &&
        (q.startsWith('hi ') ||
            q.startsWith('hey ') ||
            q.startsWith('hello ') ||
            q.startsWith('thanks') ||
            q.startsWith('thank you'))) {
      return true;
    }
    return false;
  }

  bool _looksCasualChat(String query) {
    final q = query.toLowerCase();
    if (q.contains('bro') ||
        q.contains('chill') ||
        q.contains('friend') ||
        q.contains('feel') ||
        q.contains('how are you') ||
        q.contains("what's up") ||
        q.contains('lol') ||
        q.contains('lmao') ||
        q.contains('hhh') ||
        q.contains('😂') ||
        q.contains('🤣')) {
      return true;
    }
    // If it has '=' but no other code markers, it's often just typing noise.
    final hasEquals = q.contains('=');
    final hasCodeMarkers =
        RegExp(r'[{}();<>]|==|!=|:=|=>|#include|import |class |def |SELECT ',
                caseSensitive: false)
            .hasMatch(query);
    if (hasEquals && !hasCodeMarkers) return true;
    return false;
  }

  String _detectMood(String query) {
    final q = query.toLowerCase();
    final sad = [
      'sad',
      'down',
      'depressed',
      'lonely',
      'cry',
      'tired',
      'hurt',
      'broken',
      'hopeless',
      'stress',
      'stressed',
      'anxious',
      'anxiety',
      'panic',
      'overwhelmed',
    ];
    final angry = [
      'angry',
      'mad',
      'furious',
      'annoyed',
      'hate',
      'pissed',
      'frustrated',
    ];
    final happy = [
      'happy',
      'excited',
      'great',
      'awesome',
      'good news',
      'love',
      'lol',
      'lmao',
      'haha',
    ];
    final wantsJoke = RegExp(r'\\b(joke|funny|make me laugh|cheer me up)\\b')
        .hasMatch(q);

    bool hasAny(List<String> words) => words.any((w) => q.contains(w));

    if (wantsJoke) return 'wants_joke';
    if (hasAny(angry) || q.contains('!!!')) return 'angry';
    if (hasAny(sad) || q.contains(':( ' ) || q.contains('😢') || q.contains('😭'))
      return 'sad';
    if (hasAny(happy) || q.contains('😊') || q.contains('😁') || q.contains('🎉'))
      return 'happy';
    return 'neutral';
  }

  String _moodInstructionFor(String query) {
    final detected = _detectMood(query);
    final mode = _moodMode;

    final wantsFun = mode == 'funny' || detected == 'wants_joke';
    final wantsSupport = mode == 'supportive' ||
        (mode == 'auto' && (detected == 'sad' || detected == 'angry'));
    final wantsSerious = mode == 'serious';

    if (wantsSerious) {
      return 'Tone: Be concise, calm, and serious. No jokes unless asked.';
    }
    if (wantsSupport && wantsFun) {
      return 'Tone: Be supportive and comforting first, then add a light joke if appropriate.';
    }
    if (wantsSupport) {
      return 'Tone: Be supportive and comforting. Acknowledge feelings briefly, then help.';
    }
    if (wantsFun) {
      return 'Tone: Be friendly and a bit playful. You may include a short joke if relevant.';
    }
    if (mode == 'auto' && detected == 'happy') {
      return 'Tone: Match the user’s positive vibe. Keep it friendly.';
    }
    return 'Tone: Be natural and friendly.';
  }

  bool _isImageGenerationRequest(String query) {
    final q = query.trim().toLowerCase();
    return RegExp(
      r'^(generate|create|make|draw|render)\\s+(an?\\s+)?(image|photo|picture)\\b',
    ).hasMatch(q) ||
        RegExp(r'\\b(image|photo|picture)\\s+of\\b').hasMatch(q) ||
        q.startsWith('img:') ||
        q.startsWith('/image ');
  }

  String _imagePromptFromQuery(String query) {
    var q = query.trim();
    q = q.replaceFirst(RegExp(r'^/image\\s+', caseSensitive: false), '');
    q = q.replaceFirst(RegExp(r'^img:\\s*', caseSensitive: false), '');
    q = q.replaceFirst(
        RegExp(
          r'^(generate|create|make|draw|render)\\s+(an?\\s+)?(image|photo|picture)\\s*(of\\s*)?',
          caseSensitive: false,
        ),
        '');
    q = q.replaceFirst(RegExp(r'^(an?\\s+)?(image|photo|picture)\\s+of\\s+',
        caseSensitive: false), '');
    q = q.trim();
    // Common typo helper: strip a leading 'x' on a single token like "xcapacitor".
    q = q.replaceAllMapped(RegExp(r'\\bx([a-z]{4,})\\b', caseSensitive: false),
        (m) => m.group(1) ?? '');
    return q.isEmpty ? query.trim() : q;
  }

  bool _isWebSearchRequest(String query) {
    final q = query.trim().toLowerCase();
    return q.startsWith('/web ') || q.startsWith('web:');
  }

  String _stripWebPrefix(String query) {
    var q = query.trim();
    q = q.replaceFirst(RegExp(r'^/web\\s+', caseSensitive: false), '');
    q = q.replaceFirst(RegExp(r'^web:\\s*', caseSensitive: false), '');
    return q.trim();
  }

  bool _isFollowUpQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;
    if (q.length <= 18) {
      const shortFollowUps = {
        'why',
        'how',
        'explain',
        'more',
        'continue',
        'again',
        'real answer',
        'answer',
        'help',
        'fix',
        'solution',
        'solve',
      };
      if (shortFollowUps.contains(q)) return true;
    }
    return RegExp(
      r'(real answer|explain( more)?|more detail|continue|why( is| does)?|fix (it|this)|solve (it|this)|what about|so (then|now)|can you (do|show|give)|make it|still|not working)',
    ).hasMatch(q);
  }

  String _stripQuotePrefixes(String text) {
    return text
        .split('\n')
        .map((l) => l.startsWith('> ') ? l.substring(2) : l)
        .join('\n')
        .trim();
  }

  String? _extractUserText(String line) {
    final stripped = _stripQuotePrefixes(line);
    if (!stripped.toLowerCase().startsWith('you:')) return null;
    final text = stripped.substring(4).trim();
    // Hide internal attachment metadata from the visible user bubble.
    final idx = text.indexOf('\n> Attachments:');
    return (idx >= 0 ? text.substring(0, idx) : text).trim();
  }

  String _buildRecentChatContextFrom(
    List<String> history, {
    int maxChars = 3500,
    int maxMessages = 6,
  }) {
    if (history.isEmpty) return '';
    final messages = <String>[];
    for (int i = history.length - 1; i >= 0; i--) {
      final raw = history[i];
      final maybeUser = _extractUserText(raw);
      if (maybeUser != null) {
        messages.add('User: $maybeUser');
      } else {
        final assistant = _stripQuotePrefixes(raw);
        if (assistant.isNotEmpty) {
          messages.add('Assistant: $assistant');
        }
      }
      if (messages.length >= maxMessages) break;
      if (messages.join('\n\n').length >= maxChars) break;
    }
    final context = messages.reversed.join('\n\n');
    if (context.length <= maxChars) return context;
    return context.substring(context.length - maxChars);
  }

  String _buildMemoryBlock() {
    final s = _chatSummary.trim();
    if (s.isEmpty) return '';
    return 'Memory (previous context summary):\n$s';
  }

  void _updateLocalSummaryAfterAssistant(String assistantText) {
    final user = _lastUserMessageFrom(_chatHistory);
    if (user == null || user.trim().isEmpty) return;
    final prev = (_chatSummaryByContext[_chatContextKey] ?? '').trim();
    final entry =
        '- User: ${_truncateOneLine(user, 120)}\n  Assistant: ${_truncateOneLine(assistantText, 160)}';
    final next = prev.isEmpty ? entry : '$prev\n$entry';
    // Keep summary bounded.
    final bounded = next.length <= 1800 ? next : next.substring(next.length - 1800);
    _chatSummaryByContext[_chatContextKey] = bounded;
  }

  String _truncateOneLine(String s, int maxLen) {
    final one = s.replaceAll(RegExp(r'\\s+'), ' ').trim();
    if (one.length <= maxLen) return one;
    return '${one.substring(0, maxLen - 1)}…';
  }

  List<InlineSpan> _linkifySpans(
    String text, {
    required TextStyle style,
    required TextStyle linkStyle,
  }) {
    final spans = <InlineSpan>[];
    // Use a raw triple-quoted string so both " and ' are safe inside the regex.
    final regex = RegExp(r'''(https?:\\/\\/[^\\s)\\]}>"']+)''');
    int index = 0;
    for (final m in regex.allMatches(text)) {
      if (m.start > index) {
        spans.add(TextSpan(text: text.substring(index, m.start), style: style));
      }
      final url = text.substring(m.start, m.end);
      spans.add(
        TextSpan(
          text: url,
          style: linkStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              try {
                final uri = Uri.parse(url);
                final ok =
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                if (!ok) _toast('Unable to open link');
              } catch (_) {
                _toast('Invalid link');
              }
            },
        ),
      );
      index = m.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index), style: style));
    }
    return spans;
  }

  String? _lastUserMessageFrom(List<String> history) {
    for (int i = history.length - 1; i >= 0; i--) {
      final maybeUser = _extractUserText(history[i]);
      if (maybeUser != null && maybeUser.isNotEmpty) return maybeUser;
    }
    return null;
  }

  String? _lastAssistantMessageFrom(List<String> history) {
    for (int i = history.length - 1; i >= 0; i--) {
      final maybeUser = _extractUserText(history[i]);
      if (maybeUser != null) continue;
      final assistant = _stripQuotePrefixes(history[i]);
      if (assistant.isNotEmpty) return assistant;
    }
    return null;
  }

  void _runSearch() async {
    final query = _textController.text.trim();
    if (query.isEmpty || _isSearching) return;
    _textController.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
    _submitQuery(query);
  }

  Future<void> _submitQuery(String query, {bool fromVoice = false}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || _isSearching) return;
    final requestId = ++_activeRequestId;
    if (!fromVoice) {
      // Ensure the input box clears even if this method is called directly.
      _textController.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    if (_handleTimeAndTimers(trimmed)) return;

    final apiKeyMatch = RegExp(
      r'\\b(gsk_[A-Za-z0-9_\\-]{20,}|sk-ant-[A-Za-z0-9_\\-]{20,}|sk-[A-Za-z0-9_\\-]{20,}|AIza[0-9A-Za-z_\\-]{20,}|serper_[A-Za-z0-9_\\-]{10,})\\b',
    ).firstMatch(trimmed);
    if (apiKeyMatch != null) {
      final raw = apiKeyMatch.group(1) ?? '';
      String? storedFor;
      if (raw.startsWith('gsk_')) {
        storedFor = 'Groq';
        _groqApiKey = raw;
        unawaited(PinStorage.setGroqApiKey(raw));
      } else if (raw.startsWith('sk-ant-')) {
        storedFor = 'Claude';
        _claudeApiKey = raw;
        unawaited(PinStorage.setClaudeApiKey(raw));
      } else if (raw.startsWith('sk-')) {
        storedFor = 'OpenAI';
        _openAiApiKey = raw;
        unawaited(PinStorage.setOpenAiApiKey(raw));
      } else if (raw.startsWith('AIza')) {
        storedFor = 'Gemini';
        _geminiApiKey = raw;
        unawaited(PinStorage.setGeminiApiKey(raw));
      } else if (raw.startsWith('serper_')) {
        storedFor = 'Web search (Serper)';
        _serperApiKey = raw;
        unawaited(PinStorage.setSerperApiKey(raw));
      }

      if (mounted) {
        setState(() {
          _currentAnswer =
              storedFor == null ? 'API key detected.' : 'Saved $storedFor API key.';
          _chatHistory.add(_currentAnswer);
        });
      }
      unawaited(_syncAiPrefsToCloud());
      _scrollChatToBottom();
      return;
    }

    if (_isImageGenerationRequest(trimmed)) {
      await _showImageGenerator(initialPrompt: _imagePromptFromQuery(trimmed));
      return;
    }

    var userQueryForModel =
        _isWebSearchRequest(trimmed) ? _stripWebPrefix(trimmed) : trimmed;

    if (_isLanguageSwitchRequest(userQueryForModel)) {
      final nextLanguage = _normalizedLanguageName(userQueryForModel);
      await _applySelectedLanguage(nextLanguage);
      setState(() {
        _currentAnswer = 'Language set to: $_selectedLanguage';
        _chatHistory.add(_currentAnswer);
      });
      _queuePersistChats();
      _scrollChatToBottom();
      return;
    }

    // If user says just "definition"/"define", infer the subject from the previous user message.
    final normalized = userQueryForModel.trim().toLowerCase();
    final isDefinitionOnly = RegExp(
      r'^(definition|defination|define|meaning|what does it mean)\\b',
    ).hasMatch(normalized);
    if (isDefinitionOnly) {
      final lastUser = _lastUserMessageFrom(_chatHistory);
      if (lastUser != null && lastUser.trim().isNotEmpty) {
        final topic = _inferTopicFrom(lastUser);
        userQueryForModel =
            'Give the definition of $topic. Keep it simple and include a short example.';
      }
    }

    final attachmentLine = _attachments.isEmpty
        ? ""
        : "\n> Attachments: ${_attachments.map((a) => a.name).join(', ')}";
    setState(() {
      _chatHistory.add("> You: $userQueryForModel$attachmentLine");
    });
    _queuePersistChats();
    _scrollChatToBottom();

    if (_isGreeting(userQueryForModel)) {
      setState(() {
        _currentAnswer = "Hey! What’s up?";
        _chatHistory.add(_currentAnswer);
      });
      if (mounted && _attachments.isNotEmpty) {
        setState(() => _attachments.clear());
      }
      _queuePersistChats();
      _scrollChatToBottom();
      return;
    }

    if (_isHelpRequest(userQueryForModel)) {
      setState(() {
        _currentAnswer = _appGuideText();
        _chatHistory.add(_currentAnswer);
      });
      _queuePersistChats();
      _scrollChatToBottom();
      return;
    }

    if (_isAboutAuraRequest(userQueryForModel)) {
      setState(() {
        _currentAnswer = _aboutAuraText();
        _chatHistory.add(_currentAnswer);
      });
      _queuePersistChats();
      _scrollChatToBottom();
      return;
    }

    // Safety: allow relationship/health advice, but block pornographic/explicit content generation.
    if (_mentionsSexOrNudity(userQueryForModel)) {
      if (_isExplicitSexRequest(userQueryForModel)) {
        setState(() {
          _currentAnswer =
              "I can’t help create explicit sexual content.\nIf you want, tell me the situation and what you need (consent, safety, communication, health, relationship advice), and I’ll help respectfully.";
          _chatHistory.add(_currentAnswer);
        });
        _queuePersistChats();
        _scrollChatToBottom();
        return;
      } else {
        // Reframe into safe advice so models don't assume a request for explicit content.
        userQueryForModel = _rewriteSexAdviceQuery(userQueryForModel);
      }
    }

    // Watchdog to avoid getting stuck in "loading" forever on flaky networks.
    _searchWatchdog?.cancel();
    _searchWatchdog = Timer(const Duration(seconds: 45), () {
      if (!mounted) return;
      if (!_isSearching) return;
      setState(() {
        _isSearching = false;
        _isOnline = false;
        _currentAnswer =
            'Request timed out. Check your internet/API key and try again.';
        _chatHistory.add(_currentAnswer);
      });
      _scrollChatToBottom();
    });

    final normalized2 = userQueryForModel.trim().toLowerCase();
    final isVague = normalized.isEmpty ||
        RegExp(r'^(it|this|that|help|\\?)$').hasMatch(normalized2);
    if (isVague) {
      setState(() {
        _currentAnswer =
            "Tell me what you want to do and I’ll help.\nExamples: “Explain front end”, “Write a CV”, “Fix my Wi‑Fi”, “Plan my day”.";
        _chatHistory.add(_currentAnswer);
      });
      _queuePersistChats();
      _scrollChatToBottom();
      return;
    }

    if (_isFollowUpQuery(userQueryForModel) && _chatHistory.length <= 1) {
      setState(() {
        _currentAnswer =
            "> I can do that — what’s the topic/problem?\n> Paste the question, error, code, or a screenshot, then I’ll give a direct answer.";
      });
      return;
    }

    // Allow all topics; avoid hard-gating to ICT only.

    setState(() {
      _isSearching = true;
      _currentAnswer = "";
      _openPanel = null;
    });
    _scrollChatToBottom();

    _revealController.reverse();
    _orbitController.stop();
    _searchSpinController.repeat();

    try {
      final forceCasual = _looksCasualChat(userQueryForModel);
      final moodInstruction = _moodInstructionFor(userQueryForModel);
      final availableLevels = levels.map((level) => level.name).join(', ');
      final appGuide = _appGuideText();
      final systemPrompt = OllamaService.buildSystemPrompt(
        _userLevel.name,
        _selectedCourse,
        style: _conversationStyle,
        forceCasual: forceCasual,
        moodInstruction: moodInstruction,
        availableLevels: availableLevels,
        appGuide: appGuide,
        preferredLanguage: _selectedLanguage,
      );
      if (mounted) setState(() => _currentAnswer = "> Thinking...");
      _scrollChatToBottom();

      final attachmentTexts = _attachments
          .map(_attachmentTextForPrompt)
          .where((t) => t.trim().isNotEmpty)
          .toList();

      final historyExcludingCurrent = _chatHistory.length <= 1
          ? const <String>[]
          : _chatHistory.sublist(0, _chatHistory.length - 1);
      final priorHistory = historyExcludingCurrent.isEmpty
          ? ''
          : _buildRecentChatContextFrom(
              historyExcludingCurrent,
              maxChars: 3500,
              maxMessages: 6,
            );
      final memoryBlock = _buildMemoryBlock();
    final shortFollowUp = userQueryForModel.trim().split(RegExp(r'\s+')).length <= 4;
    final shouldAttachHistory = _isFollowUpQuery(userQueryForModel) ||
          RegExp(r'^(and|also|so|then|but)\\b', caseSensitive: false)
              .hasMatch(userQueryForModel) ||
          RegExp(r'\\b(it|this|that|those|these|they)\\b', caseSensitive: false)
              .hasMatch(userQueryForModel);
    final forceAttachHistory = shortFollowUp ||
        RegExp(r'^(yes|no|ok|okay|sure|do it|go on|continue|more|again|why|how|what|definition|define)\\b',
                caseSensitive: false)
            .hasMatch(userQueryForModel.trim());

      final qLower = userQueryForModel.toLowerCase();
      final wantsDirectAnswer =
          qLower.contains('real answer') ||
          qLower.contains('direct answer') ||
          qLower.contains('just answer') ||
          qLower.contains('give me answer') ||
          qLower.contains('give me real answer');

      String webContextBlock = '';
      final shouldWebSearch = _webSearchEnabled || _isWebSearchRequest(query);
      if (shouldWebSearch) {
        if (mounted) {
          setState(() => _currentAnswer = "Searching the web…");
        }
        final key = _serperApiKey.trim();
        if (key.isEmpty) {
          throw Exception(
              'Web search is enabled but missing Serper API key. Add it in AI Settings.');
        }
        final results = await SerperSearchService.search(
          apiKey: key,
          query: userQueryForModel,
          maxResults: 5,
        );
        if (results.isNotEmpty) {
          final lines = <String>[];
          for (int i = 0; i < results.length; i++) {
            final r = results[i];
            lines.add(
              '${i + 1}. ${r['title']}\n${r['link']}\n${r['snippet']}',
            );
          }
          _chatHistory.add(
            "Sources:\n${results.asMap().entries.map((e) => '${e.key + 1}. ${e.value['link']}').join('\n')}",
          );
          _queuePersistChats();
          _scrollChatToBottom();
          webContextBlock = [
            'Web search results (use these as sources; include URLs in your answer):',
            ...lines,
          ].join('\n\n');
        } else {
          _chatHistory.add("Sources: (no results)");
          _queuePersistChats();
          _scrollChatToBottom();
        }
      }

      final basePrompt =
          (!(shouldAttachHistory || forceAttachHistory) || historyExcludingCurrent.isEmpty)
              ? userQueryForModel
              : wantsDirectAnswer
                  ? () {
                      final lastUser = _lastUserMessageFrom(historyExcludingCurrent);
                      final lastAssistant =
                          _lastAssistantMessageFrom(historyExcludingCurrent);
                      return [
                        if (lastUser != null) "Previous user question:\n$lastUser",
                        if (lastAssistant != null)
                          "\nPrevious assistant answer:\n$lastAssistant",
                        "\nUser follow-up:\n$userQueryForModel",
                        "\nInstruction: Give a direct, concrete answer/solution to the previous question. Do not ask clarifying questions; if something is missing, make a reasonable assumption and proceed.",
                      ].join("\n");
                    }()
                  : [
                      "Conversation context:",
                      if (memoryBlock.isNotEmpty) memoryBlock,
                      priorHistory,
                      "",
                      "User follow-up:",
                      userQueryForModel,
                    ].join("\n");

      final prompt = _attachments.isEmpty
          ? [
              basePrompt,
              if (webContextBlock.isNotEmpty) ...['', webContextBlock],
            ].join('\n')
          : [
              basePrompt,
              if (webContextBlock.isNotEmpty) ...['', webContextBlock],
              "",
              "Context: The user attached files related to the question.",
              "Files: ${_attachments.map((a) => a.name).join(', ')}",
              if (attachmentTexts.isNotEmpty) ...[
                "",
                ...attachmentTexts,
              ],
            ].join("\n");

      final String finalAnswer;
      final imageAttachments = _attachments.where((a) => a.isImage).toList();
      if (imageAttachments.isNotEmpty) {
        final key = _openAiApiKey.trim();
        if (key.isEmpty) {
          final msg =
              'To understand images, add your OpenAI API key in AI Settings (Images/Vision), then send the image again.';
          if (mounted) {
            setState(() {
              _currentAnswer = msg;
              _chatHistory.add(msg);
            });
          } else {
            _currentAnswer = msg;
            _chatHistory.add(msg);
          }
          _queuePersistChats();
          _scrollChatToBottom();
          if (_voiceChatEnabled && mounted) {
            await _startListening();
          }
          return;
        }
        finalAnswer = await OpenAiVisionService.describe(
          apiKey: key,
          prompt:
              'User question: $userQueryForModel\n\nIf the question is unclear, describe what you see and give the most likely helpful answer.',
          images: imageAttachments,
        );
        if (mounted) {
          setState(() => _currentAnswer = finalAnswer);
        }
        if (mounted) setState(() => _isOnline = true);
      } else if (_aiEngine == 'groq') {
        final key = _groqApiKey.trim();
        if (key.isEmpty) {
          throw Exception('Missing Groq API key. Tap the tune icon to add it.');
        }
        final messages = _buildOpenAiStyleMessages(
          systemPrompt: systemPrompt,
          userPrompt: prompt,
          maxTurns: 8,
        );
        finalAnswer = await GroqService.generate(
          apiKey: key,
          prompt: prompt,
          systemPrompt: systemPrompt,
          messages: messages,
          model: _groqModel,
          onChunk: (chunk) {
            if (requestId != _activeRequestId) return;
            if (mounted) setState(() => _currentAnswer = chunk);
            _scrollChatToBottom();
          },
        ).timeout(
          const Duration(seconds: 40),
          onTimeout: () => throw TimeoutException('Request timeout'),
        );
        if (mounted) setState(() => _isOnline = true);
      } else if (_aiEngine == 'openai') {
        final key = _openAiApiKey.trim();
        if (key.isEmpty) {
          throw Exception('Missing OpenAI API key. Add it in AI Settings.');
        }
        final messages = _buildOpenAiStyleMessages(
          systemPrompt: systemPrompt,
          userPrompt: prompt,
          maxTurns: 10,
        );
        finalAnswer = await OpenAiChatService.generate(
          apiKey: key,
          prompt: prompt,
          systemPrompt: systemPrompt,
          messages: messages,
          model: _openAiModel,
          onChunk: (chunk) {
            if (requestId != _activeRequestId) return;
            if (mounted) setState(() => _currentAnswer = chunk);
            _scrollChatToBottom();
          },
        ).timeout(
          const Duration(seconds: 40),
          onTimeout: () => throw TimeoutException('Request timeout'),
        );
        if (mounted) setState(() => _isOnline = true);
      } else if (_aiEngine == 'gemini') {
        final key = _geminiApiKey.trim();
        if (key.isEmpty) {
          throw Exception('Missing Gemini API key. Add it in AI Settings.');
        }
      finalAnswer = await GeminiChatService.generate(
          apiKey: key,
          prompt: prompt,
          systemPrompt: systemPrompt,
          model: _geminiModel,
        ).timeout(
          const Duration(seconds: 40),
          onTimeout: () => throw TimeoutException('Request timeout'),
        );
        if (mounted) setState(() => _currentAnswer = finalAnswer);
        if (mounted) setState(() => _isOnline = true);
      } else if (_aiEngine == 'claude') {
        final key = _claudeApiKey.trim();
        if (key.isEmpty) {
          throw Exception('Missing Claude API key. Add it in AI Settings.');
        }
      finalAnswer = await ClaudeChatService.generate(
          apiKey: key,
          prompt: prompt,
          systemPrompt: systemPrompt,
          model: _claudeModel,
        ).timeout(
          const Duration(seconds: 40),
          onTimeout: () => throw TimeoutException('Request timeout'),
        );
        if (mounted) setState(() => _currentAnswer = finalAnswer);
        if (mounted) setState(() => _isOnline = true);
      } else {
        throw Exception('Unknown engine: $_aiEngine');
      }
      if (requestId != _activeRequestId) return;
      if (mounted) {
        setState(() {
          _chatHistory.add(_currentAnswer);
        });
      } else {
        _chatHistory.add(_currentAnswer);
      }
      _updateLocalSummaryAfterAssistant(finalAnswer);
      _queuePersistChats();
      _scrollChatToBottom();
      await PinStorage.updateStreak();

      // Unblock UI immediately; speaking should not keep the "sending" state.
      if (mounted) setState(() => _isSearching = false);

      final shouldSpeak = _voiceChatEnabled || _speakAnswers;
      if (shouldSpeak) {
        unawaited(() async {
          try {
            if (!mounted) return;
            setState(() => _isSpeaking = true);
            await _stopListening();
            // Ensure the final text is painted before TTS starts (prevents "speaks first, shows later").
            await Future<void>.delayed(const Duration(milliseconds: 30));
            await VoiceService.speak(finalAnswer);
          } finally {
            if (mounted && requestId == _activeRequestId) {
              setState(() => _isSpeaking = false);
              // Hands-free voice mode: automatically resume listening after speaking.
              if (_voiceChatEnabled) {
                unawaited(_startListening());
              }
            }
          }
        }());
      }
      if (mounted && _attachments.isNotEmpty) {
        setState(() => _attachments.clear());
      }
      // Note: voice mode resumes listening after TTS finishes (see above).
    } catch (e) {
      setState(() {
        _currentAnswer = e.toString();
        _ollamaAvailable = false;
      });
      if (e is SocketException || e is TimeoutException) {
        if (mounted) setState(() => _isOnline = false);
      }
      if (_voiceChatEnabled && mounted) {
        await _startListening();
      }
    } finally {
      _searchWatchdog?.cancel();
      _searchSpinController.stop();
      _searchSpinController.reset();
      _orbitController.repeat();
      if (mounted && requestId == _activeRequestId) {
        setState(() => _isSearching = false);
      }
      _revealController.forward();
    }
  }

  String _inferTopicFrom(String lastUser) {
    final lower = lastUser.toLowerCase();
    if (lower.contains('python')) return 'Python';
    if (lower.contains('java')) return 'Java';
    if (lower.contains('javascript') || lower.contains('js')) return 'JavaScript';
    if (lower.contains('html')) return 'HTML';
    if (lower.contains('css')) return 'CSS';
    final cleaned = lastUser.replaceAll(RegExp(r'[^A-Za-z0-9\\s]'), '').trim();
    if (cleaned.isEmpty) return 'that';
    final words = cleaned.split(RegExp(r'\\s+')).where((w) => w.isNotEmpty).toList();
    return words.take(6).join(' ');
  }

  bool _mentionsSexOrNudity(String s) {
    final t = s.toLowerCase();
    return RegExp(
      r'\\b(sex|sext|nude|nudes|porn|pornography|hook\\s*up|hookup|blowjob|handjob|oral|anal|xxx)\\b',
    ).hasMatch(t);
  }

  bool _isExplicitSexRequest(String s) {
    final t = s.toLowerCase();
    // Heuristic: explicit content creation or detailed sexual instructions.
    return RegExp(
      r'\\b(write|create|generate|role\\s*play|rp|sext|dirty\\s*talk|explicit|porn|nude|nudes)\\b',
    ).hasMatch(t) ||
        RegExp(
          r'\\b(how\\s+to\\s+have\\s+sex|sex\\s+positions|describe\\s+in\\s+detail)\\b',
        ).hasMatch(t);
  }

  String _rewriteSexAdviceQuery(String original) {
    return [
      "The user is asking for non-explicit advice related to sex/relationships.",
      "Give respectful, practical guidance focused on consent, safety, communication, and health. Do not be explicit.",
      "",
      "User message:",
      original.trim(),
    ].join('\\n');
  }

  Future<void> _addImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked =
          await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final mimeType = switch (ext) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/*',
      };
      if (!mounted) return;
      setState(() {
        _attachments.add(
          _UserAttachment(name: picked.name, mimeType: mimeType, bytes: bytes),
        );
      });
    } catch (e) {
      _toast('Failed to pick image');
    }
  }

  Future<void> _addDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        _toast('Unable to read file');
        return;
      }
      final name = file.name;
      final mimeType = file.extension == null
          ? 'application/octet-stream'
          : 'application/${file.extension}';
      if (!mounted) return;
      setState(() {
        _attachments.add(
          _UserAttachment(name: name, mimeType: mimeType, bytes: bytes),
        );
      });
    } catch (_) {
      _toast('Failed to pick file');
    }
  }

  void _removeAttachment(_UserAttachment attachment) {
    setState(() => _attachments.remove(attachment));
  }

  bool _looksLikeText(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    final sample = bytes.length > 4096 ? bytes.sublist(0, 4096) : bytes;
    int weird = 0;
    for (final b in sample) {
      if (b == 0) return false;
      final isCommon = (b == 9 || b == 10 || b == 13) || (b >= 32 && b <= 126);
      if (!isCommon) weird++;
    }
    return weird / sample.length < 0.15;
  }

  String _attachmentTextForPrompt(_UserAttachment a) {
    const maxBytes = 200 * 1024;
    if (a.isImage) return '';
    final lower = a.name.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return 'File `${a.name}` is a PDF. I can’t reliably extract PDF text yet; paste the relevant text or export the PDF to .txt/.md and re-upload.';
    }
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return 'File `${a.name}` is a Word document. I can’t parse DOCX yet; export to .txt/.md and re-upload.';
    }
    if (a.bytes.length > maxBytes) {
      return 'File `${a.name}` is too large to include (>${maxBytes ~/ 1024}KB).';
    }
    if (!_looksLikeText(a.bytes)) {
      return 'File `${a.name}` looks binary; paste relevant text if needed.';
    }
    final text = utf8.decode(a.bytes, allowMalformed: true).trim();
    if (text.isEmpty) return 'File `${a.name}` is empty.';
    final clipped = text.length > 12000 ? text.substring(0, 12000) : text;
    return 'File `${a.name}` contents:\n```text\n$clipped\n```';
  }

  Future<void> _showAttachmentSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0D1117),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: Colors.white70),
                title: const Text('Generate image',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Create a real PNG image from your prompt',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _showImageGenerator();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Colors.white70),
                title: const Text('Take photo',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _addImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo, color: Colors.white70),
                title: const Text('Choose image',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _addImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file, color: Colors.white70),
                title: const Text('Choose document',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _addDocument();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showImageGenerator({String? initialPrompt}) async {
    final promptController = TextEditingController(text: initialPrompt ?? '');
    String size = '1024x1024';
    bool generating = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0D1117),
            title:
                const Text('Generate Image', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: promptController,
                  minLines: 2,
                  maxLines: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Prompt',
                    labelStyle: TextStyle(color: Colors.white70),
                    hintText: 'e.g., A realistic photo of an electronic capacitor...',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: size,
                  dropdownColor: const Color(0xFF0D1117),
                  decoration: const InputDecoration(
                    labelText: 'Size',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: const [
                    DropdownMenuItem(value: '512x512', child: Text('512×512')),
                    DropdownMenuItem(value: '1024x1024', child: Text('1024×1024')),
                    DropdownMenuItem(value: '1024x1536', child: Text('1024×1536')),
                    DropdownMenuItem(value: '1536x1024', child: Text('1536×1024')),
                  ],
                  onChanged: (v) => setModalState(() => size = v ?? '1024x1024'),
                ),
                if (_openAiApiKey.trim().isEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _openOpenAiApiKeyPage,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Get OpenAI API key'),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: generating ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: generating
                    ? null
                    : () async {
                        final prompt = promptController.text.trim();
                        if (prompt.isEmpty) {
                          _toast('Enter a prompt');
                          return;
                        }
                        final key = _openAiApiKey.trim();
                        if (key.isEmpty) {
                          _toast('Add your OpenAI API key in AI Settings');
                          return;
                        }
                        setModalState(() => generating = true);
                        try {
                          final bytes = await OpenAiImageService.generatePngBytes(
                            apiKey: key,
                            prompt: prompt,
                            size: size,
                          );
                          if (!mounted) return;
                          final suggestedName =
                              'aura_image_${DateTime.now().millisecondsSinceEpoch}.png';
                          final savedPath = await _saveGeneratedImage(
                            bytes: bytes,
                            suggestedName: suggestedName,
                          );
                          setState(() {
                            _attachments.add(
                              _UserAttachment(
                                name: suggestedName,
                                mimeType: 'image/png',
                                bytes: bytes,
                              ),
                            );
                            _currentAnswer =
                                'AURA: ✅ Image generated.\nSaved: $savedPath';
                            _chatHistory.add('> You: generate image: $prompt');
                            _chatHistory.add(_currentAnswer);
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          _toast(e.toString());
                          setModalState(() => generating = false);
                        }
                      },
                child: generating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Generate'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String> _saveGeneratedImage({
    required Uint8List bytes,
    required String suggestedName,
  }) async {
    if (kIsWeb) throw Exception('Image save not supported on web');
    String? path;
    try {
      path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save generated image',
        fileName: suggestedName,
      );
    } catch (_) {
      path = null;
    }
    if (path == null) {
      final dir = await getApplicationDocumentsDirectory();
      path = '${dir.path}/$suggestedName';
    }
    await File(path).writeAsBytes(bytes, flush: true);
    _toast('Saved: $path');
    return path;
  }

  Future<void> _exportText({
    required String suggestedName,
    required String contents,
  }) async {
    await _exportBytes(
      suggestedName: suggestedName,
      bytes: utf8.encode(contents),
    );
  }

  Future<void> _exportMarkdown({
    required String suggestedName,
    required String title,
    required String body,
  }) async {
    final cleanTitle = _stripQuotePrefixes(title).trim();
    final cleanBody = _stripQuotePrefixes(body).trim();
    final md = [
      '# ${cleanTitle.isEmpty ? 'AURA Export' : cleanTitle}',
      '',
      cleanBody,
      '',
    ].join('\n');
    await _exportBytes(
      suggestedName: suggestedName.endsWith('.md') ? suggestedName : '$suggestedName.md',
      bytes: utf8.encode(md),
    );
  }

  Future<void> _exportJson({
    required String suggestedName,
    required Map<String, dynamic> jsonMap,
  }) async {
    final pretty = const JsonEncoder.withIndent('  ').convert(jsonMap);
    await _exportBytes(
      suggestedName: suggestedName.endsWith('.json') ? suggestedName : '$suggestedName.json',
      bytes: utf8.encode(pretty),
    );
  }

  Future<void> _exportBytes({
    required String suggestedName,
    required List<int> bytes,
  }) async {
    if (kIsWeb) {
      _toast('Export not supported on web');
      return;
    }
    try {
      String? path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export',
        fileName: suggestedName,
      );

      if (path == null) {
        final dir = await getApplicationDocumentsDirectory();
        path = '${dir.path}/$suggestedName';
      }

      await File(path).writeAsBytes(bytes, flush: true);
      _toast('Saved: $path');
    } catch (_) {
      _toast('Export failed');
    }
  }

  Future<void> _exportPdf({
    required String suggestedName,
    required String title,
    required String body,
  }) async {
    final cleanTitle = _stripQuotePrefixes(title).trim();
    final cleanBody = _stripQuotePrefixes(body).trim();
    final doc = pw.Document();
    final now = DateTime.now();
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.fromLTRB(36, 42, 36, 42),
        ),
        build: (_) => [
          pw.Text(cleanTitle.isEmpty ? 'AURA Answer' : cleanTitle,
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(
            'Exported: ${now.toIso8601String().replaceFirst('T', ' ').split('.').first}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            cleanBody.isEmpty ? '(empty)' : cleanBody,
            style: const pw.TextStyle(fontSize: 12, lineSpacing: 4),
            softWrap: true,
          ),
        ],
      ),
    );
    await _exportBytes(
      suggestedName: suggestedName.endsWith('.pdf')
          ? suggestedName
          : '$suggestedName.pdf',
      bytes: await doc.save(),
    );
  }

  Future<void> _showExportSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0D1117),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.description, color: Colors.white70),
                title: const Text('Export answer (.txt)',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportText(
                    suggestedName: 'aura_answer.txt',
                    contents: _currentAnswer.trim().isEmpty
                        ? ''
                        : _currentAnswer.trim(),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.code, color: Colors.white70),
                title: const Text('Export answer (.md)',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportMarkdown(
                    suggestedName: 'aura_answer.md',
                    title: 'AURA Answer',
                    body: _currentAnswer.trim(),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.white70),
                title: const Text('Export answer (.pdf)',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportPdf(
                    suggestedName: 'aura_answer.pdf',
                    title: 'AURA Answer',
                    body: _currentAnswer.trim().isEmpty
                        ? ''
                        : _currentAnswer.trim(),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.data_object, color: Colors.white70),
                title: const Text('Export answer (.json)',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportJson(
                    suggestedName: 'aura_answer.json',
                    jsonMap: {
                      'type': 'answer',
                      'engine': _aiEngine,
                      'createdAt': DateTime.now().toIso8601String(),
                      'answer': _currentAnswer.trim(),
                      'contextKey': _chatContextKey,
                      'course': _selectedCourse,
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.notes, color: Colors.white70),
                title: const Text('Export chat (.txt)',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportText(
                    suggestedName: 'aura_chat.txt',
                    contents: _chatHistory.join('\n\n'),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.code, color: Colors.white70),
                title: const Text('Export chat (.md)',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportMarkdown(
                    suggestedName: 'aura_chat.md',
                    title: 'AURA Chat',
                    body: _chatHistory.join('\n\n'),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.white70),
                title: const Text('Export chat (.pdf)',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportPdf(
                    suggestedName: 'aura_chat.pdf',
                    title: 'AURA Chat',
                    body: _chatHistory.join('\n\n'),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.data_object, color: Colors.white70),
                title: const Text('Export chat (.json)',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportJson(
                    suggestedName: 'aura_chat.json',
                    jsonMap: {
                      'type': 'chat',
                      'engine': _aiEngine,
                      'createdAt': DateTime.now().toIso8601String(),
                      'contextKey': _chatContextKey,
                      'course': _selectedCourse,
                      'messages': List<String>.from(_chatHistory),
                      'memorySummary': _chatSummary,
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAiSettings() async {
    final groqController = TextEditingController(text: _groqApiKey);
    final groqModelController = TextEditingController(text: _groqModel);
    final openAiController = TextEditingController(text: _openAiApiKey);
    final openAiModelController = TextEditingController(text: _openAiModel);
    final geminiController = TextEditingController(text: _geminiApiKey);
    final geminiModelController = TextEditingController(text: _geminiModel);
    final claudeController = TextEditingController(text: _claudeApiKey);
    final claudeModelController = TextEditingController(text: _claudeModel);
    final serperController = TextEditingController(text: _serperApiKey);

    String tempEngine = _aiEngine;
    String tempStyle = _conversationStyle;
    String tempImageProvider = _imageProvider;
    bool tempWebEnabled = _webSearchEnabled;
    String tempMoodMode = _moodMode;
    bool showKeys = false;
    bool didAutofillFromClipboard = false;

    InputDecoration decorate({
      required String label,
      String? hint,
      Widget? suffixIcon,
    }) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        suffixIcon: suffixIcon,
      );
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          if (!didAutofillFromClipboard) {
            didAutofillFromClipboard = true;
            Future.microtask(() async {
              final data = await Clipboard.getData('text/plain');
              final raw = data?.text?.trim();
              if (raw == null || raw.isEmpty) return;
              if (raw.startsWith('gsk_') && groqController.text.trim().isEmpty) {
                groqController.text = raw;
              } else if ((raw.startsWith('sk-') || raw.startsWith('sk_proj_')) &&
                  openAiController.text.trim().isEmpty) {
                openAiController.text = raw;
              } else if (raw.startsWith('sk-ant-') &&
                  claudeController.text.trim().isEmpty) {
                claudeController.text = raw;
              } else if (raw.startsWith('AIza') &&
                  geminiController.text.trim().isEmpty) {
                geminiController.text = raw;
              } else if (raw.startsWith('serper_') &&
                  serperController.text.trim().isEmpty) {
                serperController.text = raw;
              } else {
                return;
              }
              if (ctx.mounted) setModalState(() {});
            });
          }

          final mq = MediaQuery.of(ctx);
          final size = mq.size;
          final isSmall = size.height < 700 || size.width < 420;
          // When the keyboard is open, available height is smaller; otherwise the dialog can overflow.
          final availableHeight = size.height - mq.viewInsets.bottom;
          final maxDialogHeight = availableHeight * (isSmall ? 0.92 : 0.82);
          final scrollController = ScrollController();

          Future<void> save() async {
            final groqKey = groqController.text.trim();
            final groqModel = groqModelController.text.trim();
            final openAiKey = openAiController.text.trim();
            final openAiModel = openAiModelController.text.trim();
            final geminiKey = geminiController.text.trim();
            final geminiModel = geminiModelController.text.trim();
            final claudeKey = claudeController.text.trim();
            final claudeModel = claudeModelController.text.trim();
            final serperKey = serperController.text.trim();

            if (!mounted) return;
            setState(() {
              _aiEngine = tempEngine;
              _conversationStyle = tempStyle;
              _moodMode = tempMoodMode;
              _imageProvider = tempImageProvider;
              _webSearchEnabled = tempWebEnabled;
              _groqApiKey = groqKey;
              if (groqModel.isNotEmpty) _groqModel = groqModel;
              _openAiApiKey = openAiKey;
              if (openAiModel.isNotEmpty) _openAiModel = openAiModel;
              _geminiApiKey = geminiKey;
              if (geminiModel.isNotEmpty) _geminiModel = geminiModel;
              _claudeApiKey = claudeKey;
              if (claudeModel.isNotEmpty) _claudeModel = claudeModel;
              _serperApiKey = serperKey;
            });

            await PinStorage.setAiEngine(tempEngine);
            await PinStorage.setConversationStyle(tempStyle);
            await PinStorage.setMoodMode(tempMoodMode);
            await PinStorage.setImageProvider(tempImageProvider);
            await PinStorage.setWebSearchEnabled(tempWebEnabled);
            await PinStorage.setGroqApiKey(groqKey);
            await PinStorage.setOpenAiApiKey(openAiKey);
            await PinStorage.setGeminiApiKey(geminiKey);
            await PinStorage.setClaudeApiKey(claudeKey);
            await PinStorage.setSerperApiKey(serperKey);
            await PinStorage.setGroqModel(_groqModel);
            await PinStorage.setOpenAiModel(_openAiModel);
            await PinStorage.setGeminiModel(_geminiModel);
            await PinStorage.setClaudeModel(_claudeModel);

            try {
              await _syncAiPrefsToCloud().timeout(const Duration(seconds: 3));
            } catch (_) {}
          }

          Widget modelField({
            required TextEditingController controller,
            required String label,
            required String hint,
          }) {
            return TextField(
              controller: controller,
              enableInteractiveSelection: true,
              style: const TextStyle(color: Colors.white),
              onChanged: (_) => setModalState(() {}),
              decoration: decorate(label: label, hint: hint),
            );
          }

          Widget keyField({
            required TextEditingController controller,
            required String label,
            required String hint,
            VoidCallback? onGetKey,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  obscureText: !showKeys,
                  enableInteractiveSelection: true,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (_) => setModalState(() {}),
                  decoration: decorate(
                    label: label,
                    hint: hint,
                    suffixIcon: Wrap(
                      spacing: 0,
                      children: [
                        IconButton(
                          tooltip: showKeys ? 'Hide' : 'Show',
                          onPressed: () =>
                              setModalState(() => showKeys = !showKeys),
                          icon: Icon(
                            showKeys ? Icons.visibility_off : Icons.visibility,
                            size: 18,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy',
                          onPressed: () =>
                              _copyToClipboard(controller.text.trim()),
                          icon: const Icon(Icons.copy, size: 18),
                        ),
                        IconButton(
                          tooltip: 'Paste',
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            final raw = data?.text?.trim();
                            if (raw == null || raw.isEmpty) return;
                            controller.text = raw;
                            setModalState(() {});
                          },
                          icon: const Icon(Icons.content_paste, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
                if (onGetKey != null && controller.text.trim().isEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onGetKey,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Get your API key'),
                    ),
                  ),
              ],
            );
          }

          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
            child: Dialog(
              backgroundColor: const Color(0xFF0D1117),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxHeight: maxDialogHeight, maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'AI Settings',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Scrollbar(
                        controller: scrollController,
                        thumbVisibility: !isSmall,
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DropdownButtonFormField<String>(
                                value: tempEngine,
                                dropdownColor: const Color(0xFF0D1117),
                                decoration: const InputDecoration(
                                  labelText: 'Engine',
                                  labelStyle: TextStyle(color: Colors.white70),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'groq',
                                      child: Text('Groq (Cloud)')),
                                  DropdownMenuItem(
                                      value: 'openai',
                                      child: Text('OpenAI (GPT)')),
                                  DropdownMenuItem(
                                      value: 'gemini', child: Text('Gemini')),
                                  DropdownMenuItem(
                                      value: 'claude', child: Text('Claude')),
                                ],
                                onChanged: (v) => setModalState(() {
                                  tempEngine = v ?? 'groq';
                                }),
                              ),
                              const SizedBox(height: 12),
                              if (tempEngine == 'groq')
                                keyField(
                                  controller: groqController,
                                  label: 'Groq API Key',
                                  hint: 'gsk_...',
                                  onGetKey: _openGroqApiKeyPage,
                                ),
                              if (tempEngine == 'groq') ...[
                                const SizedBox(height: 8),
                                modelField(
                                  controller: groqModelController,
                                  label: 'Groq Model',
                                  hint: 'e.g. llama-3.1-8b-instant',
                                ),
                              ],
                              if (tempEngine == 'openai')
                                keyField(
                                  controller: openAiController,
                                  label: 'OpenAI API Key',
                                  hint: 'sk-...',
                                  onGetKey: _openOpenAiApiKeyPage,
                                ),
                              if (tempEngine == 'openai') ...[
                                const SizedBox(height: 8),
                                modelField(
                                  controller: openAiModelController,
                                  label: 'OpenAI Model',
                                  hint: 'e.g. gpt-4.1-mini',
                                ),
                              ],
                              if (tempEngine == 'gemini')
                                keyField(
                                  controller: geminiController,
                                  label: 'Gemini API Key',
                                  hint: 'AIza...',
                                  onGetKey: _openGeminiApiKeyPage,
                                ),
                              if (tempEngine == 'gemini') ...[
                                const SizedBox(height: 8),
                                modelField(
                                  controller: geminiModelController,
                                  label: 'Gemini Model',
                                  hint: 'e.g. gemini-1.5-flash',
                                ),
                              ],
                              if (tempEngine == 'claude')
                                keyField(
                                  controller: claudeController,
                                  label: 'Claude API Key',
                                  hint: 'sk-ant-...',
                                  onGetKey: _openClaudeApiKeyPage,
                                ),
                              if (tempEngine == 'claude') ...[
                                const SizedBox(height: 8),
                                modelField(
                                  controller: claudeModelController,
                                  label: 'Claude Model',
                                  hint: 'e.g. claude-3-5-sonnet-20240620',
                                ),
                              ],
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: tempStyle,
                                dropdownColor: const Color(0xFF0D1117),
                                decoration: const InputDecoration(
                                  labelText: 'Style',
                                  labelStyle: TextStyle(color: Colors.white70),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'chill',
                                      child: Text('Chill (Chat)')),
                                  DropdownMenuItem(
                                      value: 'study',
                                      child: Text('Study (Serious)')),
                                ],
                                onChanged: (v) => setModalState(() {
                                  tempStyle = v ?? 'chill';
                                }),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: tempMoodMode,
                                dropdownColor: const Color(0xFF0D1117),
                                decoration: const InputDecoration(
                                  labelText: 'Mood',
                                  labelStyle: TextStyle(color: Colors.white70),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'auto', child: Text('Auto')),
                                  DropdownMenuItem(
                                      value: 'supportive',
                                      child: Text('Supportive')),
                                  DropdownMenuItem(
                                      value: 'funny', child: Text('Funny')),
                                  DropdownMenuItem(
                                      value: 'serious', child: Text('Serious')),
                                ],
                                onChanged: (v) => setModalState(() {
                                  tempMoodMode = v ?? 'auto';
                                }),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: tempImageProvider,
                                dropdownColor: const Color(0xFF0D1117),
                                decoration: const InputDecoration(
                                  labelText: 'Image Engine',
                                  labelStyle: TextStyle(color: Colors.white70),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'openai',
                                      child: Text('OpenAI (Cloud)')),
                                ],
                                onChanged: (v) => setModalState(() {
                                  tempImageProvider = v ?? 'openai';
                                }),
                              ),
                              if (tempImageProvider == 'openai') ...[
                                const SizedBox(height: 12),
                                keyField(
                                  controller: openAiController,
                                  label: 'OpenAI API Key (Images/Vision)',
                                  hint: 'sk-...',
                                  onGetKey: _openOpenAiApiKeyPage,
                                ),
                              ],
                              const SizedBox(height: 12),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: tempWebEnabled,
                                onChanged: (v) =>
                                    setModalState(() => tempWebEnabled = v),
                                title: const Text('Web search',
                                    style: TextStyle(color: Colors.white)),
                                subtitle: const Text(
                                  'Fetch live sources from the internet',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 12),
                                ),
                              ),
                              if (tempWebEnabled) ...[
                                const SizedBox(height: 6),
                                keyField(
                                  controller: serperController,
                                  label: 'Serper API Key',
                                  hint: 'serper_...',
                                  onGetKey: _openSerperApiKeyPage,
                                ),
                              ],
                              const SizedBox(height: 6),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel',
                                style: TextStyle(color: Colors.white54)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await save();
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openGroqApiKeyPage() async {
    const url = 'https://console.groq.com/keys';
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _toast('Unable to open Groq API keys page');
  }

  Future<void> _openOpenAiApiKeyPage() async {
    const url = 'https://platform.openai.com/api-keys';
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _toast('Unable to open OpenAI API keys page');
  }

  Future<void> _openSerperApiKeyPage() async {
    const url = 'https://serper.dev/';
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _toast('Unable to open Serper page');
  }

  Future<void> _openGeminiApiKeyPage() async {
    const url = 'https://aistudio.google.com/app/apikey';
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _toast('Unable to open Gemini API key page');
  }

  Future<void> _openClaudeApiKeyPage() async {
    const url = 'https://console.anthropic.com/settings/keys';
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _toast('Unable to open Claude API key page');
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

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
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

    final availableHeight = size.height -
        MediaQuery.of(context).padding.vertical -
        MediaQuery.of(context).viewInsets.bottom;
    final baseOrbSize = _isCompact ? 120 : (isSmallScreen ? 250 : 300);
    final heightLimitedOrbSize =
        (availableHeight * (isSmallScreen ? 0.33 : 0.36)).clamp(140.0, 320.0);
    double orbSize = math.min(baseOrbSize.toDouble(), heightLimitedOrbSize);

    return WillPopScope(
      onWillPop: _onBackPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        color: _themeBg,
        child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
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
        ),
      ),
    );
  }

  Widget _buildMobileLayout(double orbSize) {
    return Column(
      children: [
        _buildTopSystemInfo(),
        const SizedBox(height: 12),
        Expanded(flex: 3, child: Center(child: _buildMainOrb(orbSize))),
        const SizedBox(height: 12),
        Expanded(flex: 4, child: _buildThoughtStream()),
        const SizedBox(height: 8),
        _buildInputBar(),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildDesktopLayout(double orbSize) {
    return Column(
      children: [
        _buildTopSystemInfo(),
        const SizedBox(height: 10),
        Expanded(child: Center(child: _buildMainOrb(orbSize))),
        const SizedBox(height: 10),
        Expanded(child: _buildThoughtStream()),
        const SizedBox(height: 8),
        _buildInputBar(),
        const SizedBox(height: 4),
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
            // Back to level selection
            GestureDetector(
              onTap: () async {
                await _stopAssistant();
                if (!mounted) return;
                final navigator = Navigator.of(context);
                if (navigator.canPop()) {
                  navigator.pop();
                  return;
                }
                navigator.pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const BootSequence(forceLevelSelect: true),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
            ),
            Text(
              "AURA",
              style: TextStyle(
                color: _textPrimary,
                fontSize: _isCompact ? 16 : (isSmallScreen ? 18 : 22),
                fontWeight: _isLight ? FontWeight.w400 : FontWeight.w300,
                letterSpacing: _isLight ? 2 : 3,
                shadows: [
                  Shadow(
                    color: _accent.withOpacity(_isLight ? 0.25 : 0.5),
                    blurRadius: _isLight ? 10 : 14,
                  )
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
                  onTap: () async {
                    final next = !_speakAnswers;
                    setState(() => _speakAnswers = next);
                    await PinStorage.setSpeakAnswers(next);
                    if (next) {
                      VoiceService.speak("Voice answers enabled");
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _speakAnswers
                          ? _accent.withOpacity(0.2)
                          : Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _speakAnswers
                            ? _accent.withOpacity(0.85)
                            : Colors.white24,
                      ),
                    ),
                    child: Icon(
                      _speakAnswers ? Icons.volume_up : Icons.volume_off,
                      color: _speakAnswers ? _accent : Colors.white54,
                      size: 16,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _showAiSettings,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.tune,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _showGuideDialog,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.help_outline,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _showExportSheet,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.download,
                      color: Colors.white70,
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
	              GestureDetector(
	                  onTap: () {},
	                  child: Container(
	                    padding: EdgeInsets.symmetric(
	                        horizontal: isSmallScreen ? 8 : 10,
	                        vertical: isSmallScreen ? 4 : 6),
	                    decoration: BoxDecoration(
	                      color: _isOnline
	                          ? Colors.green.withOpacity(0.1)
	                          : Colors.red.withOpacity(0.1),
	                      borderRadius: BorderRadius.circular(20),
	                      border: Border.all(
	                          color: _isOnline
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
	                              color: _isOnline ? Colors.green : Colors.red),
	                        ),
	                        const SizedBox(width: 4),
	                        Text(
	                          _isOnline
	                              ? (_aiEngine == 'groq'
	                                  ? 'Groq'
	                                  : _aiEngine == 'openai'
	                                      ? 'OpenAI'
	                                      : _aiEngine == 'gemini'
	                                          ? 'Gemini'
	                                          : _aiEngine == 'claude'
	                                              ? 'Claude'
	                                              : _aiEngine)
	                              : "offline",
	                          style: TextStyle(
	                              color: _isOnline ? Colors.green : Colors.red,
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
                  onTap: _toggleVoiceChat,
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
                                  _isListening
                                      ? Icons.hearing
                                      : (_selectedVoice == "female"
                                          ? Icons.female
                                          : Icons.male),
                                  color: Colors.white,
                                  size: orbSize * 0.08,
                                ),
                                if (_voiceChatEnabled && !_isSearching)
                                  Text(
                                    _isListening ? 'LISTENING' : 'VOICE',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: orbSize * 0.03,
                                      letterSpacing: 1.2,
                                    ),
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
    final messages = <({bool isUser, String text})>[];
    for (final item in _chatHistory) {
      final maybeUser = _extractUserText(item);
      if (maybeUser != null) {
        messages.add((isUser: true, text: maybeUser));
      } else {
        final assistant = _stripQuotePrefixes(item);
        if (assistant.isNotEmpty) {
          messages.add((isUser: false, text: assistant));
        }
      }
    }
    final currentAssistant = _stripQuotePrefixes(_currentAnswer).trim();
    final alreadyHasCurrent =
        messages.isNotEmpty && !messages.last.isUser && messages.last.text == currentAssistant;
    if (currentAssistant.isNotEmpty && !alreadyHasCurrent) {
      messages.add((isUser: false, text: currentAssistant));
    }

    return FadeTransition(
      opacity: _revealController,
      child: Column(
        mainAxisSize: MainAxisSize.max,
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
              IconButton(
                tooltip: 'New chat',
                icon: Icon(Icons.chat_bubble_outline, color: _textSub, size: 16),
                onPressed: () => _newConversation(keepContext: true),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Clear chat',
                icon: Icon(Icons.delete_outline, color: _textSub, size: 16),
                onPressed: _clearCurrentChat,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 6),
              if (_currentAnswer.isNotEmpty && !_currentAnswer.contains("⚠️"))
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.volume_up, color: _textSub, size: 14),
                      onPressed: () => VoiceService.speak(_currentAnswer),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
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
              // Engine status is shown in the top pill; don't show local model badges here.
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  width: double.infinity,
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
                  child: Scrollbar(
                    controller: _chatScrollController,
                    thumbVisibility: !isSmallScreen,
                    child: ListView.builder(
                      controller: _chatScrollController,
                      itemCount: messages.isEmpty ? 1 : messages.length,
                      itemBuilder: (ctx, index) {
                        if (messages.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              "Ready.",
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 13,
                                color: _codeTextColor,
                              ),
                            ),
                          );
                        }

                        final msg = messages[index];
                        final isUser = msg.isUser;
                        final bubbleColor = isUser
                            ? _userLevel.color
                                .withOpacity(_isLight ? 0.14 : 0.12)
                            : Colors.white.withOpacity(_isLight ? 0.55 : 0.06);
                        final align = isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft;
                        final textColor =
                            _isLight ? Colors.black87 : Colors.white70;
                        final isCodeLike = msg.text.contains('```') ||
                            RegExp(
                              r'[{}();<>]|==|!=|:=|=>|#include|class |def |import |SELECT ',
                              caseSensitive: false,
                            ).hasMatch(msg.text);

	                        final baseStyle = TextStyle(
	                          fontSize: isSmallScreen ? 12 : 13,
	                          fontFamily: isCodeLike ? 'monospace' : null,
	                          color: textColor,
	                          height: 1.5,
	                        );
	                        final linkStyle = baseStyle.copyWith(
	                          color: _userLevel.color,
	                          decoration: TextDecoration.underline,
	                        );

	                        return Align(
	                          alignment: align,
	                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            constraints: BoxConstraints(
                              maxWidth: isSmallScreen
                                  ? size.width * 0.86
                                  : size.width * 0.55,
                            ),
                            decoration: BoxDecoration(
                              color: bubbleColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white
                                    .withOpacity(_isLight ? 0.22 : 0.10),
                              ),
                            ),
	                            child: SelectableText.rich(
	                              TextSpan(
	                                children: _linkifySpans(
	                                  msg.text,
	                                  style: baseStyle,
	                                  linkStyle: linkStyle,
	                                ),
	                              ),
	                            ),
	                          ),
	                        );
	                      },
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
	          child: Column(
	            mainAxisSize: MainAxisSize.min,
	            children: [
	              if (_attachments.isNotEmpty) ...[
	                Padding(
	                  padding: const EdgeInsets.only(right: 10, top: 6, bottom: 2),
	                  child: SizedBox(
	                    width: double.infinity,
	                    child: SizedBox(
	                      height: isSmallScreen ? 34 : 38,
	                      child: Scrollbar(
	                        thumbVisibility: !isSmallScreen,
	                        child: SingleChildScrollView(
	                          scrollDirection: Axis.horizontal,
	                          child: Row(
	                            children: _attachments.map((a) {
	                              final avatar = a.isImage
	                                  ? CircleAvatar(
	                                      radius: 10,
	                                      backgroundImage: MemoryImage(a.bytes),
	                                      backgroundColor: Colors.transparent,
	                                    )
	                                  : const Icon(Icons.description,
	                                      size: 16, color: Colors.white70);
	                              return Padding(
	                                padding: const EdgeInsets.only(right: 6),
	                                child: InputChip(
	                                  materialTapTargetSize:
	                                      MaterialTapTargetSize.shrinkWrap,
	                                  labelPadding: const EdgeInsets.symmetric(
	                                      horizontal: 6),
	                                  avatar: avatar,
	                                  label: ConstrainedBox(
	                                    constraints: BoxConstraints(
	                                      maxWidth:
	                                          isSmallScreen ? 150 : 220,
	                                    ),
	                                    child: Text(
	                                      a.name,
	                                      style: TextStyle(
	                                        color: _textPrimary,
	                                        fontSize: isSmallScreen ? 10 : 11,
	                                      ),
	                                      overflow: TextOverflow.ellipsis,
	                                    ),
	                                  ),
	                                  onDeleted: () => _removeAttachment(a),
	                                  deleteIconColor: Colors.white54,
	                                  backgroundColor:
	                                      Colors.white.withOpacity(0.06),
	                                  side: BorderSide(color: _inputBorder),
	                                ),
	                              );
	                            }).toList(),
	                          ),
	                        ),
	                      ),
	                    ),
	                  ),
	                ),
	              ],
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.add_circle_outline,
                        color: _textSub, size: isSmallScreen ? 18 : 20),
                    onPressed: _isSearching ? null : _showAttachmentSheet,
                    tooltip: 'Attach photo or file',
                  ),
                  Expanded(
                    child: Shortcuts(
                      shortcuts: {
                        LogicalKeySet(
                          LogicalKeyboardKey.control,
                          LogicalKeyboardKey.enter,
                        ): const ActivateIntent(),
                        LogicalKeySet(
                          LogicalKeyboardKey.meta,
                          LogicalKeyboardKey.enter,
                        ): const ActivateIntent(),
                      },
                      child: Actions(
                        actions: {
                          ActivateIntent: CallbackAction<ActivateIntent>(
                            onInvoke: (_) {
                              _runSearch();
                              return null;
                            },
                          ),
                        },
                        child: TextField(
                          controller: _textController,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          minLines: 1,
                          maxLines: 6,
                          style: TextStyle(
                              color: _textPrimary,
                              fontSize: isSmallScreen ? 11 : 12),
                          decoration: InputDecoration(
                            hintText: "Type your message…",
                            hintStyle: TextStyle(
                                color: _textFaint,
                                fontSize: isSmallScreen ? 11 : 12),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: (_isSearching || _isSpeaking) ? _stopAssistant : _runSearch,
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
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : (_isSpeaking
                              ? Icon(Icons.stop_rounded,
                                  color: Colors.white,
                                  size: isSmallScreen ? 13 : 15)
                              : Icon(Icons.send_rounded,
                                  color: Colors.white,
                                  size: isSmallScreen ? 13 : 15)),
                    ),
                  ),
                ],
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
                        onTap: () async {
                          await _applySelectedLanguage(lang);
                        },
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
    final levelKey = widget.selectedLevel.name.toLowerCase();
    final levelCourses = _catalogCourses
        .where((c) => c.level == levelKey)
        .toList(growable: false)
      ..sort((a, b) => a.title.compareTo(b.title));
    final hasCatalog = levelCourses.isNotEmpty;
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
          if (!hasCatalog)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                "No courses found for this level.\n(Add them in assets/data/course_catalog.json)",
                style: TextStyle(
                  color: _textSub,
                  fontSize: isSmallScreen ? 7 : 8,
                ),
              ),
            ),
          ...List.generate(hasCatalog ? levelCourses.length : _userLevel.courses.length,
              (index) {
            final courseTitle =
                hasCatalog ? levelCourses[index].title : _userLevel.courses[index];
            final isSelected = _selectedCourse == courseTitle;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: GestureDetector(
                onTap: () => hasCatalog
                    ? _selectCatalogCourse(levelCourses[index])
                    : _selectCourse(courseTitle),
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
                          courseTitle.length > (isSmallScreen ? 12 : 20)
                              ? "${courseTitle.substring(0, isSmallScreen ? 12 : 20)}..."
                              : courseTitle,
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
