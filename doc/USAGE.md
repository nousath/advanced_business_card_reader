# Usage Notes

## Choosing a script

- **Latin**: English, most business cards, Tanglish
- **Devanagari**: Hindi/Marathi/Nepali etc.
- **Chinese/Japanese/Korean**: use if your cards are in these scripts

If your UI offers languages, map them to scripts (ex: Hindi → Devanagari).

## Auto scan strategy

Use `scanAutoFromFile()` with a preferred order, starting with what is most common in your region.
Example for India:

```dart
preferredScripts: const [OcrScript.latin, OcrScript.devanagari]
```

## Parsing accuracy

Business cards vary greatly. Always let the user confirm/edit the parsed fields.

If you want to customize parsing rules (company keywords, name rules), fork and adjust `lib/src/parser.dart`.
