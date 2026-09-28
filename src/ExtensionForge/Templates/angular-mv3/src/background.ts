/// <reference types="chrome" />

// Background Service Worker (Chrome MV3) / Background Script (Firefox MV3)
import { MessageHandlers } from './app/models/messages.model';
import { registerMessageHandlers } from './app/models/messaging';
import { startDevReload } from './dev/dev-reload';

chrome.runtime.onInstalled.addListener(() => {
  console.log('[ExtensionForge] Extensión instalada correctamente.');
});

// Un handler por mensaje de MessageContract (src/app/models/messages.model.ts).
// TypeScript avisa si falta alguno o si la respuesta no coincide con el contrato.
const handlers: MessageHandlers = {
  PING: () => ({ pong: true, at: new Date().toISOString() }),
  GET_INFO: () => {
    const manifest = chrome.runtime.getManifest();
    return {
      name: manifest.name,
      version: manifest.version,
      browser: 'browser_specific_settings' in manifest ? 'firefox' : 'chrome',
    };
  },
  ECHO: ({ text }) => ({ text, length: text.length }),
};

registerMessageHandlers(handlers);

// Recarga automática en Development (eliminada del bundle en Staging/Production)
if (__EXTFORGE_DEV_RELOAD_PORT__) void startDevReload();
