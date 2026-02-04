import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import 'business_card_data.dart';

class BusinessCardParser {
  // email
  static final RegExp _emailRx = RegExp(
    r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
    caseSensitive: false,
  );

  // website/domain (basic)
  static final RegExp _urlRx = RegExp(
    r'''\b((https?:\/\/)?(www\.)?[a-z0-9-]+\.[a-z]{2,}(\/[^\s]*)?)\b''',
    caseSensitive: false,
  );

  // loose phone candidates: +91 98765 43210, 09876543210, (987) 654-3210 etc.
  static final RegExp _phoneCandidateRx = RegExp(r'(\+?\d[\d\s().-]{7,}\d)');

  static BusinessCardData parse(
    String rawText, {
    String defaultIsoCountry = 'IN',

    /// If you want “auto country” for local numbers, pass multiple countries:
    /// e.g. ['IN','AE','US'].
    List<String>? tryIsoCountries,

    /// Output numbers as +<countryCode><nsn>
    bool phoneAsE164 = true,
  }) {
    final text = rawText.trim();

    final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final emails = _emailRx.allMatches(text).map((m) => m.group(0)!).toSet().toList();

    final websites = _urlRx.allMatches(text).map((m) => m.group(0)!).map(_normalizeWebsite).toSet().toList();

    final phones = _extractPhones(
      text,
      defaultIsoCountry: defaultIsoCountry,
      tryIsoCountries: tryIsoCountries,
      asE164: phoneAsE164,
    );

    final company = _pickCompany(lines);
    final name = _pickName(lines, company: company);

    return BusinessCardData(
      rawText: text,
      name: name,
      company: company,
      phones: phones,
      emails: emails,
      websites: websites,
    );
  }

  static List<String> _extractPhones(
    String text, {
    required String defaultIsoCountry,
    List<String>? tryIsoCountries,
    bool asE164 = true,
  }) {
    final defaultIso = _isoFromString(defaultIsoCountry);

    // If not provided, only use the default country for local numbers
    final isoCandidates = (tryIsoCountries == null || tryIsoCountries.isEmpty)
        ? <IsoCode>[defaultIso]
        : tryIsoCountries.map(_isoFromString).toList();

    final out = <String>{};

    for (final m in _phoneCandidateRx.allMatches(text)) {
      var candidate = m.group(0)!.trim();

      // handle 00-prefixed international numbers: 00971... -> +971...
      candidate = candidate.replaceFirst(RegExp(r'^00'), '+');

      // remove obvious extension part (ext / x / #)
      candidate = candidate.split(RegExp(r'\b(ext|extension|x|#)\b', caseSensitive: false)).first.trim();

      final cleaned = candidate.replaceAll(RegExp(r'[^\d+]'), '');
      final digitsCount = cleaned.replaceAll('+', '').length;
      if (digitsCount < 8) continue;

      // Case 1: already international => country code is inside the number
      if (cleaned.startsWith('+')) {
        try {
          final p = PhoneNumber.parse(candidate); // detects iso from +code
          if (p.isValid()) out.add(asE164 ? _toE164(p) : p.international);
        } catch (_) {}
        continue;
      }

      // Case 2: local number => parse using destination country
      // If multiple isoCandidates provided, try each until valid
      PhoneNumber? best;
      for (final iso in isoCandidates) {
        try {
          final p = PhoneNumber.parse(candidate, destinationCountry: iso);
          if (p.isValid()) {
            best = p;
            break; // first valid wins (ordered list)
          }
        } catch (_) {}
      }

      if (best != null) out.add(asE164 ? _toE164(best) : best.international);
    }

    return out.toList();
  }

  static String _toE164(PhoneNumber p) => '+${p.countryCode}${p.nsn}';

  static IsoCode _isoFromString(String iso) {
    final upper = iso.trim().toUpperCase();
    for (final v in IsoCode.values) {
      if (v.name == upper) return v;
    }
    return IsoCode.IN;
  }

  static String _normalizeWebsite(String s) {
    var w = s.trim();
    w = w.replaceAll(RegExp(r'[),.;]+$'), '');
    // Add https if missing
    if (!w.startsWith('http') && w.contains('.')) {
      w = 'https://${w.replaceFirst(RegExp(r'^www\.'), '')}';
    }
    return w;
  }

  static String? _pickCompany(List<String> lines) {
    const keywords = [
      // legal forms
      'pvt', 'pvt.', 'private', 'ltd', 'ltd.', 'limited', 'llp', 'llc', 'inc', 'inc.', 'corp', 'corporation',
      'co', 'co.', 'company', 'gmbh', 'sarl', 'bv', 'ag',

      // India specific
      'private limited', 'pvt ltd', 'pvt. ltd', 'opc', 'one person company',

      // common business words
      'technologies', 'technology', 'tech', 'solutions', 'systems', 'services', 'consulting', 'consultants',
      'enterprises', 'enterprise', 'industries', 'group', 'global', 'international',
      'trading', 'exports', 'import', 'imports', 'logistics', 'shipping',
      'construction', 'builders', 'infra', 'infrastructure',
      'pharma', 'pharmaceutical', 'hospital', 'clinic', 'diagnostics',
      'education', 'institute', 'academy', 'school', 'college',
      'finance', 'capital', 'investments', 'holdings',
      'studio', 'media', 'design', 'digital', 'marketing', 'advertising', 'creative',
      'manufacturing', 'factory',

      'l.l.c', 'llc', 'fze', 'f.z.e', 'fz-llc', 'fzc', 'f.z.c',
      'freezone', 'free zone',
      'pjsc', 'p.j.s.c', 'psc', 'p.s.c',
      'est', 'est.', 'establishment',
      'trading', 'general trading',
      'l.l.p', 'holding', 'holdings',
    ];

    // 1) keyword-based
    for (final l in lines) {
      final low = l.toLowerCase();
      if (keywords.any(low.contains)) return l;
    }

    // 2) fallback: strongest uppercase-ish line near top
    final top = lines.take(6).toList();
    String? best;
    int bestScore = -999;

    for (final l in top) {
      if (RegExp(r'\d').hasMatch(l)) continue;
      final lettersOnly = l.replaceAll(RegExp(r'[^A-Za-z]'), '');
      if (lettersOnly.length < 4) continue;

      final upperCount = lettersOnly.split('').where((c) => c == c.toUpperCase()).length;
      final score = (upperCount * 2) + l.length;

      if (score > bestScore) {
        bestScore = score;
        best = l;
      }
    }
    return best;
  }

  static String? _pickName(List<String> lines, {String? company}) {
    final top = lines.take(8);

    for (final l in top) {
      final low = l.toLowerCase();

      if (company != null && l == company) continue;
      if (_emailRx.hasMatch(l)) continue;
      if (_urlRx.hasMatch(l)) continue;
      if (_phoneCandidateRx.hasMatch(l)) continue;

      // reject role/title lines (common on cards)
      if (low.contains('manager') ||
          low.contains('developer') ||
          low.contains('engineer') ||
          low.contains('director') ||
          low.contains('sales') ||
          low.contains('marketing') ||
          low.contains('founder') ||
          low.contains('ceo') ||
          low.contains('cto')) {
        continue;
      }

      if (RegExp(r'\d').hasMatch(l)) continue;

      final words = l.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (words.length >= 2 && words.length <= 4) {
        if (RegExp(r'[@:/]').hasMatch(l)) continue;
        return l;
      }
    }
    return null;
  }
}
