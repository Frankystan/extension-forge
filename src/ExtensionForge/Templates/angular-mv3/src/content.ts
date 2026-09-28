/// <reference types="chrome" />
import { sendExtensionMessage } from './app/models/messaging';
import { announceDevContentScript } from './dev/dev-reload';

// Content Script: se inyecta en la página visitada.
console.log('[ExtensionForge][content] Content script inyectado.');

// Avisa al background; este emite PAGE_VISITED a las superficies abiertas.
sendExtensionMessage('CONTENT_READY', []).catch(() => {
  // background no disponible (p. ej. durante una recarga): se ignora
});

// Otros mensajes tipados al background:
//   const info = await sendExtensionMessage('GET_INFO', []);
// Las preferencias se leen directamente (chrome.storage está disponible aquí):
//   import { loadSettings, onSettingsChanged } from './app/models/settings-store';
//   const { theme } = await loadSettings();

// Development: registra la pestaña para recargarla cuando se recargue la extensión
if (__EXTFORGE_DEV_RELOAD_PORT__) announceDevContentScript();
