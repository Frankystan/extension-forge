/// <reference types="chrome" />

// Background Service Worker (Chrome MV3) / Background Script (Firefox MV3)
import { MessageHandlers } from './app/models/messages.model';
import { registerMessageHandlers } from './app/models/messaging';
import { ensureSettings, loadSettings } from './app/models/settings-store';
import { createEventHub } from './app/models/events';
import { startDevReload } from './dev/dev-reload';

chrome.runtime.onInstalled.addListener(({ reason }) => {
  if (reason === 'install') console.log('[ExtensionForge] Extensión instalada correctamente.');
  if (reason === 'update') console.log('[ExtensionForge] Extensión actualizada correctamente.');
  // Guarda las preferencias por defecto (instalación) o migra las existentes (actualización)
  void ensureSettings();
});

// Eventos proactivos hacia popup/options/side panel (EventContract, events.model.ts).
// El popup abierto recibe al conectarse la última página visitada.
const events = createEventHub({ replay: ['PAGE_VISITED'] });

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
  CONTENT_READY: (_payload, sender) => {
    const tabId = sender.tab?.id;
    if (tabId === undefined || !sender.url) return { registered: false };
    events.emit('PAGE_VISITED', { tabId, url: sender.url });
    return { registered: true };
  },
  REQUEST_NOTIFICATION: ({ text, delayMs }) => {
    const delay = Math.min(Math.max(0, delayMs), 30_000);
    setTimeout(() => {
      void loadSettings().then(({ notifications }) => {
        // Respeta la preferencia guardada en chrome.storage.local
        if (notifications) events.emit('NOTIFICATION', { level: 'info', text });
      });
    }, delay);
    return { scheduled: true };
  },
};

registerMessageHandlers(handlers);

// Recarga automática en Development (eliminada del bundle en Staging/Production)
if (__EXTFORGE_DEV_RELOAD_PORT__) void startDevReload();
