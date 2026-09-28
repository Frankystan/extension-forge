/// <reference types="chrome" />
import { announceDevContentScript } from './dev/dev-reload';

// Content Script: inyecta un botón flotante en la página visitada que,
// al pulsarlo, pide al service worker que abra el SidePanel.

function injectButton(): void {
  if (document.getElementById('forgenotes-fab')) {
    return;
  }

  const btn = document.createElement('button');
  btn.id = 'forgenotes-fab';
  btn.textContent = '📝';
  btn.title = 'Abrir ForgeNotes (SidePanel)';
  btn.setAttribute(
    'style',
    'position:fixed;bottom:20px;right:20px;z-index:2147483647;' +
      'width:48px;height:48px;border-radius:50%;border:none;' +
      'background:#3f51b5;color:#fff;font-size:22px;cursor:pointer;' +
      'box-shadow:0 2px 8px rgba(0,0,0,.3);',
  );
  btn.addEventListener('click', () => {
    void chrome.runtime.sendMessage({ type: 'OPEN_SIDE_PANEL' });
  });
  document.body.appendChild(btn);
}

if (document.body) {
  injectButton();
} else {
  document.addEventListener('DOMContentLoaded', injectButton);
}

// Development: registra la pestaña para recargarla cuando se recargue la extensión
if (__EXTFORGE_DEV_RELOAD_PORT__) announceDevContentScript();
