# VoiceDubAI 3 — Apple Glass

## Qué cambia
- Interfaz clara inspirada en la app Traducir de Apple, con superficies translúcidas tipo Liquid Glass.
- Dos modos: Traductor de texto y modo Películas.
- Selector de idiomas con búsqueda, modal y lista legible.
- Apple Foundation Models como motor principal, en el dispositivo y sin descargar pesos adicionales, cuando esté disponible. Requiere iOS 26+ y dispositivo compatible con Apple Intelligence.
- Qwen3-0.6B Q4_K_M como alternativa descargable bajo demanda. Archivo oficial de Qwen: `Qwen3-0.6B-Q4_K_M.gguf`, 397 MB en la revisión consultada, SHA-256 `b0638f08417a2d3c8652760462eb5407c6e30173cf9608ad0820757a281eea0e`.
- Caché de recursos de voz con expiración a los 50 minutos y borrado completo si supera 20 MB.

## Importante sobre las voces
Este proyecto prepara la caché temporal y la interfaz de gestión, pero **no implementa todavía la clonación neuronal de voces ni la diarización automática de hablantes**. Actualmente la lectura usa voces instaladas en iOS. Para clonar y cambiar entre voces de diferentes actores se necesita integrar y validar un modelo específico de separación/identificación de hablantes y síntesis o conversión de voz; no basta con Foundation Models ni con Qwen. La app no afirma imitar a los actores en esta versión.

## Compilar
1. Sube el contenido de esta carpeta a la raíz del repositorio GitHub. Incluye `.github` y `modules`.
2. Abre Actions y ejecuta `Build VoiceDubAI iOS IPA`.
3. Descarga el artefacto `VoiceDubAI-AppleGlass-unsigned-ipa` y firma el IPA con Sideloadly o AltStore.

## Compatibilidad y límites
- El módulo nativo Foundation Models usa APIs de iOS 26. El runner usa macOS 26/Xcode reciente.
- Si Apple Foundation Models no está disponible en el dispositivo o para el idioma elegido, puedes descargar y cargar Qwen desde `Motor alternativo`.
- La traducción de Qwen no garantiza 190 idiomas. El reconocimiento offline depende de los idiomas/modelos de voz disponibles en iOS.
- El audio de otras apps no se puede capturar directamente con el micrófono de la app; el modo películas escucha sonido externo.

## Estado de validación
El ZIP contiene el código fuente; no se ha ejecutado todavía en GitHub Actions ni probado en un iPhone real. Si falla la compilación, comparte el registro completo de Actions.


## Fix 3.0.1: white screen on launch

This build registers both local Expo modules with their own `package.json` files and uses optional native-module loading so a missing native module does not immediately crash the React screen. A React error boundary also displays the actual JS render error instead of leaving a blank white screen. Upload the complete project, including `modules/` and `.github/`, and build a new IPA.

If the app now shows an error message, take a screenshot or copy the text; that message will identify the next issue.


## Fix 3.0.2: diagnóstico de Foundation Models y verificación de módulos
- La app muestra el motivo devuelto por `SystemLanguageModel.default.availability` en lugar de mostrar solo “no disponible”.
- El workflow verifica que los diez archivos críticos de los módulos locales estén en el repositorio y que CocoaPods genere los podspecs de `AppleFoundationTranslator` y `VoiceCache`. La compilación falla con un mensaje claro si faltan.
- Sube siempre la carpeta `modules/` completa, incluido `MODULES_REQUIRED.txt`, junto con `.github/`.
- Apple Foundation Models puede no estar listo aunque el iPhone sea compatible: requiere Apple Intelligence activado, modelos del sistema descargados y un idioma compatible. La app mostrará el motivo que reporte iOS.

No se ha ejecutado GitHub Actions desde este entorno; el workflow debe ejecutarse en tu repositorio para producir el IPA nuevo.
