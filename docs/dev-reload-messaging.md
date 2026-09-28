# Recarga en desarrollo y mensajería tipada

Guía de las dos piezas de la plantilla `angular-mv3` para el día a día: la recarga automática de la extensión al guardar y el `MessageService` tipado entre Angular y el background. La recarga también está en `angular-mv3-demo`; la demo mantiene su propio `ExtensionService`.

## Índice

- [Recarga en desarrollo](#recarga-en-desarrollo)
- [MessageService y contrato de mensajes](#messageservice-y-contrato-de-mensajes)
- [Proyectos creados antes de esta versión](#proyectos-creados-antes-de-esta-versión)
- [Verificación](#verificación)

## Recarga en desarrollo

```powershell
# En el directorio del proyecto de la extensión
../extension-forge/scripts/Start-ExtensionForgeDev.ps1 -Browser Chrome
```

1. Arranca `scripts/dev-reload-server.mjs` (WebSocket, solo en `127.0.0.1:35729`).
2. Compila en Development.
3. Vigila `src/` y `public/`; tras cada guardado (con 400 ms de agrupación, `-DebounceMs`) vuelve a compilar.
4. Cada build escribe `dist/extension/.build-complete`. El servidor lo detecta y envía `RELOAD_EXTENSION`.
5. El background (`src/dev/dev-reload.ts`) recarga la extensión con `chrome.runtime.reload()` y, al reiniciar, refresca con `chrome.tabs.reload()` las pestañas donde se inyectó el content script.

Carga `dist/extension/chrome` sin empaquetar **una vez**; después basta con guardar. `Ctrl+C` detiene el vigilante y el servidor. Si un build falla, el error se muestra y la extensión no se recarga hasta el siguiente build correcto.

| Pieza | Archivo | Detalle |
|---|---|---|
| Servidor | `scripts/dev-reload-server.mjs` (plantilla) | `ws`; puerto por argumento, `EXTFORGE_DEV_RELOAD_PORT` o 35729. También vale `npm run dev:reload` con builds manuales. |
| Cliente | `src/dev/dev-reload.ts` (plantilla) | Solo actúa si `chrome.management.getSelf().installType === 'development'` (sin empaquetar o temporal). Reintenta la conexión cada 0,5–10 s. |
| Pestañas | `announceDevContentScript()` en `content.ts` | El content script avisa al background; la lista se guarda en `storage.session` y pasa a `storage.local` justo antes de recargar. No requiere el permiso `tabs`. |
| Bucle | `scripts/Start-ExtensionForgeDev.ps1` (ExtensionForge) | `-Browser`, `-Port`, `-DebounceMs`, `-NoWatch` (un build y termina). |

### Qué incluye cada entorno

`Build-ExtensionForgeProject` pasa a esbuild `EXTFORGE_DEV_RELOAD_PORT`, que se convierte en la constante `__EXTFORGE_DEV_RELOAD_PORT__`:

| Entorno | `Runtime.EnableHotReload` | Constante | Cliente en el bundle |
|---|---|---|---|
| Development | `$true` | `Runtime.DevReloadPort` (35729) | Sí |
| Staging | `$false` | 0 | No |
| Production | forzado a no | 0 | No; `Validate` Production falla si detecta restos (`RELOAD_EXTENSION` o `[ExtensionForge][dev-reload]`) |

Las llamadas van protegidas con `if (__EXTFORGE_DEV_RELOAD_PORT__)` en `background.ts` y `content.ts`: con 0, esbuild elimina el módulo entero. Si cambias el puerto, hazlo en `Runtime.DevReloadPort` (la configuración por capas) para que build y servidor coincidan.

### Limitaciones

- El build es completo (Angular + esbuild, unos 5 s en la plantilla base); no es HMR de módulos.
- La recarga de content scripts refresca la pestaña (F5). La reinyección sin recargar sigue pendiente.
- Firefox no se ha probado en el navegador. Su CSP MV3 por defecto incluye `upgrade-insecure-requests`; si la conexión a `ws://127.0.0.1` fallara, usa `web-ext run`, que ya recarga en vivo.

## MessageService y contrato de mensajes

| Archivo | Papel |
|---|---|
| `src/app/models/messages.model.ts` | Contrato `MessageContract` (tipo → `request`/`response`), tipos derivados y `isExtensionRequest()`. `MESSAGE_TYPE_MAP` obliga a listar cada tipo. |
| `src/app/models/messaging.ts` | Sin Angular: `sendExtensionMessage()` (timeout 10 s, `ExtensionMessageError`) y `registerMessageHandlers()` para el background. |
| `src/app/services/message.service.ts` | Servicio inyectable: `send()` (Promise), `send$()` (Observable frío) y `sendWithOptions()`. |
| `src/background.ts` | `const handlers: MessageHandlers = { ... }`: uno por tipo; TypeScript avisa si falta alguno o si la respuesta no coincide. |

Uso desde un componente:

```typescript
private readonly messages = inject(MessageService);

const info = await this.messages.send('GET_INFO');           // ExtensionInfo
this.messages.send$('ECHO', { text: 'hola' }).subscribe(r => console.log(r.length));
```

Desde el content script (sin Angular):

```typescript
import { sendExtensionMessage } from './app/models/messaging';
const { pong } = await sendExtensionMessage('PING', []);
```

Añadir un mensaje:

1. Declara el tipo en `MessageContract` y en `MESSAGE_TYPE_MAP`.
2. Añade su handler en `background.ts` (el compilador lo exige).
3. Llámalo con `send('NUEVO', payload)`.

Las respuestas viajan envueltas (`{ ok: true, data }` o `{ ok: false, error }`): un handler que lanza no deja el popup esperando; `send()` rechaza con `ExtensionMessageError`. El listener solo responde a los tipos del contrato y devuelve `false` con el resto, así que convive con otros listeners (por ejemplo, el de recarga).

Pendiente: los mensajes proactivos Background → Popup (eventos) no forman parte todavía del servicio.

## Proyectos creados antes de esta versión

`Initialize` copia a un proyecto existente solo los archivos que faltan (`scripts/dev-reload-server.mjs`, `src/dev/*`, `src/app/models/*`, `src/app/services/message.service.ts`) y nunca sobrescribe `background.ts` ni `content.ts`. Después:

1. `npm install -D ws` y, si quieres, el script `"dev:reload": "node scripts/dev-reload-server.mjs"`.
2. Copia de la plantilla el bloque `define` de `scripts/build-extension.mjs`.
3. Añade al final de `background.ts` y `content.ts` las llamadas protegidas de la plantilla (`startDevReload()` / `announceDevContentScript()`).

## Verificación

Hecha el 2026-09-28 sobre un proyecto real creado con `Initialize` (Angular 22, Node 22) y Chromium 1217:

- Popup: `GET_INFO` y `PING` responden por `MessageService`; `ECHO` sin payload devuelve `{ ok: false, error }` en lugar de dejar el canal colgado.
- Recarga: escribir `.build-complete` recarga la extensión (el background se reconecta), la pestaña con content script se refresca y el content script se vuelve a inyectar.
- `Start-ExtensionForgeDev.ps1`: build inicial, recompilación tras editar `app.component.html`, error claro con el puerto ocupado, `Ctrl+C` detiene el servidor.
- Bundles: Development contiene el cliente; Staging y Production no, y `Validate` Production pasa.
