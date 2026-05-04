# google_mlkit_text_recognition references optional script-specific recognizers
# as compileOnly dependencies. Suppress R8 warnings for the classes that are not
# packaged unless those scripts are explicitly added by the app.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder

# FlutterFire plugins referenced by GeneratedPluginRegistrant can trigger
# release shrinker failures on some builds. Keep and suppress warnings for
# these plugin entry points.
-keep class io.flutter.plugins.firebase.core.FlutterFirebaseCorePlugin { *; }
-keep class io.flutter.plugins.firebase.core.FlutterFirebasePlugin { *; }
-keep class io.flutter.plugins.firebase.core.FlutterFirebasePluginRegistry { *; }
-dontwarn io.flutter.plugins.firebase.core.FlutterFirebaseCorePlugin
-dontwarn io.flutter.plugins.firebase.core.FlutterFirebasePlugin
-dontwarn io.flutter.plugins.firebase.core.FlutterFirebasePluginRegistry
