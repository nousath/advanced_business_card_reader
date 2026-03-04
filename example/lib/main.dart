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

enum _ScanMode { singleSide, doubleSide }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _picker = ImagePicker();

  bool _loading = false;
  _ScanMode _scanMode = _ScanMode.singleSide;

  bool _auto = true;
  OcrScript _script = OcrScript.latin;

  String? _singleImagePath;
  String? _frontImagePath;
  String? _backImagePath;

  BusinessCardScanResult? _singleResult;
  BusinessCardSidesResult? _doubleResult;

  List<String> _singleAddresses = const [];
  List<String> _frontAddresses = const [];
  List<String> _backAddresses = const [];
  List<String> _mergedAddresses = const [];

  String? _error;

  Future<void> _scanSinglePath(String path) async {
    setState(() {
      _loading = true;
      _error = null;
      _singleResult = null;
      _doubleResult = null;
      _singleAddresses = const [];
      _singleImagePath = path;
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

      final addresses = await BusinessCardReader.extractAddressesFromText(
        r.data.rawText,
        language: _languageForScript(r.scriptUsed),
      );

      setState(() {
        _singleResult = r;
        _singleAddresses = addresses;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _singleAddresses = const [];
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _scanDoubleSides() async {
    final frontPath = _frontImagePath;
    final backPath = _backImagePath;
    if (frontPath == null || backPath == null) {
      setState(() {
        _error = 'Please select both front and back images first.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _singleResult = null;
      _doubleResult = null;
      _frontAddresses = const [];
      _backAddresses = const [];
      _mergedAddresses = const [];
    });

    try {
      final r = _auto
          ? await BusinessCardReader.scanAutoFromFilesFrontBack(
              frontPath: frontPath,
              backPath: backPath,
              preferredScripts: const [
                OcrScript.latin,
                OcrScript.devanagari,
                OcrScript.chinese,
                OcrScript.japanese,
                OcrScript.korean,
              ],
              defaultIsoCountry: 'IN',
            )
          : await BusinessCardReader.scanFromFilesFrontBack(
              frontPath: frontPath,
              backPath: backPath,
              script: _script,
              defaultIsoCountry: 'IN',
            );

      final frontAddresses = await BusinessCardReader.extractAddressesFromText(
        r.front.data.rawText,
        language: _languageForScript(r.front.scriptUsed),
      );
      final backAddresses = await BusinessCardReader.extractAddressesFromText(
        r.back.data.rawText,
        language: _languageForScript(r.back.scriptUsed),
      );
      final mergedAddresses = await BusinessCardReader.extractAddressesFromText(
        r.merged.data.rawText,
        language: _languageForScript(r.merged.scriptUsed),
      );

      setState(() {
        _doubleResult = r;
        _frontAddresses = frontAddresses;
        _backAddresses = backAddresses;
        _mergedAddresses = mergedAddresses;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  String _languageForScript(OcrScript script) {
    switch (script) {
      case OcrScript.latin:
        return 'en';
      case OcrScript.devanagari:
        return 'hi';
      case OcrScript.chinese:
        return 'zh';
      case OcrScript.japanese:
        return 'ja';
      case OcrScript.korean:
        return 'ko';
    }
  }

  Future<void> _scanCameraSingle() async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 92);
    if (x == null) return;
    await _scanSinglePath(x.path);
  }

  Future<void> _scanGallerySingle() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (x == null) return;
    await _scanSinglePath(x.path);
  }

  Future<void> _scanFileSingle() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    final path = res?.files.single.path;
    if (path == null) return;
    await _scanSinglePath(path);
  }

  Future<void> _pickSideFromCamera({required bool isFront}) async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 92);
    if (x == null) return;
    setState(() {
      _error = null;
      _singleResult = null;
      _doubleResult = null;
      if (isFront) {
        _frontImagePath = x.path;
      } else {
        _backImagePath = x.path;
      }
    });
  }

  Future<void> _pickSideFromGallery({required bool isFront}) async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (x == null) return;
    setState(() {
      _error = null;
      _singleResult = null;
      _doubleResult = null;
      if (isFront) {
        _frontImagePath = x.path;
      } else {
        _backImagePath = x.path;
      }
    });
  }

  Future<void> _pickSideFromFile({required bool isFront}) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    final path = res?.files.single.path;
    if (path == null) return;

    setState(() {
      _error = null;
      _singleResult = null;
      _doubleResult = null;
      if (isFront) {
        _frontImagePath = path;
      } else {
        _backImagePath = path;
      }
    });
  }

  void _setScanMode(_ScanMode mode) {
    if (_scanMode == mode) return;
    setState(() {
      _scanMode = mode;
      _error = null;
      _singleResult = null;
      _doubleResult = null;
      _singleAddresses = const [];
      _frontAddresses = const [];
      _backAddresses = const [];
      _mergedAddresses = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Card Reader'),
      ),
      body: SafeArea(
        child: Scrollbar(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _controls(cs),
              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(),
              if (_loading) const SizedBox(height: 12),
              if (!_loading) const SizedBox(height: 4),
              ..._contentSections(cs),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _contentSections(ColorScheme cs) {
    if (_error != null) {
      return [_errorView(_error!)];
    }

    if (_scanMode == _ScanMode.singleSide) {
      if (_singleResult == null) return [_emptyState(cs)];
      return _singleResultSections(_singleResult!);
    }

    if (_doubleResult == null) {
      return [
        _emptyState(
        cs,
        title: 'Select front and back, then scan both',
        subtitle: 'Double-side mode merges both card sides into one result.',
      ),
      ];
    }

    return _doubleResultSections(_doubleResult!);
  }

  Widget _controls(ColorScheme cs) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Single Side'),
                  selected: _scanMode == _ScanMode.singleSide,
                  onSelected: _loading ? null : (_) => _setScanMode(_ScanMode.singleSide),
                ),
                ChoiceChip(
                  label: const Text('Double Side'),
                  selected: _scanMode == _ScanMode.doubleSide,
                  onSelected: _loading ? null : (_) => _setScanMode(_ScanMode.doubleSide),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_scanMode == _ScanMode.singleSide) _singleButtons(),
            if (_scanMode == _ScanMode.doubleSide) _doubleButtons(),
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
                    subtitle: Text(
                      _scanMode == _ScanMode.singleSide
                          ? 'Try multiple scripts and pick best'
                          : 'Auto-pick script per side',
                    ),
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
                        initialValue: _script,
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

  Widget _singleButtons() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _loading ? null : _scanCameraSingle,
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Camera'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _loading ? null : _scanGallerySingle,
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Gallery'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _loading ? null : _scanFileSingle,
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('File'),
          ),
        ),
      ],
    );
  }

  Widget _doubleButtons() {
    final frontReady = _frontImagePath != null;
    final backReady = _backImagePath != null;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _loading ? null : () => _pickSideFromCamera(isFront: true),
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Front Cam'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _loading ? null : () => _pickSideFromGallery(isFront: true),
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Front Gal'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _loading ? null : () => _pickSideFromFile(isFront: true),
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Front File'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _loading ? null : () => _pickSideFromCamera(isFront: false),
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Back Cam'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _loading ? null : () => _pickSideFromGallery(isFront: false),
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Back Gal'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _loading ? null : () => _pickSideFromFile(isFront: false),
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Back File'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Front: ${frontReady ? "selected" : "missing"} | Back: ${backReady ? "selected" : "missing"}',
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _loading || !frontReady || !backReady ? null : _scanDoubleSides,
              icon: const Icon(Icons.document_scanner_rounded),
              label: const Text('Scan Both'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _emptyState(
    ColorScheme cs, {
    String title = 'Scan a business card to extract details',
    String subtitle = 'Use Camera, Gallery, or File pick. Keep card flat & clear.',
  }) {
    return Center(
      child: Card(
        elevation: 0,
        color: cs.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.document_scanner_rounded, size: 48),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
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

  List<Widget> _singleResultSections(BusinessCardScanResult result) {
    return [
      if (_singleImagePath != null) _imageCard(_singleImagePath!, 'Selected Image'),
      const SizedBox(height: 12),
      _parsedCard(
        title: 'Parsed Details',
        result: result,
        addresses: _singleAddresses,
      ),
      _rawTextCard(title: 'Raw Text', text: result.data.rawText),
    ];
  }

  List<Widget> _doubleResultSections(BusinessCardSidesResult result) {
    return [
      if (_frontImagePath != null || _backImagePath != null)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _frontImagePath == null
                  ? const SizedBox.shrink()
                  : _imageCard(_frontImagePath!, 'Front'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _backImagePath == null
                  ? const SizedBox.shrink()
                  : _imageCard(_backImagePath!, 'Back'),
            ),
          ],
        ),
      const SizedBox(height: 12),
      _parsedCard(
        title: 'Front Parsed',
        result: result.front,
        addresses: _frontAddresses,
      ),
      _parsedCard(
        title: 'Back Parsed',
        result: result.back,
        addresses: _backAddresses,
      ),
      _parsedCard(
        title: 'Merged Parsed (Primary)',
        result: result.merged,
        addresses: _mergedAddresses,
      ),
      _rawTextCard(title: 'Merged Raw Text', text: result.merged.data.rawText),
    ];
  }

  Widget _imageCard(String path, String title) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(path),
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _parsedCard({
    required String title,
    required BusinessCardScanResult result,
    required List<String> addresses,
  }) {
    final d = result.data;

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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            kv('Script', result.scriptUsed.label),
            kv('Name', d.name ?? '-'),
            kv('Company', d.company ?? '-'),
            kv('Phones', d.phones.isEmpty ? '-' : d.phones.join('\n')),
            kv('Emails', d.emails.isEmpty ? '-' : d.emails.join('\n')),
            kv('Websites', d.websites.isEmpty ? '-' : d.websites.join('\n')),
            kv('Addresses', addresses.isEmpty ? '-' : addresses.join('\n')),
          ],
        ),
      ),
    );
  }

  Widget _rawTextCard({
    required String title,
    required String text,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            SelectableText(text.isEmpty ? '(empty)' : text),
          ],
        ),
      ),
    );
  }
}
