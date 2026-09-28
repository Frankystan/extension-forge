/// <reference types="chrome" />

// Background Service Worker (Chrome MV3) / Background Script (Firefox MV3)
import { MessageHandlers } from './app/models/messages.model';
import { registerMessageHandlers } from './app/models/messaging';
import { ensureSettings } from './app/models/settings-store';
import { startDevReload } from './dev/dev-reload';

chrome.runtime.onInstalled.addListener(({ reason }) => {
  if (reason === 'install') console.log('[ExtensionForge] Extensión instalada correctamente.');
  if (reason === 'update') console.log('[ExtensionForge] Extensión actualizada correctamente.');
  // Guarda las preferencias por defecto (instalación) o migra las existentes (actualización)
  void ensureSettings();
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
