# Flutter and plugin entry points are kept by their own consumer rules.
# flutter_gemma / LiteRT-LM load native libraries and reflect on model config classes.
-keep class com.google.ai.edge.** { *; }
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.auto.value.**
-dontwarn com.google.mediapipe.proto.**
-dontwarn org.tensorflow.lite.**
