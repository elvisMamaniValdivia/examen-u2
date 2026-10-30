# H19 - ML Kit Text Recognition.
# El plugin referencia los reconocedores de chino, devanagari, japones y coreano,
# pero la app solo incluye el de alfabeto latino. Sin estas reglas, R8 falla
# en el build release por clases faltantes.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
