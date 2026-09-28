// ---------------------------------------------------------------------------
// Utilidades de mensajería sin Angular: las usan MessageService (popup), el
// content script y el background.
// ---------------------------------------------------------------------------
import {
  ExtensionRequest,
  ExtensionResponse,
  MessageHandlers,
  MessageType,
  PayloadArgs,
  ResponseOf,
  isExtensionRequest,
} from './messages.model';

/** Error de mensajería: incluye el tipo de mensaje que falló. */
export class ExtensionMessageError extends Error {
  constructor(
    readonly messageType: MessageType,
    message: string,
  ) {
    super(`[${messageType}] ${message}`);
    this.name = 'ExtensionMessageError';
  }
}

export interface SendOptions {
  /** Milisegundos antes de rechazar si el background no responde (por defecto 10 000). */
  timeoutMs?: number;
}

/**
 * Envía un mensaje tipado al background y devuelve `data` de la respuesta.
 * Rechaza con ExtensionMessageError si no hay receptor, si el handler falla o
 * si se agota el tiempo.
 */
export async function sendExtensionMessage<K extends MessageType>(
  type: K,
  args: PayloadArgs<K>,
  options: SendOptions = {},
): Promise<ResponseOf<K>> {
  const request = (args.length > 0 ? { type, payload: args[0] } : { type }) as ExtensionRequest<K>;
  const timeoutMs = options.timeoutMs ?? 10_000;

  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(
      () => reject(new ExtensionMessageError(type, `sin respuesta tras ${timeoutMs} ms`)),
      timeoutMs,
    );
  });

  try {
    const response = (await Promise.race([
      chrome.runtime.sendMessage(request),
      timeout,
    ])) as ExtensionResponse<K> | undefined;

    if (!response) {
      throw new ExtensionMessageError(type, 'el background no devolvió respuesta');
    }
    if (!response.ok) {
      throw new ExtensionMessageError(type, response.error);
    }
    return response.data;
  } catch (err) {
    if (err instanceof ExtensionMessageError) throw err;
    throw new ExtensionMessageError(type, err instanceof Error ? err.message : String(err));
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Registra los handlers del background. Solo responde a los mensajes del
 * contrato (devuelve false con el resto para no bloquear otros listeners) y
 * envuelve cada resultado en { ok, data } / { ok, error }.
 */
export function registerMessageHandlers(handlers: MessageHandlers): void {
  chrome.runtime.onMessage.addListener((message: unknown, sender, sendResponse) => {
    if (!isExtensionRequest(message)) {
      return false;
    }
    const handler = handlers[message.type] as (
      payload: unknown,
      sender: chrome.runtime.MessageSender,
    ) => unknown;
    const payload = 'payload' in message ? message.payload : undefined;

    Promise.resolve()
      .then(() => handler(payload, sender))
      .then(
        (data) => sendResponse({ ok: true, data }),
        (err: unknown) =>
          sendResponse({ ok: false, error: err instanceof Error ? err.message : String(err) }),
      );
    return true; // canal abierto para la respuesta asíncrona
  });
}
