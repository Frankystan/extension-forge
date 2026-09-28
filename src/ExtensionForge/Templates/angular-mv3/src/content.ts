/// <reference types="chrome" />

// Content Script: se inyecta en la página visitada.
console.log('[ExtensionForge][content] Content script inyectado.');

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  console.log('[ExtensionForge][content] Mensaje recibido:', message);
  sendResponse({ ok: true });
});
