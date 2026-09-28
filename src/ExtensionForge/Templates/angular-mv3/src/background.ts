/// <reference types="chrome" />

// Background Service Worker (Chrome MV3) / Background Script (Firefox MV3)
chrome.runtime.onInstalled.addListener(() => {
  console.log('[ExtensionForge] Extensión instalada correctamente.');
});

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  console.log('[ExtensionForge][background] Mensaje recibido:', message);
  // Devuelve true para permitir respuestas asíncronas
  return true;
});
