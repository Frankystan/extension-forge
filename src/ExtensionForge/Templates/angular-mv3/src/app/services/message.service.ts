import { Injectable } from '@angular/core';
import { Observable, defer, filter, map, share } from 'rxjs';
import { MessageType, PayloadArgs, ResponseOf } from '../models/messages.model';
import { SendOptions, sendExtensionMessage } from '../models/messaging';
import { EventPayload, EventType, ExtensionEvent } from '../models/events.model';
import { subscribeToEvents } from '../models/events';

/**
 * Comunicación tipada con el background.
 *
 * Petición → respuesta (Popup/Options/SidePanel → Background):
 *   const info = await this.messages.send('GET_INFO');
 *   this.messages.send$('ECHO', { text: 'hola' }).subscribe(r => ...);
 *
 * Eventos proactivos (Background → superficies abiertas):
 *   this.messages.on$('NOTIFICATION').subscribe(({ text }) => ...);
 *
 * Los tipos se derivan de MessageContract (messages.model.ts) y de
 * EventContract (events.model.ts). Los errores de send() llegan como
 * ExtensionMessageError (sin receptor, error del handler o timeout).
 */
@Injectable({ providedIn: 'root' })
export class MessageService {
  /**
   * Todos los eventos del background. Un único puerto compartido: se abre con
   * la primera suscripción y se cierra al cancelar la última.
   */
  readonly events$: Observable<ExtensionEvent> = new Observable<ExtensionEvent>((subscriber) => {
    const subscription = subscribeToEvents((event) => subscriber.next(event));
    return () => subscription.close();
  }).pipe(share());

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

  /** Eventos de un tipo concreto, con su payload tipado y el instante de emisión. */
  on$<K extends EventType>(type: K): Observable<EventPayload<K> & { at: string }> {
    return this.events$.pipe(
      filter((event): event is ExtensionEvent<K> => event.type === type),
      map((event) => ({ ...(event.payload as EventPayload<K>), at: event.at })),
    );
  }
}
