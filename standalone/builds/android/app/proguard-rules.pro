# JUCE generates JNI bindings to com.rmsl.juce.*; keep them all.
-keep class com.rmsl.juce.** { *; }
-keep class audio.spectra.synth.** { *; }
-keepclasseswithmembernames class * { native <methods>; }
