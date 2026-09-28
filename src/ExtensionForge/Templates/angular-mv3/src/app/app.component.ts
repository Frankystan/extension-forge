import { Component, inject, signal } from '@angular/core';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { ExtensionInfo } from './models/messages.model';
import { MessageService } from './services/message.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [MatToolbarModule, MatCardModule, MatButtonModule],
  templateUrl: './app.component.html',
  styleUrl: './app.component.scss'
})
export class AppComponent {
  private readonly messages = inject(MessageService);

  title = 'ExtensionForge';
  readonly info = signal<ExtensionInfo | null>(null);
  readonly lastPing = signal<string | null>(null);
  readonly error = signal<string | null>(null);

  constructor() {
    this.messages.send('GET_INFO').then(
      (info) => this.info.set(info),
      (err: Error) => this.error.set(err.message),
    );
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
