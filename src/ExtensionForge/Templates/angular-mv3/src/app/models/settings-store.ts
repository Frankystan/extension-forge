// ---------------------------------------------------------------------------
// Acceso a las preferencias en chrome.storage.local sin Angular: lo usan
// SettingsService (popup), el background y, si lo necesita, el content script.
// ---------------------------------------------------------------------------
import { SETTINGS_KEY, Settings, normalizeSettings, sameSettings } from './settings.model';

/** Lee las preferencias guardadas (o los valores por defecto). */
export async function loadSettings(): Promise<Settings> {
  const stored = await chrome.storage.local.get(SETTINGS_KEY);
  return normalizeSettings(stored[SETTINGS_KEY]);
}

/** Guarda las preferencias completas (normalizadas) y las devuelve. */
export async function saveSettings(settings: Settings): Promise<Settings> {
  const next = normalizeSettings(settings);
  await chrome.storage.local.set({ [SETTINGS_KEY]: next });
  return next;
}

/** Aplica un cambio parcial sobre lo guardado y lo persiste. */
export async function updateSettings(patch: Partial<Omit<Settings, 'schemaVersion'>>): Promise<Settings> {
  const current = await loadSettings();
  return saveSettings({ ...current, ...patch });
}

/**
 * Instalación o actualización: escribe las preferencias normalizadas si faltan
 * o están desfasadas (migración). No toca nada si ya son válidas.
 */
export async function ensureSettings(): Promise<Settings> {
  const stored = (await chrome.storage.local.get(SETTINGS_KEY))[SETTINGS_KEY];
  const next = normalizeSettings(stored);
  const valid = typeof stored === 'object' && stored !== null && sameSettings(stored as Settings, next);
  if (!valid) {
    await chrome.storage.local.set({ [SETTINGS_KEY]: next });
  }
  return next;
}

/**
 * Avisa cuando otra superficie (popup, options, background) cambia las
 * preferencias. Devuelve la función para dejar de escuchar.
 */
export function onSettingsChanged(listener: (settings: Settings) => void): () => void {
  const handler = (changes: Record<string, chrome.storage.StorageChange>, area: string) => {
    if (area === 'local' && SETTINGS_KEY in changes) {
      listener(normalizeSettings(changes[SETTINGS_KEY].newValue));
    }
  };
  chrome.storage.onChanged.addListener(handler);
  return () => chrome.storage.onChanged.removeListener(handler);
}
