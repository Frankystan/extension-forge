import { Component, effect, inject, signal } from '@angular/core';
import { takeUntilDestroyed, toSignal } from '@angular/core/rxjs-interop';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { MatSlideToggleModule } from '@angular/material/slide-toggle';
import { EventPayload } from './models/events.model';
import { ExtensionInfo } from './models/messages.model';
import { ThemePreference } from './models/settings.model';
import { MessageService } from './services/message.service';
import { SettingsService } from './services/settings.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [MatToolbarModule, MatCardModule, MatButtonModule, MatButtonToggleModule, MatSlideToggleModule],
  templateUrl: './app.component.html',
  styleUrl: './app.component.scss'
})
export class AppComponent {
  private readonly messages = inject(MessageService);
  protected readonly prefs = inject(SettingsService);

  title = 'ExtensionForge';
  readonly info = signal<ExtensionInfo | null>(null);
  readonly lastPing = signal<string | null>(null);
  readonly error = signal<string | null>(null);

  // Eventos proactivos del background (un único puerto compartido)
  readonly lastVisit = toSignal(this.messages.on$('PAGE_VISITED'), { initialValue: null });
  readonly notifications = signal<(EventPayload<'NOTIFICATION'> & { at: string })[]>([]);

  constructor() {
    // Tema guardado → color-scheme del documento (el tema M3 usa light-dark())
    effect(() => {
      const theme = this.prefs.settings().theme;
      document.documentElement.style.colorScheme = theme === 'system' ? 'light dark' : theme;
    });

    this.messages
      .on$('NOTIFICATION')
      .pipe(takeUntilDestroyed())
      .subscribe((n) => this.notifications.update((list) => [n, ...list].slice(0, 3)));

    this.messages.send('GET_INFO').then(
      (info) => this.info.set(info),
      (err: Error) => this.error.set(err.message),
    );
  }

  /** Pide al background una notificación dentro de 2 s (llega por el canal de eventos). */
  async requestNotification(): Promise<void> {
    try {
      await this.messages.send('REQUEST_NOTIFICATION', { text: 'Aviso enviado por el background', delayMs: 2000 });
      this.error.set(null);
    } catch (err) {
      this.error.set((err as Error).message);
    }
  }

  setTheme(theme: ThemePreference): void {
    void this.prefs.update({ theme });
  }

  setNotifications(notifications: boolean): void {
    void this.prefs.update({ notifications });
  }

  async ping(): Promise<void> {
    try {
      const { at } = await this.messages.send('PING');
      this.lastPing.set(at);
      this.error.set(null);
    } catch (err) {
      this.error.set((err as Error).message);
    }
  }
}
