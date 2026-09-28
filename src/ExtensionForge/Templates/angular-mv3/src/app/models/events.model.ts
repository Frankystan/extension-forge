// ---------------------------------------------------------------------------
// Contrato de eventos proactivos Background → Popup/Options/SidePanel.
// A diferencia de MessageContract (petición → respuesta), aquí el background
// emite por iniciativa propia y las superficies abiertas lo reciben.
// Añade aquí cada evento nuevo; emit() y MessageService.on$() se tipan solos.
// ---------------------------------------------------------------------------

export type NotificationLevel = 'info' | 'warning' | 'error';

/** Mapa tipo de evento → payload. */
export interface EventContract {
  /** Una pestaña ha cargado el content script. */
  PAGE_VISITED: { tabId: number; url: string };
  /** Aviso para el usuario (solo si la preferencia `notifications` está activa). */
  NOTIFICATION: { level: NotificationLevel; text: string };
}

export type EventType = keyof EventContract;
export type EventPayload<K extends EventType> = EventContract[K];

/** Evento tal como viaja por el puerto. `at`: ISO 8601 del momento de emisión. */
export type ExtensionEvent<K extends EventType = EventType> = K extends EventType
  ? { type: K; payload: EventContract[K]; at: string }
  : never;

/** Nombre del puerto chrome.runtime.connect() que usan las superficies. */
export const EVENTS_PORT = 'extforge-events';

// Record<EventType, true>: TypeScript obliga a listar aquí cada evento del contrato.
const EVENT_TYPE_MAP: Record<EventType, true> = { PAGE_VISITED: true, NOTIFICATION: true };
const EVENT_TYPES: ReadonlySet<string> = new Set(Object.keys(EVENT_TYPE_MAP));

/** Comprueba en runtime que un mensaje del puerto es un evento del contrato. */
export function isExtensionEvent(value: unknown): value is ExtensionEvent {
  return (
    typeof value === 'object' &&
    value !== null &&
    typeof (value as { type?: unknown }).type === 'string' &&
    EVENT_TYPES.has((value as { type: string }).type) &&
    'payload' in value
  );
}
