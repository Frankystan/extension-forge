// ---------------------------------------------------------------------------
// Canal de eventos Background → superficies de la extensión, sin Angular.
//
// Las superficies (popup, options, side panel) abren un puerto con
// chrome.runtime.connect({ name: EVENTS_PORT }); el background guarda los
// puertos abiertos y emite por ellos. Con el popup cerrado no hay puertos y
// emit() no hace nada (sin errores "Receiving end does not exist").
// ---------------------------------------------------------------------------
import { EVENTS_PORT, EventPayload, EventType, ExtensionEvent, isExtensionEvent } from './events.model';

export interface EventHub {
  /** Envía un evento a todas las superficies conectadas. Devuelve cuántas lo recibieron. */
  emit<K extends EventType>(type: K, payload: EventPayload<K>): number;
  /** Número de superficies conectadas ahora mismo. */
  connections(): number;
}

export interface EventHubOptions {
  /**
   * Tipos cuyo último valor se reenvía a cada superficie al conectarse (por
   * ejemplo, para que el popup muestre la última página visitada al abrirse).
   * Se guarda en memoria: se pierde si el navegador detiene el service worker.
   */
  replay?: readonly EventType[];
}

function isExtensionPage(port: chrome.runtime.Port): boolean {
  const sender = port.sender;
  // Solo páginas propias (popup, options, side panel), nunca content scripts de webs
  return sender?.id === chrome.runtime.id && !!sender.url?.startsWith(chrome.runtime.getURL(''));
}

/** Background: crea el emisor de eventos (llámalo una sola vez, al arrancar). */
export function createEventHub(options: EventHubOptions = {}): EventHub {
  const ports = new Set<chrome.runtime.Port>();
  const replay = new Set<EventType>(options.replay ?? []);
  const last = new Map<EventType, ExtensionEvent>();

  chrome.runtime.onConnect.addListener((port) => {
    if (port.name !== EVENTS_PORT) return;
    if (!isExtensionPage(port)) {
      port.disconnect();
      return;
    }
    ports.add(port);
    port.onDisconnect.addListener(() => ports.delete(port));
    for (const event of last.values()) port.postMessage(event);
  });

  return {
    emit(type, payload) {
      const event = { type, payload, at: new Date().toISOString() } as ExtensionEvent;
      if (replay.has(type)) last.set(type, event);
      let delivered = 0;
      for (const port of ports) {
        try {
          port.postMessage(event);
          delivered++;
        } catch {
          ports.delete(port); // puerto cerrado entre medias
        }
      }
      return delivered;
    },
    connections: () => ports.size,
  };
}

export interface EventSubscription {
  /** Cierra el puerto y deja de reconectar. */
  close(): void;
}

/**
 * Superficie (popup, options...): recibe los eventos del background.
 * Si el puerto se cierra porque el navegador reinicia el service worker, se
 * vuelve a conectar (espera creciente de 100 ms a 5 s) hasta llamar a close().
 */
export function subscribeToEvents(listener: (event: ExtensionEvent) => void): EventSubscription {
  let port: chrome.runtime.Port | null = null;
  let closed = false;
  let attempt = 0;
  let timer: ReturnType<typeof setTimeout> | undefined;

  const connect = () => {
    if (closed) return;
    try {
      port = chrome.runtime.connect({ name: EVENTS_PORT });
    } catch {
      scheduleReconnect(); // contexto invalidado o background no disponible
      return;
    }
    port.onMessage.addListener((message: unknown) => {
      attempt = 0;
      if (isExtensionEvent(message)) listener(message);
    });
    port.onDisconnect.addListener(() => {
      void chrome.runtime.lastError; // evita el aviso "Unchecked runtime.lastError"
      port = null;
      scheduleReconnect();
    });
  };

  const scheduleReconnect = () => {
    if (closed) return;
    const delay = Math.min(5_000, 100 * 2 ** attempt++);
    timer = setTimeout(connect, delay);
  };

  connect();
  return {
    close() {
      closed = true;
      clearTimeout(timer);
      port?.disconnect();
      port = null;
    },
  };
}
