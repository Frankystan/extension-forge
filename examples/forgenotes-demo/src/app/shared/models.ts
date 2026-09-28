export interface Note {
  id: string;
  text: string;
  createdAt: number;
}

export interface Settings {
  theme: 'light' | 'dark';
  maxNotes: number;
}

export const DEFAULT_SETTINGS: Settings = {
  theme: 'light',
  maxNotes: 50,
};

export type Message =
  | { type: 'ADD_NOTE'; text: string }
  | { type: 'DELETE_NOTE'; id: string }
  | { type: 'CLEAR_ALL' }
  | { type: 'UPDATE_SETTINGS'; settings: Settings }
  | { type: 'OPEN_SIDE_PANEL' }
  | { type: 'GET_STATE' };

export interface AppState {
  notes: Note[];
  settings: Settings;
}

export const STORAGE_KEY = 'forgenotes';
