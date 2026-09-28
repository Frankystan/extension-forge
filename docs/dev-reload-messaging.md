# Recarga en desarrollo y mensajería tipada

Guía de las dos piezas de la plantilla `angular-mv3` para el día a día: la recarga automática de la extensión al guardar y el `MessageService` tipado entre Angular y el background. La recarga también está en `angular-mv3-demo`; la demo mantiene su propio `ExtensionService`.

## Índice

- [Recarga en desarrollo](#recarga-en-desarrollo)
- [MessageService y contrato de mensajes](#messageservice-y-contrato-de-mensajes)
- [Eventos Background → Popup](#eventos-background--popup)
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

Las preferencias persistentes no pasan por mensajes: ver [storage.md](storage.md).

## Eventos Background → Popup

Además de petición → respuesta, el background puede avisar por iniciativa propia a las superficies abiertas (popup, options, side panel).

| Archivo | Papel |
|---|---|
| `src/app/models/events.model.ts` | Contrato `EventContract` (tipo → payload), `ExtensionEvent`, `EVENTS_PORT` e `isExtensionEvent()`. `EVENT_TYPE_MAP` obliga a listar cada evento. |
| `src/app/models/events.ts` | Sin Angular: `createEventHub()` para el background (`emit`, `connections`, `replay`) y `subscribeToEvents()` para las superficies (reconexión automática). |
| `MessageService` | `events$` (todos los eventos, un único puerto compartido) y `on$(tipo)` (payload tipado + `at`). |

Transporte: cada superficie abre un puerto con `chrome.runtime.connect({ name: 'extforge-events' })` y el background emite por los puertos abiertos. Con el popup cerrado no hay puertos y `emit()` no hace nada, sin los errores «Receiving end does not exist» de `runtime.sendMessage`. El background cierra los puertos que no vienen de páginas de la propia extensión (por ejemplo, de un content script).

```typescript
// Componente
readonly lastVisit = toSignal(this.messages.on$('PAGE_VISITED'), { initialValue: null });
this.messages.on$('NOTIFICATION').pipe(takeUntilDestroyed()).subscribe((n) => ...);

// background.ts
const events = createEventHub({ replay: ['PAGE_VISITED'] });
events.emit('NOTIFICATION', { level: 'info', text: 'Hecho' });
```

Ejemplos de la plantilla:

| Evento | Cuándo se emite |
|---|---|
| `PAGE_VISITED` | El content script envía `CONTENT_READY` al cargar una página; el background emite la URL y la pestaña (`sender.url`, sin permiso `tabs`). Con `replay`, el popup la recibe también al abrirse. |
| `NOTIFICATION` | El popup pide `REQUEST_NOTIFICATION` y el background la emite 2 s después, solo si la preferencia `notifications` está activa. |

Añadir un evento:

1. Declara el tipo y su payload en `EventContract` y en `EVENT_TYPE_MAP`.
2. Emítelo en el background con `events.emit('TIPO', payload)`.
3. Suscríbete en la superficie con `on$('TIPO')`.

Límites:

- Los eventos emitidos con el popup cerrado se pierden; lo que deba sobrevivir va a `chrome.storage` ([storage.md](storage.md)).
- El valor de `replay` vive en memoria: se pierde si el navegador detiene el service worker.
- Los content scripts no reciben estos eventos (el canal es solo para páginas de la extensión); para ellos, `chrome.tabs.sendMessage`.

## Proyectos creados antes de esta versión

`Initialize` copia a un proyecto existente solo los archivos que faltan (`scripts/dev-reload-server.mjs`, `src/dev/*`, `src/app/models/*`, `src/app/services/message.service.ts`) y nunca sobrescribe `background.ts` ni `content.ts`. Después:

1. `npm install -D ws` y, si quieres, el script `"dev:reload": "node scripts/dev-reload-server.mjs"`.
2. Copia de la plantilla el bloque `define` de `scripts/build-extension.mjs`.
3. Añade al final de `background.ts` y `content.ts` las llamadas protegidas de la plantilla (`startDevReload()` / `announceDevContentScript()`).

## Verificación

Hecha el 2026-09-28 sobre un proyecto real creado con `Initialize` (Angular 22, Node 22) y Chromium 1217:

- Popup: `GET_INFO` y `PING` responden por `MessageService`; `ECHO` sin payload devuelve `{ ok: false, error }` en lugar de dejar el canal colgado.
- Eventos: el popup abierto recibe `PAGE_VISITED` al abrir una web y `NOTIFICATION` a los 2 s (no antes); con las notificaciones desactivadas no llega ninguna; al reabrir el popup recibe la última página visitada; dos superficies abiertas reciben el mismo evento; tras detener el service worker (se pierde el `replay`), el popup se reconecta y sigue recibiendo eventos. Sin errores ni avisos en consola.
- Recarga: escribir `.build-complete` recarga la extensión (el background se reconecta), la pestaña con content script se refresca y el content script se vuelve a inyectar.
- `Start-ExtensionForgeDev.ps1`: build inicial, recompilación tras editar `app.component.html`, error claro con el puerto ocupado, `Ctrl+C` detiene el servidor.
- Bundles: Development contiene el cliente; Staging y Production no, y `Validate` Production pasa.
