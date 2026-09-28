/// <reference types="chrome" />
import { announceDevContentScript } from './dev/dev-reload';

// Content Script: se inyecta en la página visitada.
console.log('[ExtensionForge][content] Content script inyectado.');

// Para hablar con el background usa sendExtensionMessage (tipado):
//   import { sendExtensionMessage } from './app/models/messaging';
//   const info = await sendExtensionMessage('GET_INFO', []);

// Development: registra la pestaña para recargarla cuando se recargue la extensión
if (__EXTFORGE_DEV_RELOAD_PORT__) announceDevContentScript();
