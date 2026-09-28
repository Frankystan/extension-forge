/// <reference types="chrome" />

import { AppState, DEFAULT_SETTINGS, Message, Note, Settings, STORAGE_KEY } from './app/shared/models';

// El service worker es el "hub" de la extensión:
// - centraliza el acceso a chrome.storage.local
// - recibe los mensajes de Popup / SidePanel / Options / Content Script
// - abre el SidePanel cuando se lo piden

async function getState(): Promise<AppState> {
  const result = await chrome.storage.local.get(STORAGE_KEY);
  const state = result[STORAGE_KEY] as AppState | undefined;
  return state ?? { notes: [], settings: DEFAULT_SETTINGS };
}

async function setState(state: AppState): Promise<void> {
  await chrome.storage.local.set({ [STORAGE_KEY]: state });
}

async function addNote(text: string): Promise<void> {
  const state = await getState();
  const note: Note = { id: crypto.randomUUID(), text, createdAt: Date.now() };
  state.notes = [note, ...state.notes].slice(0, state.settings.maxNotes);
  await setState(state);
}

async function deleteNote(id: string): Promise<void> {
  const state = await getState();
  state.notes = state.notes.filter((n) => n.id !== id);
  await setState(state);
}

async function clearAll(): Promise<void> {
  const state = await getState();
  state.notes = [];
  await setState(state);
}

async function updateSettings(settings: Settings): Promise<void> {
  const state = await getState();
  state.settings = settings;
  await setState(state);
}

async function openSidePanel(sender: chrome.runtime.MessageSender | undefined): Promise<void> {
  // Nota: chrome.sidePanel.open() requiere un gesto del usuario (Chrome 114+).
  const tabId = sender?.tab?.id;
  if (tabId != null) {
    await chrome.sidePanel.open({ tabId });
    return;
  }
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (tab?.id != null) {
    await chrome.sidePanel.open({ tabId: tab.id });
  }
}

chrome.runtime.onInstalled.addListener(async () => {
  await setState(await getState());
});

chrome.runtime.onMessage.addListener((message: Message, sender, sendResponse) => {
  (async () => {
    switch (message.type) {
      case 'GET_STATE':
        sendResponse(await getState());
        return;
      case 'ADD_NOTE':
        await addNote(message.text);
        break;
      case 'DELETE_NOTE':
        await deleteNote(message.id);
        break;
      case 'CLEAR_ALL':
        await clearAll();
        break;
      case 'UPDATE_SETTINGS':
        await updateSettings(message.settings);
        break;
      case 'OPEN_SIDE_PANEL':
        await openSidePanel(sender);
        break;
    }
    sendResponse({ ok: true });
  })();
  return true; // mantiene el canal abierto para respuestas asíncronas
});
