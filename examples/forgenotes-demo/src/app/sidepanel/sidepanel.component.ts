import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatListModule } from '@angular/material/list';
import { MatButtonModule } from '@angular/material/button';
import { MatInputModule } from '@angular/material/input';
import { MatIconModule } from '@angular/material/icon';
import { ExtensionService } from '../shared/extension.service';

@Component({
  selector: 'app-sidepanel',
  standalone: true,
  imports: [FormsModule, MatToolbarModule, MatListModule, MatButtonModule, MatInputModule, MatIconModule],
  templateUrl: './sidepanel.component.html',
  styleUrl: './sidepanel.component.scss',
})
export class SidePanelComponent {
  readonly service = inject(ExtensionService);
  text = '';

  add(): void {
    const t = this.text.trim();
    if (t) {
      this.service.addNote(t);
      this.text = '';
    }
  }
}
