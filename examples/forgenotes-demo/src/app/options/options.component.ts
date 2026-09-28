import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatInputModule } from '@angular/material/input';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { ExtensionService } from '../shared/extension.service';
import { Settings } from '../shared/models';

@Component({
  selector: 'app-options',
  standalone: true,
  imports: [FormsModule, MatToolbarModule, MatCardModule, MatButtonModule, MatInputModule, MatButtonToggleModule],
  templateUrl: './options.component.html',
  styleUrl: './options.component.scss',
})
export class OptionsComponent {
  readonly service = inject(ExtensionService);
  theme: Settings['theme'] = 'light';
  maxNotes = 50;

  save(): void {
    this.service.updateSettings({ theme: this.theme, maxNotes: Number(this.maxNotes) || 50 });
  }
}
