import { Component } from '@angular/core';
import { PopupComponent } from './popup/popup.component';
import { SidePanelComponent } from './sidepanel/sidepanel.component';
import { OptionsComponent } from './options/options.component';

type View = 'popup' | 'sidepanel' | 'options';

/**
 * Componente raíz: decide qué superficie renderizar según el atributo
 * data-view del <body>. Un único bundle Angular sirve las 3 páginas
 * (index.html, sidepanel.html y options.html generadas en el post-build).
 */
@Component({
  selector: 'app-root',
  standalone: true,
  imports: [PopupComponent, SidePanelComponent, OptionsComponent],
  template: `
    @switch (view) {
      @case ('sidepanel') { <app-sidepanel /> }
      @case ('options')   { <app-options /> }
      @default            { <app-popup /> }
    }
  `,
})
export class AppComponent {
  readonly view: View = (document.body.dataset['view'] as View) ?? 'popup';
}
