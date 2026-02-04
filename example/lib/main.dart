import 'dart:io';

import 'package:advanced_business_card_reader/advanced_business_card_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const CardReaderExampleApp());
}

class CardReaderExampleApp extends StatelessWidget {
  const CardReaderExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Business Card Reader',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _picker = ImagePicker();

  bool _loading = false;
  String? _imagePath;

  // Script selection
  bool _auto = true;
  OcrScript _script = OcrScript.latin;

  BusinessCardScanResult? _result;
  String? _error;

  Future<void> _scanPath(String path) async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _imagePath = path;
    });

    try {
      final r = _auto
          ? await BusinessCardReader.scanAutoFromFile(
              path,
              preferredScripts: const [
                OcrScript.latin,
                OcrScript.devanagari,
                OcrScript.chinese,
                OcrScript.japanese,
                OcrScript.korean,
              ],
              defaultIsoCountry: 'IN',
            )
          : await BusinessCardReader.scanFromFile(
              path,
              script: _script,
              defaultIsoCountry: 'IN',
            );

      setState(() => _result = r);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _scanCamera() async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 92);
    if (x == null) return;
    await _scanPath(x.path);
  }

  Future<void> _scanGallery() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (x == null) return;
    await _scanPath(x.path);
  }

  Future<void> _scanFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    final path = res?.files.single.path;
    if (path == null) return;
    await _scanPath(path);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Card Reader'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _controls(cs),
              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(),
              if (!_loading) const SizedBox(height: 4),
              Expanded(
                child: _result == null && _error == null
                    ? _emptyState(cs)
                    : _result != null
                        ? _resultView(_result!)
                        : _errorView(_error!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(ColorScheme cs) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _scanCamera,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _scanGallery,
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _scanFile,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('File'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _auto,
                    onChanged: _loading
                        ? null
                        : (v) => setState(() {
                              _auto = v;
                            }),
                    title: const Text('Auto script'),
                    subtitle: const Text('Try multiple scripts and pick best'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 170,
                  child: Opacity(
                    opacity: _auto ? 0.5 : 1,
                    child: IgnorePointer(
                      ignoring: _auto,
                      child: DropdownButtonFormField<OcrScript>(
                        value: _script,
                        decoration: const InputDecoration(
                          labelText: 'Script',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: OcrScript.values
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _script = v ?? OcrScript.latin),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(ColorScheme cs) {
    return Center(
      child: Card(
        elevation: 0,
        color: cs.surfaceContainerHighest,
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.document_scanner_rounded, size: 48),
              SizedBox(height: 10),
              Text(
                'Scan a business card to extract details',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
              SizedBox(height: 4),
              Text(
                'Use Camera, Gallery, or File pick For best results, keep the card flat & clear.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorView(String err) {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              err,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _resultView(BusinessCardScanResult r) {
    final d = r.data;

    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 92,
                child: Text(k, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              Expanded(child: Text(v)),
            ],
          ),
        );

    return ListView(
      children: [
        if (_imagePath != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              File(_imagePath!),
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parsed Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                kv('Script', r.scriptUsed.label),
                kv('Name', d.name ?? '-'),
                kv('Company', d.company ?? '-'),
                kv('Phones', d.phones.isEmpty ? '-' : d.phones.join('\n')),
                kv('Emails', d.emails.isEmpty ? '-' : d.emails.join('\n')),
                kv('Websites', d.websites.isEmpty ? '-' : d.websites.join('\n')),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Raw Text',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                SelectableText(d.rawText.isEmpty ? '(empty)' : d.rawText),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
