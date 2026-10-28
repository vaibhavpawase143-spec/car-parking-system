# ProGuard / R8 rules for car_parking_system

# Google ML Kit Text Recognition optional script recognizers:
# The google_mlkit_text_recognition Flutter plugin's TextRecognizer.java contains switch cases
# referencing Chinese, Devanagari, Japanese, and Korean TextRecognizerOptions.
# By design, Google ML Kit distributes these scripts as separate modular AAR dependencies so apps
# only package the language models they use.
# Since this application recognizes Indian vehicle registration numbers using Latin script
# (TextRecognitionScript.latin), the optional non-Latin script artifacts are intentionally not bundled.
# The following exact rules (recommended by Android Gradle Plugin in missing_rules.txt)
# instruct R8 that these optional classes are intentionally absent, without disabling minification
# or using broad wildcard suppressions.

-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
