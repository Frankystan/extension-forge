// ---------------------------------------------------------------------------
// Recarga en desarrollo (solo Development con Runtime.EnableHotReload).
// El background se conecta por WebSocket a scripts/dev-reload-server.mjs; al
// recibir RELOAD_EXTENSION recarga la extensión y, tras reiniciar, refresca
// las pestañas en las que se inyectó el content script.
// En Staging/Production el build define __EXTFORGE_DEV_RELOAD_PORT__ = 0: las
// llamadas van protegidas con `if (__EXTFORGE_DEV_RELOAD_PORT__)` en background.ts
// y content.ts, así esbuild elimina el módulo entero del bundle.
// ---------------------------------------------------------------------------

const LOG = '[ExtensionForge][dev-reload]';
const TABS_KEY = 'extforgeDevContentTabs';
const PENDING_KEY = 'extforgeDevPendingTabReload';
export const DEV_CONTENT_READY = 'EXTFORGE_DEV_CONTENT_READY';

/** Puerto del servidor de recarga o 0 si la recarga está desactivada en este build. */
export function devReloadPort(): number {
  return typeof __EXTFORGE_DEV_RELOAD_PORT__ !== 'undefined' ? __EXTFORGE_DEV_RELOAD_PORT__ : 0;
}

async function isUnpackedInstall(): Promise<boolean> {
  try {
    // 'development' = extensión cargada sin empaquetar (Chrome) o temporal (Firefox)
    return (await chrome.management.getSelf()).installType === 'development';
  } catch {
    return false;
  }
}

// storage.session: Chrome 102+ / Firefox 115+; si no existe se usa local
function sessionArea(): chrome.storage.StorageArea {
  return chrome.storage.session ?? chrome.storage.local;
}

async function rememberContentTab(tabId: number): Promise<void> {
  const stored = (await sessionArea().get(TABS_KEY))[TABS_KEY] as number[] | undefined;
  const tabs = new Set(stored ?? []);
  tabs.add(tabId);
  await sessionArea().set({ [TABS_KEY]: [...tabs] });
}

async function reloadExtension(): Promise<void> {
  // storage.session se pierde con runtime.reload(): las pestañas pasan a local
  const stored = (await sessionArea().get(TABS_KEY))[TABS_KEY] as number[] | undefined;
  await chrome.storage.local.set({ [PENDING_KEY]: stored ?? [] });
  await sessionArea().remove(TABS_KEY);
  console.log(`${LOG} RELOAD_EXTENSION recibido: recargando extensión.`);
  chrome.runtime.reload();
}

async function reloadPendingTabs(): Promise<void> {
  const pending = (await chrome.storage.local.get(PENDING_KEY))[PENDING_KEY] as number[] | undefined;
  if (!pending) return;
  await chrome.storage.local.remove(PENDING_KEY);
  for (const tabId of pending) {
    try {
      await chrome.tabs.reload(tabId);
    } catch {
      // la pestaña ya no existe
    }
  }
  if (pending.length > 0) console.log(`${LOG} ${pending.length} pestaña(s) con content script recargada(s).`);
}

function connect(port: number, attempt = 0): void {
  const socket = new WebSocket(`ws://127.0.0.1:${port}`);
  socket.addEventListener('open', () => {
    attempt = 0;
    console.log(`${LOG} conectado a ws://127.0.0.1:${port}`);
  });
  socket.addEventListener('message', (event) => {
    try {
      const data = JSON.parse(String(event.data)) as { type?: string };
      if (data.type === 'RELOAD_EXTENSION') void reloadExtension();
    } catch {
      // mensaje no JSON: se ignora
    }
  });
  socket.addEventListener('close', () => {
    // Reintento con espera creciente (máx. 10 s) mientras el servidor no esté arrancado
    const delay = Math.min(10_000, 500 * 2 ** attempt);
    setTimeout(() => connect(port, attempt + 1), delay);
  });
}

/** Arranca el cliente de recarga en el background (no hace nada fuera de Development). */
export async function startDevReload(): Promise<void> {
  const port = devReloadPort();
  if (!port || !(await isUnpackedInstall())) return;

  chrome.runtime.onMessage.addListener((message: unknown, sender) => {
    if ((message as { type?: string } | null)?.type === DEV_CONTENT_READY && sender.tab?.id !== undefined) {
      void rememberContentTab(sender.tab.id);
    }
    return false;
  });

  await reloadPendingTabs();
  connect(port);
}

/** Registra la pestaña actual para recargarla tras RELOAD_EXTENSION (content script). */
export function announceDevContentScript(): void {
  if (!devReloadPort()) return;
  chrome.runtime.sendMessage({ type: DEV_CONTENT_READY }).catch(() => {
    // background aún no disponible: la pestaña no se recargará automáticamente
  });
}
