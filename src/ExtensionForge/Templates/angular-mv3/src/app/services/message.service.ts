import { Injectable } from '@angular/core';
import { Observable, defer } from 'rxjs';
import { MessageType, PayloadArgs, ResponseOf } from '../models/messages.model';
import { SendOptions, sendExtensionMessage } from '../models/messaging';

/**
 * Comunicación tipada Popup/Options/SidePanel → Background.
 *
 *   const info = await this.messages.send('GET_INFO');
 *   this.messages.send$('ECHO', { text: 'hola' }).subscribe(r => ...);
 *
 * El tipo del payload y de la respuesta se deriva de MessageContract
 * (src/app/models/messages.model.ts). Los errores llegan como
 * ExtensionMessageError (sin receptor, error del handler o timeout).
 */
@Injectable({ providedIn: 'root' })
export class MessageService {
  /** Envía un mensaje y resuelve con la respuesta tipada. */
  send<K extends MessageType>(type: K, ...args: PayloadArgs<K>): Promise<ResponseOf<K>> {
    return sendExtensionMessage(type, args);
  }

  /** Igual que send(), con opciones (p. ej. timeoutMs). */
  sendWithOptions<K extends MessageType>(
    type: K,
    options: SendOptions,
    ...args: PayloadArgs<K>
  ): Promise<ResponseOf<K>> {
    return sendExtensionMessage(type, args, options);
  }

  /** Versión Observable (fría: envía el mensaje al suscribirse). */
  send$<K extends MessageType>(type: K, ...args: PayloadArgs<K>): Observable<ResponseOf<K>> {
    return defer(() => sendExtensionMessage(type, args));
  }
}
