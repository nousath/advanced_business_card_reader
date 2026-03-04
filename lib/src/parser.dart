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

  static const List<String> _companyKeywords = [
    'pvt', 'pvt.', 'private', 'ltd', 'ltd.', 'limited', 'llp', 'llc', 'inc', 'inc.', 'corp', 'corporation',
    'co', 'co.', 'company', 'gmbh', 'sarl', 'bv', 'ag',
    'private limited', 'pvt ltd', 'pvt. ltd', 'opc', 'one person company',
    'technologies', 'technology', 'tech', 'solutions', 'systems', 'services', 'consulting', 'consultants',
    'enterprises', 'enterprise', 'industries', 'group', 'global', 'international',
    'trading', 'exports', 'import', 'imports', 'logistics', 'shipping',
    'construction', 'builders', 'infra', 'infrastructure',
    'pharma', 'pharmaceutical', 'hospital', 'clinic', 'diagnostics',
    'education', 'institute', 'academy', 'school', 'college',
    'finance', 'capital', 'investments', 'holdings',
    'studio', 'media', 'design', 'digital', 'marketing', 'advertising', 'creative',
    'manufacturing', 'factory',
    'l.l.c', 'fze', 'f.z.e', 'fz-llc', 'fzc', 'f.z.c',
    'freezone', 'free zone',
    'pjsc', 'p.j.s.c', 'psc', 'p.s.c',
    'est', 'est.', 'establishment',
    'general trading',
    'l.l.p', 'holding',
  ];

  static const List<String> _roleKeywords = [
    'manager',
    'developer',
    'engineer',
    'director',
    'sales',
    'marketing',
    'founder',
    'co-founder',
    'ceo',
    'cto',
    'cfo',
    'coo',
    'president',
    'vice president',
    'vp',
    'head',
    'lead',
    'consultant',
    'specialist',
    'executive',
    'officer',
    'assistant',
    'associate',
  ];

  static const List<String> _addressKeywords = [
    'street',
    'st.',
    'road',
    'rd.',
    'avenue',
    'ave',
    'lane',
    'ln.',
    'boulevard',
    'blvd',
    'building',
    'bldg',
    'floor',
    'flr',
    'suite',
    'unit',
    'tower',
    'block',
    'sector',
    'area',
    'city',
    'state',
    'district',
    'postal',
    'postcode',
    'zip',
    'pincode',
    'pin',
    'po box',
    'near',
    'opp',
    'nagar',
    'colony',
    'india',
    'uae',
  ];

  static BusinessCardData parse(
    String rawText, {
    String defaultIsoCountry = 'IN',

    /// If you want “auto country” for local numbers, pass multiple countries:
    /// e.g. ['IN','AE','US'].
    List<String>? tryIsoCountries,

    /// Output numbers as `+<countryCode><nsn>`
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

    final companyPick = _pickCompanyPick(lines);
    final company = _pickCompany(lines) ?? companyPick.text;
    final name = _pickName(
      lines,
      company: company,
      blockedIndices: companyPick.indices.toSet(),
    );

    return BusinessCardData(
      rawText: text,
      name: name,
      company: company,
      phones: phones,
      emails: emails,
      websites: websites,
    );
  }

  static bool _looksLikeContactLine(String line) {
    if (line.trim().isEmpty) return false;
    return _emailRx.hasMatch(line) || _urlRx.hasMatch(line) || _phoneCandidateRx.hasMatch(line);
  }

  static double _upperRatio(String line) {
    final letters = RegExp(r'[A-Za-z]').allMatches(line).length;
    if (letters == 0) return 0;
    final uppers = RegExp(r'[A-Z]').allMatches(line).length;
    return uppers / letters;
  }

  static bool _hasLegalSuffix(String line) {
    final low = line.toLowerCase();
    const legal = [
      'pvt',
      'pvt.',
      'private limited',
      'ltd',
      'ltd.',
      'limited',
      'llp',
      'l.l.p',
      'llc',
      'l.l.c',
      'inc',
      'inc.',
      'company',
      'co.',
      'corp',
      'corporation',
      'gmbh',
      'sarl',
      'ag',
      'bv',
    ];
    return legal.any(low.contains);
  }

  static String _joinLines(List<String> spanLines) {
    return spanLines.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Normalized email used for merge de-duplication.
  static String normalizeEmailForMerge(String email) {
    return email.trim().toLowerCase();
  }

  /// Normalized website used for merge de-duplication and output.
  static String normalizeWebsiteForMerge(String website) {
    final trimmed = website.trim();
    if (trimmed.isEmpty) return '';
    return _normalizeWebsite(trimmed);
  }

  /// Normalized phone used for merge de-duplication and output.
  static String normalizePhoneForMerge(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return '';
    final cleaned = trimmed.replaceAll(RegExp(r'[^\d+]'), '');
    final digits = cleaned.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    return cleaned.startsWith('+') ? '+$digits' : digits;
  }

  static BusinessCardData mergeEntityContacts(
    BusinessCardData base,
    Iterable<Map<String, dynamic>> entities, {
    String defaultIsoCountry = 'IN',
    List<String>? tryIsoCountries,
    bool phoneAsE164 = true,
  }) {
    final phones = <String>{...base.phones};
    final emails = <String>{...base.emails};
    final websites = <String>{...base.websites};
    final phoneCandidates = <String>[];

    for (final entity in entities) {
      final type = entity['type']?.toString().toLowerCase().trim() ?? '';
      final text = entity['text']?.toString().trim() ?? '';
      if (text.isEmpty) continue;

      switch (type) {
        case 'phone':
        case 'phone_number':
          phoneCandidates.add(text);
          break;
        case 'email':
          if (_emailRx.hasMatch(text)) emails.add(text);
          break;
        case 'url':
        case 'website':
          websites.add(_normalizeWebsite(text));
          break;
      }
    }

    phones.addAll(
      _normalizePhoneCandidates(
        phoneCandidates,
        defaultIsoCountry: defaultIsoCountry,
        tryIsoCountries: tryIsoCountries,
        asE164: phoneAsE164,
      ),
    );

    return base.copyWith(
      phones: phones.toList(),
      emails: emails.toList(),
      websites: websites.toList(),
    );
  }

  static List<String> _extractPhones(
    String text, {
    required String defaultIsoCountry,
    List<String>? tryIsoCountries,
    bool asE164 = true,
  }) {
    final candidates = _phoneCandidateRx.allMatches(text).map((m) => m.group(0)!.trim());
    return _normalizePhoneCandidates(
      candidates,
      defaultIsoCountry: defaultIsoCountry,
      tryIsoCountries: tryIsoCountries,
      asE164: asE164,
    );
  }

  static List<String> _normalizePhoneCandidates(
    Iterable<String> candidates, {
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

    for (final rawCandidate in candidates) {
      var candidate = rawCandidate.trim();

      // handle 00-prefixed international numbers: 00971... -> +971...
      candidate = candidate.replaceFirst(RegExp(r'^00'), '+');

      // remove obvious extension part (ext / x / #)
      candidate = candidate.split(RegExp(r'\b(ext|extension|x|#)\b', caseSensitive: false)).first.trim();

      final cleaned = candidate.replaceAll(RegExp(r'[^\d+]'), '');
      final digitsOnly = cleaned.replaceAll(RegExp(r'\D'), '');
      final digitsCount = digitsOnly.length;
      if (digitsCount < 8) continue;

      final looseCandidate = cleaned.startsWith('+') ? '+$digitsOnly' : digitsOnly;
      var parsed = false;

      // Case 1: already international => country code is inside the number
      if (cleaned.startsWith('+')) {
        try {
          final p = PhoneNumber.parse(candidate); // detects iso from +code
          if (p.isValid()) {
            out.add(asE164 ? _toE164(p) : p.international);
            parsed = true;
          }
        } catch (_) {}
        if (!parsed) {
          out.add(looseCandidate);
        }
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

      if (best != null) {
        out.add(asE164 ? _toE164(best) : best.international);
        parsed = true;
      }

      if (!parsed) {
        out.add(looseCandidate);
      }
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

  static String? _pickCompany(List<String> lines) => _pickCompanyPick(lines).text;

  static _CompanyPick _pickCompanyPick(List<String> lines) {
    if (lines.isEmpty) {
      return const _CompanyPick(text: null, indices: <int>[], score: -9999);
    }

    _CompanyPick? best;
    final n = lines.length;

    for (var start = 0; start < n; start++) {
      for (var spanLength = 1; spanLength <= 3; spanLength++) {
        final end = start + spanLength;
        if (end > n) break;

        final spanIndices = List<int>.generate(spanLength, (i) => start + i);
        final spanLines = <String>[
          for (final idx in spanIndices) lines[idx],
        ];

        if (spanLines.any(_looksLikeContactLine)) {
          continue; // hard reject contact-heavy spans
        }

        final joined = _joinLines(spanLines);
        if (joined.isEmpty) continue;

        var score = 0;
        final joinedLow = joined.toLowerCase();

        if (_hasAnyKeyword(joinedLow, _companyKeywords)) score += 10;
        if (_hasLegalSuffix(spanLines.last)) {
          score += 12;
        } else if (spanLines.any(_hasLegalSuffix)) {
          score += 8;
        }
        if (_upperRatio(joined) >= 0.65) score += 6;
        if (spanIndices.any((i) => i < 6)) score += 4;
        if (spanIndices.any((i) => i >= n - 6)) score += 4;
        if (spanLines.any(_hasRoleKeyword)) score -= 8;
        if (spanLines.any(_hasAddressKeyword)) score -= 6;

        final digitCount = RegExp(r'\d').allMatches(joined).length;
        if (digitCount >= 6 || (joined.isNotEmpty && (digitCount / joined.length) > 0.18)) {
          score -= 5;
        }

        final len = joined.length;
        if (len >= 8 && len <= 48) {
          score += 3;
        } else if (len >= 5 && len <= 64) {
          score += 1;
        }
        if (spanLength > 1) {
          score += 2 + (spanLength - 2); // continuity bonus for 2-3 line company spans
        }
        if (len > 80) score -= 6;
        if (len > 120) score -= 8;

        final letterCount = RegExp(r'[A-Za-z]').allMatches(joined).length;
        if (letterCount < 3) score -= 8;
        if (spanLength >= 2 && _upperRatio(spanLines.first) >= 0.70) score += 2;

        if (best == null || score > best.score) {
          best = _CompanyPick(
            text: joined,
            indices: spanIndices,
            score: score,
          );
        }
      }
    }

    if (best == null || best.score < 8) {
      return const _CompanyPick(text: null, indices: <int>[], score: -9999);
    }

    return best;
  }

  static String? _pickName(
    List<String> lines, {
    String? company,
    Set<int>? blockedIndices,
  }) {
    final blocked = <int>{...?blockedIndices};
    if (blocked.isEmpty) {
      blocked.addAll(_pickCompanyPick(lines).indices);
    }

    final limit = lines.length < 12 ? lines.length : 12;
    for (var i = 0; i < limit; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      if (blocked.contains(i)) continue;
      if (company != null && company.contains(line)) continue;
      if (_looksLikeContactLine(line)) continue;
      if (_hasRoleKeyword(line)) continue;
      if (_hasAddressKeyword(line)) continue;
      if (_hasLegalSuffix(line)) continue;
      if (_hasAnyKeyword(line.toLowerCase(), _companyKeywords)) continue;
      if (RegExp(r'\d').hasMatch(line)) continue;
      if (RegExp(r'[@:/]').hasMatch(line)) continue;

      final words = line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (words.length < 2 || words.length > 4) continue;

      final lettersOnly = line.replaceAll(RegExp(r'[^A-Za-z ]'), '').replaceAll(' ', '');
      if (lettersOnly.length < 4) continue;
      if (_upperRatio(line) > 0.85) continue; // likely company-style all-caps line

      return line;
    }

    return null;
  }

  static bool _hasAnyKeyword(String haystackLower, List<String> keywords) {
    return keywords.any(haystackLower.contains);
  }

  static bool _hasRoleKeyword(String line) {
    return _hasAnyKeyword(line.toLowerCase(), _roleKeywords);
  }

  static bool _hasAddressKeyword(String line) {
    return _hasAnyKeyword(line.toLowerCase(), _addressKeywords);
  }
}

class _CompanyPick {
  final String? text;
  final List<int> indices;
  final int score;

  const _CompanyPick({
    required this.text,
    required this.indices,
    required this.score,
  });
}
