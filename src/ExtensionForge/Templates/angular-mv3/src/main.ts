import { inject, provideAppInitializer } from '@angular/core';
import { bootstrapApplication } from '@angular/platform-browser';
import { AppComponent } from './app/app.component';
import { SettingsService } from './app/services/settings.service';

bootstrapApplication(AppComponent, {
  providers: [
    // El popup se crea de cero cada vez que se abre: carga las preferencias de
    // chrome.storage.local antes del primer render.
    provideAppInitializer(() => inject(SettingsService).ready),
  ],
}).catch((err) => console.error(err));
