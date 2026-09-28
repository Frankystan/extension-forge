// ---------------------------------------------------------------------------
// Preferencias de la extensión guardadas en chrome.storage.local.
// Añade aquí cada preferencia nueva: su valor por defecto en DEFAULT_SETTINGS y
// su validación en normalizeSettings() (los datos guardados pueden venir de una
// versión anterior o estar corruptos).
// ---------------------------------------------------------------------------

export type ThemePreference = 'system' | 'light' | 'dark';

export interface Settings {
  /** Versión del esquema guardado; súbela si cambias el formato y migra en normalizeSettings(). */
  schemaVersion: 1;
  theme: ThemePreference;
  notifications: boolean;
}

/** Clave única en chrome.storage.local. */
export const SETTINGS_KEY = 'extforge.settings';

export const DEFAULT_SETTINGS: Readonly<Settings> = Object.freeze({
  schemaVersion: 1,
  theme: 'system',
  notifications: true,
});

const THEMES: readonly ThemePreference[] = ['system', 'light', 'dark'];

/**
 * Devuelve siempre unas preferencias válidas: parte de los valores por defecto
 * y solo conserva los campos guardados con el tipo correcto.
 */
export function normalizeSettings(raw: unknown): Settings {
  const value = typeof raw === 'object' && raw !== null ? (raw as Record<string, unknown>) : {};
  return {
    schemaVersion: 1,
    theme: THEMES.includes(value['theme'] as ThemePreference)
      ? (value['theme'] as ThemePreference)
      : DEFAULT_SETTINGS.theme,
    notifications:
      typeof value['notifications'] === 'boolean' ? value['notifications'] : DEFAULT_SETTINGS.notifications,
  };
}

/** true si dos preferencias tienen los mismos valores. */
export function sameSettings(a: Settings, b: Settings): boolean {
  return a.theme === b.theme && a.notifications === b.notifications && a.schemaVersion === b.schemaVersion;
}
