# Examen Práctico de Unidad II · SI-988 Soluciones Móviles II

- **Estudiante:** 2020068763 · Mamani Valdivia Elvis
- **Docente:** Dr. Oscar Juan Jimenez Flores
- **Tipo de Examen Asignado:** **TIPO 4**
- **Repositorio:** `examen-u2`

### Historia de Usuario
> *«Como usuario de la app, quiero consultar mis datos sin conexión, sin que nadie pueda leerlos si copia los archivos de la app, los saca de un respaldo o mira la pantalla de aplicaciones recientes, y poder borrarlos del teléfono cuando quiera.»*

### Resumen de Cambios y Archivos Afectados

| Archivo Afectado | Cambio Realizado | Ítem Relacionado |
|---|---|---|
| [`pubspec.yaml`](pubspec.yaml) | Agregadas dependencias `cryptography` (AES-GCM), `flutter_secure_storage` (Keystore) y `path_provider`. | Ítems 1, 2, 4, 5 |
| [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml) | Configurado `android:allowBackup="false"` y `android:fullBackupContent="false"` para evitar fugas en respaldos. | Ítem 3 (Tarea 2) |
| [`MainActivity.kt`](android/app/src/main/kotlin/com/example/proyecto_moviles2_grupo03/MainActivity.kt) | Añadido `MethodChannel` (`com.example.pondera/seguridad`) para controlar `FLAG_SECURE` y ocultar la app en recientes / bloquear capturas. | Ítem 3 (Tarea 3) |
| [`lib/services/seguridad_storage_service.dart`](lib/services/seguridad_storage_service.dart) | Servicio de almacenamiento offline seguro con AES-GCM 256 bits, IV único por guardado, custodia de clave en Android Keystore, tolerancia a corrupción y borrado seguro. Soporta fakes para testing. | Ítems 1, 2, 4, 5 |
| [`lib/services/seguridad_pantalla_service.dart`](lib/services/seguridad_pantalla_service.dart) | Helper para comunicación con el canal nativo de `FLAG_SECURE`. | Ítem 3 (Tarea 3) |
| [`lib/screens/ciclos_screen.dart`](lib/screens/ciclos_screen.dart) | Botón «Guardar sin conexión», selector de modo claro/cifrado, botón «Borrar datos de este teléfono» y renderizado automático offline en modo avión. | Ítems 1, 2, 3 |
| [`test/offline_security_test.dart`](test/offline_security_test.dart) | Suite de 5 pruebas unitarias con fakes/mocks en memoria que validan cifrado, integridad, lectura vacía, tolerancia a fallos y borrado seguro. | Ítems 4 y 5 |

---

<div align="center">

<img src="../docs/readme/pondera-logo.svg" alt="Logo de Pondera" width="72" height="72">

# Pondera · Guía técnica

Documentación para desarrolladores del proyecto Flutter.<br>
La presentación general del proyecto (descripción, capturas, equipo) está en el
[README principal](../README.md).

</div>

---

## Contenido

- [Inicio rápido](#inicio-rápido)
- [Entorno](#entorno)
- [Comandos útiles](#comandos-útiles)
- [Organización del código](#organización-del-código)
- [Gestión del estado](#gestión-del-estado)
- [Firebase](#firebase)
- [Escáner de notas (OCR)](#escáner-de-notas-ocr)
- [Configuración de Android](#configuración-de-android)
- [Pruebas](#pruebas)
- [Convenciones de código](#convenciones-de-código)
- [Solución de problemas](#solución-de-problemas)

---

## Inicio rápido

```bash
flutter pub get
flutter devices          # usar --device-timeout 20 si el celular no aparece
flutter run              # modo debug en el dispositivo conectado
```

## Entorno

| Herramienta | Versión usada |
|---|---|
| Flutter | 3.41.5 (canal stable) |
| Dart | 3.11 (`sdk: ^3.11.3`) |
| Java (Gradle) | 17 |
| Android | `minSdk` de Flutter (ML Kit exige 21 o más) |
| Firebase CLI | 15.x (`cmd /c firebase` en PowerShell) |

La app está pensada para **Android**. Compila para web, pero el escáner muestra un aviso porque ML Kit
solo funciona en Android e iOS.

## Comandos útiles

| Tarea | Comando |
|---|---|
| Instalar dependencias | `flutter pub get` |
| Ejecutar en debug | `flutter run -d <dispositivo>` |
| Ejecutar en release | `flutter run --release` |
| Generar APK | `flutter build apk --release` |
| Análisis estático | `flutter analyze` (debe dar 0 issues) |
| Todas las pruebas | `flutter test` |
| Un archivo de pruebas | `flutter test test/lector_reporte_notas_test.dart` |
| Publicar reglas de Firestore | `firebase deploy --only firestore:rules` |
| Reconfigurar Firebase | `flutterfire configure --project=g03-sm2-promedioapp` |
| Regenerar el ícono de la app | `dart run flutter_launcher_icons` |

---

## Organización del código

```text
lib/
├── main.dart              # Firebase, tema y pantalla inicial según la sesión
├── firebase_options.dart  # Generado por FlutterFire
├── models/                # Datos de Firestore (toMap / fromMap)
├── providers/             # ComponentesProvider (calculadora rápida)
├── screens/               # Una pantalla por archivo
├── services/              # Acceso a Firestore y lógica pura de cálculo
├── theme/                 # AppTheme y EstadoNotaColors
├── utils/                 # FormatoNota, Validators
└── widgets/               # Componentes reutilizables del sistema de diseño
```

### Pantallas (`lib/screens/`)

| Archivo | Pantalla | Historia |
|---|---|---|
| `welcome_screen.dart` | Bienvenida con logo animado | H06 |
| `auth_screen.dart` | Inicio de sesión, registro y recuperación de contraseña | H05 |
| `verificar_correo_screen.dart` | Bloqueo hasta confirmar el correo | Verificación de correo |
| `home_screen.dart` | Calculadora rápida (con y sin cuenta) | H01, H07, H08 |
| `ciclos_screen.dart` | Tus ciclos y promedio acumulado | H10 |
| `cursos_screen.dart` | Cursos del ciclo y promedio del ciclo | H11 |
| `unidades_screen.dart` | Detalle del curso: nota final o parcial y unidades | H12, H14 |
| `tipos_evaluacion_screen.dart` | Tipos de evaluación, notas y simulador de unidad | H13, H15 |
| `simulador_screen.dart` | Simulador del curso con tarjeta interactiva | H16, H17, H18 |
| `escanear_notas_screen.dart` | Escáner: recorte, lectura y vista previa editable | H19 |
| `evolucion_screen.dart` | Gráficos por unidad y entre cursos | H20 |

### Servicios (`lib/services/`)

| Archivo | Responsabilidad | Usa Firebase |
|---|---|---|
| `calculadora_promedio.dart` | Promedio ponderado de la calculadora rápida | No |
| `calculos_evaluaciones.dart` | Promedio de tipos, nota de unidad y simulador de unidad | No |
| `calculos_multinivel.dart` | Cálculo tipo → unidad → curso, promedio parcial y % evaluado | No |
| `simulador_curso_service.dart` | Nota necesaria en las unidades pendientes | No |
| `datos_graficos.dart` | Puntos, barras, abreviaturas y avisos de los gráficos | No |
| `lector_reporte_notas.dart` | Reconstrucción de la tabla del reporte a partir del OCR | No |
| `calculos_service.dart` | Guardado de la calculadora (`calculos/actual`) | Sí |
| `ciclos_service.dart`, `cursos_service.dart`, `unidades_service.dart`, `evaluaciones_service.dart` | CRUD de cada nivel | Sí |
| `calculo_curso_service.dart` | Lee la jerarquía del curso en paralelo y aplica `CalculosMultinivel` | Sí |
| `borrado_cascada.dart` | Borra un curso o unidad con todas sus subcolecciones | Sí |
| `importacion_notas_service.dart` | Guarda lo escaneado (curso nuevo o unidades agregadas) | Sí |
| `escaner_notas.dart` | Cámara, recorte, ampliación y ML Kit | No (ML Kit local) |

> Regla del proyecto: **las fórmulas viven en las clases puras** de la tabla anterior. Las pantallas y
> los servicios de Firestore solo leen datos y llaman a esas clases.

### Widgets (`lib/widgets/`)

Componentes del sistema de diseño (DESIGN.md): `CardResultado` y `CardResultadoExpandida`,
`EscalaNota`, `ChipEstado`, `BarraPesos`, `LineaPesos`, `TarjetaCiclo`, `TarjetaCurso`,
`TarjetaUnidad`, `GrupoTipoEvaluacion`, `HojaNota`, `hoja_simulador_unidad`, `GraficoUnidades`,
`GraficoCursos`, `EstadoVacio`, `AppBarNivel`, `PonderaLogo`, `BordePunteado` y los diálogos compartidos
de `dialogos.dart`.

---

## Gestión del estado

- **Calculadora rápida:** `ComponentesProvider` (paquete `provider`). Guarda en Firestore con *debounce*
  de 1 segundo y solo si la cuenta tiene el correo verificado.
- **Historial académico:** cada pantalla es un `StatefulWidget` que abre sus streams de Firestore **una
  sola vez en `initState`** y los cierra en `dispose`. No crees streams dentro de `build`: provoca
  re-suscripciones y ciclos de reconstrucción (ver el arreglo de H13).
- **Cálculos:** se recalculan al volver de una pantalla hija, con *pull to refresh* y al cambiar la lista
  de unidades.

---

## Firebase

- **Proyecto:** `g03-sm2-promedioapp`.
- **Authentication:** correo y contraseña. `main.dart` envía a `VerificarCorreoScreen` toda sesión con el
  correo sin verificar.
- **Firestore:** base `(default)` en `southamerica-west1` (Santiago). Estructura documentada en
  [`docs/MODELO_DATOS_FIRESTORE.md`](docs/MODELO_DATOS_FIRESTORE.md).
- **Reglas** ([`firestore.rules`](firestore.rules)): cada usuario solo puede leer y escribir
  `usuarios/{uid}/**`, y solo con `email_verified == true`. Todo lo demás está cerrado.
- **Modo offline:** Firestore aplica las escrituras en el teléfono al instante y las sincroniza después.
  El escáner espera como máximo 12 segundos la confirmación del servidor y, si no llega, avisa que los
  datos quedaron en el teléfono.
- **Borrado:** Firestore no borra subcolecciones; usar siempre `BorradoCascada`.

---

## Escáner de notas (OCR)

Flujo: `image_picker` → `image_cropper` → ampliación si el ancho es menor a 1800 px (paquete `image`, en
otro isolate) → ML Kit Text Recognition → `LectorReporteNotas` → vista previa editable.

- La imagen **no sale del teléfono** y los archivos temporales se borran al terminar.
- En **modo debug**, `escaner_notas.dart` imprime cada palabra leída con su posición:

  ```text
  OCR_INICIO 57 palabras
  OCR 52,19,249,61,0.000|SOLUCIONES
  ...
  OCR_FIN
  ```

  Para convertir una lectura real en caso de prueba, copia las líneas `OCR ...` (sin el prefijo) a un
  archivo en `test/fixtures/` y cárgalo con `cargarLectura()` en `lector_reporte_notas_test.dart`.
  Este registro no existe en las compilaciones release.

---

## Configuración de Android

| Archivo | Qué contiene y por qué |
|---|---|
| `android/app/build.gradle.kts` | Java 17 y reglas de ProGuard en `release`. |
| `android/app/proguard-rules.pro` | `-dontwarn` para los reconocedores de chino, japonés, coreano y devanagari que ML Kit referencia pero la app no incluye. Sin esto el build release falla. |
| `android/app/src/main/AndroidManifest.xml` | Actividad `UCropActivity` del recortador de imágenes. |
| `android/app/google-services.json` | Configuración de Firebase para Android. |
| `android/app/src/main/res/mipmap-*` y `mipmap-anydpi-v26` | Ícono de la app generado por `flutter_launcher_icons` desde `assets/icon/` (ícono adaptativo: fondo `#3B36C4` y las barras del logo al centro). El nombre visible es `Pondera` (`android:label`). |

`image_picker` usa la cámara del sistema mediante un *intent*, por lo que no se declara el permiso
`CAMERA`. El modelo de ML Kit va incluido en la app y funciona sin Google Play Services.

---

## Pruebas

| Archivo | Pruebas | Qué cubre |
|---|---|---|
| `calculadora_promedio_test.dart` | 4 | Promedio ponderado, validación de pesos y aprobado |
| `calculos_evaluaciones_test.dart` | 17 | Promedio de tipos, nota de unidad y simulador de unidad (H13, H15) |
| `calculos_multinivel_test.dart` | 6 | Cálculo multinivel, información incompleta y promedio parcial (H14) |
| `simulador_aprobado_desaprobado_test.dart` | 4 | Tarjeta del simulador del curso (H18) |
| `simulador_screen_test.dart` | 4 | Interfaz del simulador (H17) |
| `datos_graficos_test.dart` | 9 | Series, barras, abreviaturas y avisos de los gráficos (H20) |
| `lector_reporte_notas_test.dart` | 28 | Lector del reporte con casos sintéticos y 7 lecturas reales de ML Kit (H19) |
| `widget_test.dart` | 1 | Calculadora rápida |
| **Total** | **73** | |

Las pruebas no necesitan Firebase. Si una pantalla crea servicios de Firestore, decláralos como
`late final` para que se instancien solo al usarse.

---

## Convenciones de código

- **Idioma:** nombres, comentarios y textos en español (`calcularPromedio`, `notaActual`).
- **Colores:** nunca hexadecimales sueltos en los widgets; usar `Theme.of(context).colorScheme` y
  `EstadoNotaColors.of(context)`.
- **Notas:** siempre con 1 decimal (`FormatoNota.nota`) y cifras tabulares (`AppTheme.estiloNota`). Sin
  nota se muestra "—".
- **Estado de una nota:** siempre ícono + texto + color, nunca solo color.
- **Accesibilidad:** botones de solo ícono con `tooltip`, `Semantics` en tarjetas y gráficos, áreas
  táctiles de al menos 48 px y respeto a `MediaQuery.disableAnimations`.
- **Antes de un PR:** `flutter analyze` sin issues y `flutter test` en verde.

---

## Solución de problemas

| Síntoma | Causa y solución |
|---|---|
| Se queda en "Guardando..." | El servidor no responde o la base no existe. Revisar en el log `W/Firestore`. La base `(default)` ya está creada; si se usa otro proyecto, crearla con `firebase firestore:databases:create`. |
| `PERMISSION_DENIED` en el log | La cuenta no verificó su correo o las reglas no están publicadas (`firebase deploy --only firestore:rules`). |
| `flutter devices` no muestra el celular | Activar la depuración USB y usar `flutter devices --device-timeout 20`. El `adb` del SDK está en la carpeta `platform-tools` del Android SDK configurado en Flutter. |
| Avisos `Could not close incremental caches` al compilar | Ocurren cuando el proyecto y la caché de Pub están en discos distintos (por ejemplo `D:` y `C:`). No detienen el build; se pueden ocultar con `kotlin.incremental=false` en `android/gradle.properties`. |
| El escáner no reconoce una captura | Recortar solo la tabla. Las capturas pequeñas se amplían solas; si persiste, revisar las líneas `OCR` del log. |
| Error de R8 en el build release | Verificar que `proguard-rules.pro` esté referenciado en `build.gradle.kts`. |
