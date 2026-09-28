import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatInputModule } from '@angular/material/input';
import { ExtensionService } from '../shared/extension.service';

@Component({
  selector: 'app-popup',
  standalone: true,
  imports: [FormsModule, MatToolbarModule, MatCardModule, MatButtonModule, MatInputModule],
  templateUrl: './popup.component.html',
  styleUrl: './popup.component.scss',
})
export class PopupComponent {
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
