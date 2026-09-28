# 🧭 Cargar tu extensión en Google Chrome — Guía ampliada

ExtensionForge genera la extensión final en `dist/extension/chrome/` (la carpeta que contiene `manifest.json`).

## Estructura de salida (verificada)

```text
dist\
├─ extension-forge-demo-app\browser\   ← salida cruda de ng build (no cargar)
└─ extension\
   └─ chrome\                          ← ★ carpeta que hay que cargar
      ├─ manifest.json
      ├─ index.html        (popup)
      ├─ sidepanel.html    (panel lateral)
      ├─ options.html      (opciones)
      └─ background.js / content.js
```

## Método A — Manual (recomendado para desarrollo)

1. Abre Chrome y ve a `chrome://extensions`.
2. Activa el interruptor **"Modo de desarrollador"** (arriba a la derecha).
3. Pulsa **"Cargar descomprimida"**.
4. Selecciona la carpeta: `C:\<tu-proyecto>\dist\extension\chrome`.
5. Tras cada `Build`, pulsa **↻ Recargar** sobre tu extensión.

✅ Ventajas: queda instalada hasta que la quites y recargas con un clic tras cada compilación.

## Método B — Línea de comandos (proceso temporal)

⚠️ Chrome estable 137+ **ignora `--load-extension`** (cambio de seguridad). Usa **Chrome for Testing**, Canary o Dev. ✅ Verificado con Chrome for Testing 148 (`C:\chromeDriver\chrome.exe`):

```powershell
& "C:\chromeDriver\chrome.exe" `
  --user-data-dir="$env:TEMP\forge-chrome-profile" `
  --load-extension="C:\<tu-proyecto>\dist\extension\chrome"
```

### Errores frecuentes (y por qué fallaba)

| Error | Causa | Solución |
|---|---|---|
| Ruta `...\chrome\extension-manager` no existe | La carpeta a cargar es `...\chrome` (la que contiene `manifest.json`), sin subcarpetas extra | Usa `dist\extension\chrome` |
| `" C:\...` con espacio tras la comilla | El espacio invalida la ruta | Sin espacio: `"C:\...` |
| `--load-extension` se ignora | Chrome estable 137+ eliminó el flag (solo funciona en Canary/Dev/Chrome for Testing) | Usa Canary/Dev o el método manual |

⚠️ Con este método la extensión **solo vive mientras dure ese proceso de Chrome** (al cerrarlo, se pierde).

## Notas

- **SidePanel es exclusivo de Chrome 114+**; en Firefox no está disponible.
- **Firefox:** `about:debugging` → "Este Firefox" → "Cargar complemento temporal…" → selecciona `manifest.json` en `dist/extension/firefox`, o usa `npx web-ext run --source-dir "dist/extension/firefox"`.
