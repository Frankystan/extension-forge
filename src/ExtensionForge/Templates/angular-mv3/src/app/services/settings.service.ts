import { DestroyRef, Injectable, inject, signal } from '@angular/core';
import { DEFAULT_SETTINGS, Settings, normalizeSettings } from '../models/settings.model';
import { loadSettings, onSettingsChanged, saveSettings } from '../models/settings-store';

/**
 * Preferencias en chrome.storage.local expuestas como signals.
 *
 * El popup es efímero: se destruye al cerrarse y vuelve a arrancar al abrirse.
 * main.ts espera a `ready` (provideAppInitializer) antes de pintar, así el
 * popup se abre ya con las preferencias guardadas, sin parpadeo.
 * Los cambios hechos en otra superficie (options, background) llegan por
 * chrome.storage.onChanged.
 */
@Injectable({ providedIn: 'root' })
export class SettingsService {
  private readonly state = signal<Settings>({ ...DEFAULT_SETTINGS });
  private readonly loadedState = signal(false);
  private readonly errorState = signal<string | null>(null);

  /** Preferencias actuales (solo lectura). */
  readonly settings = this.state.asReadonly();
  /** true cuando ya se han leído de chrome.storage. */
  readonly loaded = this.loadedState.asReadonly();
  /** Último error de lectura o escritura. */
  readonly error = this.errorState.asReadonly();
  /** Se resuelve al terminar la primera lectura (nunca rechaza). */
  readonly ready: Promise<void>;

  constructor() {
    const stop = onSettingsChanged((settings) => this.state.set(settings));
    inject(DestroyRef).onDestroy(stop);
    this.ready = this.load();
  }

  private async load(): Promise<void> {
    try {
      this.state.set(await loadSettings());
      this.errorState.set(null);
    } catch (err) {
      this.errorState.set(`No se pudieron leer las preferencias: ${(err as Error).message}`);
    } finally {
      this.loadedState.set(true);
    }
  }

  /**
   * Cambia una o varias preferencias. Actualiza la interfaz al momento y
   * deshace el cambio si chrome.storage falla.
   */
  async update(patch: Partial<Omit<Settings, 'schemaVersion'>>): Promise<void> {
    const previous = this.state();
    const next = normalizeSettings({ ...previous, ...patch });
    this.state.set(next);
    try {
      await saveSettings(next);
      this.errorState.set(null);
    } catch (err) {
      this.state.set(previous);
      this.errorState.set(`No se pudieron guardar las preferencias: ${(err as Error).message}`);
    }
  }

  /** Vuelve a los valores por defecto. */
  reset(): Promise<void> {
    return this.update({ theme: DEFAULT_SETTINGS.theme, notifications: DEFAULT_SETTINGS.notifications });
  }
}
