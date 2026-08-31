# Trayectos

App iOS nativa para importar un `location-history.json` exportado de Google Maps Timeline y ver varios días de recorrido juntos en un único mapa.

El archivo se procesa localmente en el dispositivo. No usa Google Maps API, Google Cloud, API keys ni un servidor propio. MapKit puede necesitar conexión para descargar la cartografía base; el historial JSON nunca se envía a ningún servicio de esta app.

## Qué incluye

- Importación desde Files con el selector nativo de iOS.
- Parser tolerante para `startTime`, `endTime`, `timelinePath.point` y `durationMinutesOffsetFromStartTime` como texto o número.
- Lectura opcional de segmentos `activity` y `visit` cuando están presentes.
- Selector de fechas Desde/Hasta.
- Un mapa único con zoom automático.
- Cada `timelinePath` se conserva como bloque independiente: no se dibujan líneas artificiales entre bloques separados.
- Color y toggle independiente para cada día.
- Estadísticas de días visibles, puntos GPS y distancia aproximada.
- Interfaz SwiftUI inspirada en Material Design, adaptada a los patrones de iOS.
- Pruebas unitarias del formato observado en el JSON real.

## Requisitos

- macOS con Xcode 15 o posterior.
- iOS 16 o posterior.
- Un archivo `location-history.json` exportado desde Google Maps Timeline.

## Abrir y ejecutar

1. Cloná o descargá este repositorio en una Mac.
2. Abrí `Trayectos.xcodeproj` con Xcode.
3. Seleccioná el target **Trayectos** y entrá en **Signing & Capabilities**.
4. Elegí tu Apple Developer Team y reemplazá `com.yourname.Trayectos` por un Bundle Identifier único.
5. Elegí tu iPhone como destino y presioná **Run**.

La app no pide permiso de ubicación porque no rastrea el teléfono: solo lee el archivo que elegís manualmente.

## Generar una IPA para sideload

La firma depende de la cuenta y del método de sideload, por eso no se guarda ningún certificado en el repositorio.

1. En Xcode elegí un dispositivo real o **Any iOS Device (arm64)**.
2. Usá **Product → Archive**.
3. En Organizer elegí **Distribute App** y el método compatible con tu cuenta (Development, Ad Hoc o Custom).
4. Exportá la IPA firmada y cargala con la herramienta de sideload que ya uses.

Para una cuenta gratuita, Xcode también puede instalar directamente la app en el iPhone; Apple aplica sus límites habituales de vigencia y dispositivos.

## Privacidad

`location-history.json` puede revelar domicilio, trabajo y movimientos. Está ignorado por `.gitignore`; no lo agregues al repositorio. Para pruebas públicas usá el ejemplo sanitizado de `Examples/sample-location-history.json`.

## Cómo se calcula la distancia

La app suma la distancia geodésica entre puntos consecutivos **dentro de cada bloque**. No conecta el final de un bloque con el inicio del siguiente. Es una referencia aproximada: si Google dejó huecos o tomó pocos puntos, la polilínea corta curvas y puede subestimar la distancia real por ruta.

## Estructura

```text
Trayectos/
├── Trayectos.xcodeproj
├── Trayectos/
│   ├── App
│   ├── Models
│   ├── Services
│   ├── Utilities
│   ├── Views
│   └── Resources
├── TrayectosTests
├── Examples
└── .github/workflows
```

## Compilación en GitHub

El workflow incluido compila el proyecto, ejecuta las pruebas en un simulador iOS y publica `Trayectos-unsigned.ipa` como artefacto descargable. Esa IPA sin firma sirve para validar el build, pero no se puede instalar directamente: una IPA instalable requiere un certificado y provisioning profile de Apple, y se genera localmente siguiendo los pasos anteriores o agregando esas credenciales como secretos de GitHub Actions.
