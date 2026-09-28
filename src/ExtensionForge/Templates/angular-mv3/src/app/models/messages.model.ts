// ---------------------------------------------------------------------------
// Contrato de mensajes compartido por background, content script y Angular.
// Añade aquí cada mensaje nuevo: el tipado de MessageService.send() y de los
// handlers del background se deriva de esta interfaz.
// ---------------------------------------------------------------------------

/** Información básica de la extensión (respuesta de GET_INFO). */
export interface ExtensionInfo {
  name: string;
  version: string;
  browser: 'chrome' | 'firefox';
}

/**
 * Mapa tipo de mensaje → payload de la petición y respuesta.
 * `request: void` indica que el mensaje no lleva payload.
 */
export interface MessageContract {
  PING: { request: void; response: { pong: true; at: string } };
  GET_INFO: { request: void; response: ExtensionInfo };
  ECHO: { request: { text: string }; response: { text: string; length: number } };
  /** El content script avisa de que se ha cargado (el background emite PAGE_VISITED). */
  CONTENT_READY: { request: void; response: { registered: boolean } };
  /** Pide al background una notificación diferida (demuestra un evento proactivo). */
  REQUEST_NOTIFICATION: { request: { text: string; delayMs: number }; response: { scheduled: boolean } };
}

export type MessageType = keyof MessageContract;
export type RequestPayload<K extends MessageType> = MessageContract[K]['request'];
export type ResponseOf<K extends MessageType> = MessageContract[K]['response'];

/** Argumentos de send(): sin payload si request es void. */
export type PayloadArgs<K extends MessageType> =
  RequestPayload<K> extends void ? [] : [payload: RequestPayload<K>];

/** Petición tal como viaja por chrome.runtime.sendMessage. */
export type ExtensionRequest<K extends MessageType = MessageType> = K extends MessageType
  ? RequestPayload<K> extends void
    ? { type: K }
    : { type: K; payload: RequestPayload<K> }
  : never;

/** Respuesta envuelta: el background nunca lanza, devuelve ok/error. */
export type ExtensionResponse<K extends MessageType = MessageType> =
  | { ok: true; data: ResponseOf<K> }
  | { ok: false; error: string };

/** Handlers del background: uno por tipo de mensaje, síncronos o asíncronos. */
export type MessageHandlers = {
  [K in MessageType]: (
    payload: RequestPayload<K>,
    sender: chrome.runtime.MessageSender,
  ) => ResponseOf<K> | Promise<ResponseOf<K>>;
};

// Record<MessageType, true>: TypeScript obliga a listar aquí cada mensaje del contrato.
const MESSAGE_TYPE_MAP: Record<MessageType, true> = {
  PING: true,
  GET_INFO: true,
  ECHO: true,
  CONTENT_READY: true,
  REQUEST_NOTIFICATION: true,
};
const MESSAGE_TYPES: ReadonlySet<string> = new Set(Object.keys(MESSAGE_TYPE_MAP));

/** Comprueba en runtime que un mensaje recibido pertenece al contrato. */
export function isExtensionRequest(message: unknown): message is ExtensionRequest {
  return (
    typeof message === 'object' &&
    message !== null &&
    typeof (message as { type?: unknown }).type === 'string' &&
    MESSAGE_TYPES.has((message as { type: string }).type)
  );
}
