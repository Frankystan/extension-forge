# Estado en chrome.storage (plantilla base)

La plantilla `angular-mv3` guarda las preferencias del usuario en `chrome.storage.local` y el popup las recupera cada vez que se abre. El popup es efímero: se destruye al cerrarse, así que el estado no puede vivir en memoria.

## Archivos

| Archivo | Papel |
|---|---|
| `src/app/models/settings.model.ts` | `Settings`, `DEFAULT_SETTINGS`, `SETTINGS_KEY` (`extforge.settings`) y `normalizeSettings()`, que devuelve siempre preferencias válidas aunque lo guardado sea antiguo o esté corrupto. |
| `src/app/models/settings-store.ts` | Sin Angular: `loadSettings`, `saveSettings`, `updateSettings`, `ensureSettings` y `onSettingsChanged`. Sirve al background y al content script. |
| `src/app/services/settings.service.ts` | `SettingsService`: signals `settings`, `loaded`, `error`; `update(patch)` y `reset()`; promesa `ready`. |
| `src/main.ts` | `provideAppInitializer(() => inject(SettingsService).ready)`: el popup se pinta ya con lo guardado, sin parpadeo. |
| `src/background.ts` | `onInstalled` → `ensureSettings()`: guarda los valores por defecto al instalar y migra al actualizar. |
| `src/app/app.component.*` | Ejemplo: tema (Sistema/Claro/Oscuro, aplicado con `color-scheme`) y un interruptor de notificaciones. |

## Flujo

1. Al abrir el popup, `SettingsService` lee `extforge.settings` antes del primer render.
2. `update()` cambia la interfaz al momento y escribe en `chrome.storage.local`; si la escritura falla, deshace el cambio y expone el error en `error()`.
3. Los cambios hechos desde otra superficie (options, background u otra pestaña de la extensión) llegan por `chrome.storage.onChanged` y actualizan el signal.

```typescript
protected readonly prefs = inject(SettingsService);

// plantilla: [checked]="prefs.settings().notifications"
void this.prefs.update({ notifications: false });
```

Desde el background o el content script:

```typescript
import { loadSettings, updateSettings, onSettingsChanged } from './app/models/settings-store';
const { theme } = await loadSettings();
const stop = onSettingsChanged((s) => console.log('nuevo tema', s.theme));
```

## Añadir una preferencia

1. Añade el campo a `Settings` y su valor a `DEFAULT_SETTINGS`.
2. Valídalo en `normalizeSettings()` (si el tipo no cuadra, usa el valor por defecto).
3. Compáralo en `sameSettings()`, para que `ensureSettings()` detecte datos desfasados.

Si cambias el formato de forma incompatible, sube `schemaVersion` y convierte los datos antiguos en `normalizeSettings()`. La prueba `tests/Integration/ExtensionForge-Settings.Tests.ps1` falla si un campo de `Settings` no tiene valor por defecto o validación.

## Límites

- Todo se guarda en una sola clave; `updateSettings()` lee y escribe, así que dos superficies que escriban a la vez pueden pisarse (gana la última).
- `chrome.storage.local` no se sincroniza entre equipos. Para eso usa `chrome.storage.sync`, que tiene cuotas bajas (unos 100 KB y 8 KB por elemento).
- La plantilla demo (ForgeNotes) mantiene su propio `ExtensionService`, que guarda el estado a través del background.

## Verificación

Hecha el 2026-09-28 en Chromium 1217 con un proyecto real (Angular 22):

- Tras instalar, `onInstalled` guarda `{ schemaVersion: 1, theme: 'system', notifications: true }`.
- Cambiar tema y notificaciones se guarda; al reabrir el popup se pinta ya en oscuro y con el interruptor desactivado.
- Un cambio escrito desde otra página de la extensión se refleja en vivo; datos corruptos (`theme: 'morado'`) se muestran con los valores por defecto.
- *Restablecer* vuelve a los valores por defecto. Sin errores en consola. Build y `Validate` de Production correctos.

Firefox no se ha probado en el navegador.
