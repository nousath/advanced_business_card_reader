class BusinessCardData {
  final String rawText;

  /// Best-effort predictions
  final String? name;
  final String? company;

  /// Best-effort extracted lists
  final List<String> phones;
  final List<String> emails;
  final List<String> websites;

  const BusinessCardData({
    required this.rawText,
    required this.name,
    required this.company,
    required this.phones,
    required this.emails,
    required this.websites,
  });

  BusinessCardData copyWith({
    String? rawText,
    String? name,
    String? company,
    List<String>? phones,
    List<String>? emails,
    List<String>? websites,
  }) {
    return BusinessCardData(
      rawText: rawText ?? this.rawText,
      name: name ?? this.name,
      company: company ?? this.company,
      phones: phones ?? this.phones,
      emails: emails ?? this.emails,
      websites: websites ?? this.websites,
    );
  }

  Map<String, dynamic> toJson() => {
        'rawText': rawText,
        'name': name,
        'company': company,
        'phones': phones,
        'emails': emails,
        'websites': websites,
      };

  static BusinessCardData fromJson(Map<String, dynamic> json) {
    return BusinessCardData(
      rawText: (json['rawText'] ?? '').toString(),
      name: json['name']?.toString(),
      company: json['company']?.toString(),
      phones: (json['phones'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      emails: (json['emails'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      websites: (json['websites'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
    );
  }
}
