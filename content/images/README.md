# Adding artwork

Add a collection directory such as `08_New_Collection` under `content/images/`, then add artwork with two-digit prefixes: `01_Artwork_Title.webp`, `02_Another_Title.webp`. Catalogue order follows the full filename. WebP is preferred; PNG, JPEG, and SVG are supported. Open Godot to import assets before running or exporting.

Do not cut artwork into tiles: the game divides each complete image into a 4×4 board. Portrait, landscape, and square images are supported. Landscape puzzles allow phone rotation.

## Titles and artist credits

Optional credit format: `01_Artwork Title-Art by Artist.webp`.

The text before the first hyphen is the title; everything after it is the subtitle. Avoid hyphens in artwork titles. `Art by Artist` is displayed as `Arte por Artist` in Portuguese and `Arte de Artist` in Spanish. The artist's name is preserved. Only add credits when they accurately describe authorship.

Add localized titles to `content/artwork_titles.json` using the exact relative path and filename:

```json
"08_New_Collection/01_Artwork Title-Art by Artist.webp": {
  "en": "Artwork Title",
  "pt": "Título da Arte",
  "es": "Título de la Obra"
}
```

Collection names and descriptions are configured in `scripts/locale.gd`, `content/spanish.json`, and `scripts/main.gd`. Special cover images and their framing are set in `scripts/main.gd`. If a special cover is not configured, the first artwork is used.

## Import settings

- Compress Mode: Lossy.
- Lossy Quality: 0.80.
- Generate Mipmaps: Off.

These settings are also configured as project defaults for new textures. Preserve enough resolution for gallery zoom without unnecessarily increasing file size.

Only the first six artworks of Quiet Moments are unlocked by default. All other artwork requires one key; new collections follow this rule. Character encounters are registered separately in `content/friendships.json`.

Keep originals, variants, and UI artwork outside this directory: all supported image files placed here become catalogue entries. After renaming artwork, update references in the title data, encounter data, achievement logic, and special covers as needed.
