import { Component, effect, inject, signal } from '@angular/core';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { MatSlideToggleModule } from '@angular/material/slide-toggle';
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

  constructor() {
    // Tema guardado → color-scheme del documento (el tema M3 usa light-dark())
    effect(() => {
      const theme = this.prefs.settings().theme;
      document.documentElement.style.colorScheme = theme === 'system' ? 'light dark' : theme;
    });

    this.messages.send('GET_INFO').then(
      (info) => this.info.set(info),
      (err: Error) => this.error.set(err.message),
    );
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
