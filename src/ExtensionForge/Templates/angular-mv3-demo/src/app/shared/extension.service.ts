import { Injectable, signal } from '@angular/core';
import { AppState, DEFAULT_SETTINGS, Message, Settings, STORAGE_KEY } from './models';

/**
 * Servicio compartido por Popup, SidePanel y Options.
 * Envuelve chrome.runtime (mensajes) y chrome.storage (estado), de modo que
 * las 3 superficies comparten el mismo estado reactivo vía storage.onChanged.
 */
@Injectable({ providedIn: 'root' })
export class ExtensionService {
  readonly state = signal<AppState>({ notes: [], settings: DEFAULT_SETTINGS });

  constructor() {
    void this.load();
    chrome.storage.onChanged.addListener((changes, area) => {
      if (area === 'local' && changes[STORAGE_KEY]) {
        this.state.set(changes[STORAGE_KEY].newValue ?? { notes: [], settings: DEFAULT_SETTINGS });
      }
    });
  }

  private async load(): Promise<void> {
    const state = await this.send<AppState>({ type: 'GET_STATE' });
    if (state) {
      this.state.set(state);
    }
  }

  private send<T = unknown>(message: Message): Promise<T> {
    return chrome.runtime.sendMessage(message) as Promise<T>;
  }

  addNote(text: string): void {
    void this.send({ type: 'ADD_NOTE', text });
  }

  deleteNote(id: string): void {
    void this.send({ type: 'DELETE_NOTE', id });
  }

  clearAll(): void {
    void this.send({ type: 'CLEAR_ALL' });
  }

  updateSettings(settings: Settings): void {
    void this.send({ type: 'UPDATE_SETTINGS', settings });
  }

  async openSidePanel(): Promise<void> {
    if (!chrome.sidePanel || typeof chrome.sidePanel.open !== 'function') {
      return;
    }
    // El popup tiene acceso a chrome.sidePanel y el gesto del usuario sigue
    // activo. OpenOptions exige tabId o windowId, así que resolvemos la ventana
    // actual (enviarlo por sendMessage al background perdería el gesto).
    const currentWindow = await chrome.windows.getCurrent();
    if (currentWindow.id == null) {
      return;
    }
    await chrome.sidePanel.open({ windowId: currentWindow.id });
  }
}
