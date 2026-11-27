import 'package:flutter/material.dart';

class MovementCategory {
  final String id;
  final String name;
  final bool isExpense;
  final bool isIncome;
  final int iconCodePoint;
  final String colorHex;
  final List<String> keywords;

  const MovementCategory({
    required this.id,
    required this.name,
    this.isExpense = true,
    required this.isIncome,
    required this.iconCodePoint,
    required this.colorHex,
    this.keywords = const [],
  });

  String get scopeLabel {
    if (isExpense && isIncome) return 'Gasto e Ingreso';
    if (isIncome) return 'Ingreso';
    return 'Gasto';
  }

  static const Set<String> _stopWords = {
    'de',
    'del',
    'la',
    'las',
    'el',
    'los',
    'un',
    'una',
    'unos',
    'unas',
    'en',
    'con',
    'para',
    'por',
    'al',
    'mi',
    'mis',
    'tu',
    'tus',
    'su',
    'sus',
    'y',
    'o',
    'e',
    'a',
    'pago',
    'compra',
    'gasto',
    'cargo',
  };

  /// Normalizes text for case-insensitive and accent-insensitive keyword matching.
  static String normalizeText(String input) {
    var s = input.toLowerCase().trim();
    const replacements = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
    };
    replacements.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  /// Extracts meaningful normalized words from a movement description for keyword learning.
  static List<String> extractCandidateWords(String input) {
    final normalized = normalizeText(input);
    if (normalized.isEmpty) return const [];
    final tokens = normalized
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) =>
            t.length >= 2 &&
            !_stopWords.contains(t) &&
            double.tryParse(t) == null)
        .toSet()
        .toList();
    return tokens;
  }

  /// Built-in merchant keyword dictionary for out-of-the-box categorization (Mexican & common brands).
  static const Map<String, List<String>> builtInMerchantKeywords = {
    'Transporte': [
      'uber',
      'didi',
      'indriver',
      'cabify',
      'pemex',
      'costco gas',
      'mobil',
      'shell',
      'bp ',
      'gasolinera',
      'caseta',
      'capufe',
      'televia',
      'pase',
      'estacionamiento',
      'aeromexico',
      'volaris',
      'vivaaerobus',
      'ado',
    ],
    'Comida': [
      'uber eats',
      'ubereats',
      'rappi',
      'didi food',
      'didifood',
      'starbucks',
      'mcdonalds',
      'burger king',
      'dominos',
      'little caesars',
      'kfc',
      'vips',
      'toks',
      'sanborns',
      'chilis',
      'wings',
      'tacos',
      'restaurante',
      'cafeteria',
      'cafe',
      'panaderia',
      'el globo',
      'la esperanza',
      'sushi',
      'pizza',
    ],
    'Supermercado': [
      'walmart',
      'chedraui',
      'soriana',
      'la comer',
      'city market',
      'fresko',
      'bodega aurrera',
      'aurrera',
      'heb',
      'costco',
      'sams',
      'oxxo',
      '7-eleven',
      '7 eleven',
      'circle k',
      'superama',
      'supermercado',
    ],
    'Servicios': [
      'cfe',
      'telmex',
      'telcel',
      'at&t',
      'movistar',
      'totalplay',
      'total play',
      'izzi',
      'megacable',
      'sky',
      'naturgy',
      'agua',
      'luz',
      'internet',
      'recarga',
      'predial',
    ],
    'Entretenimiento': [
      'netflix',
      'spotify',
      'disney',
      'hbo',
      'prime video',
      'youtube',
      'cinepolis',
      'cinemex',
      'ticketmaster',
      'boletia',
      'steam',
      'playstation',
      'xbox',
      'nintendo',
      'twitch',
    ],
    'Salud': [
      'farmacia',
      'guadalajara',
      'benavides',
      'similares',
      'del ahorro',
      'san pablo',
      'hospital',
      'clinica',
      'chopo',
      'salud digna',
      'dentista',
      'optica',
      'medico',
    ],
    'Compras': [
      'amazon',
      'mercado libre',
      'mercadolibre',
      'merpago',
      'liverpool',
      'palacio de hierro',
      'sears',
      'coppel',
      'elektra',
      'zara',
      'shein',
      'temu',
      'aliexpress',
      'ali ',
      'apple store',
      'home depot',
      'office depot',
      'steren',
      'petco',
      'pay pal',
      'paypal',
    ],
  };

  /// Matches a description against [builtInMerchantKeywords], preferring longest phrase match.
  static String? matchBuiltInCategory(String description) {
    final norm = normalizeText(description);
    if (norm.isEmpty) return null;
    String? bestCategory;
    int bestLen = 0;
    builtInMerchantKeywords.forEach((category, keywords) {
      for (final rawKw in keywords) {
        final kw = normalizeText(rawKw);
        if (kw.isEmpty) continue;
        final pattern = RegExp('(^|[^a-z0-9])${RegExp.escape(kw)}([^a-z0-9]|\$)');
        if (pattern.hasMatch(norm) && kw.length > bestLen) {
          bestLen = kw.length;
          bestCategory = category;
        }
      }
    });
    return bestCategory;
  }

  static const List<String> colorPaletteHex = [
    '#EF4444', // Coral Red
    '#F97316', // Orange
    '#F59E0B', // Amber Gold
    '#10B981', // Emerald Green
    '#14B8A6', // Teal
    '#06B6D4', // Electric Cyan
    '#3B82F6', // Royal Blue
    '#8B5CF6', // Violet
    '#EC4899', // Pink
    '#64748B', // Slate
  ];

  // Keep const IconData references so Flutter web icon tree-shaking preserves them.
  static const List<IconData> iconOptions = [
    Icons.restaurant,
    Icons.directions_car,
    Icons.shopping_cart,
    Icons.bolt,
    Icons.movie,
    Icons.medical_services,
    Icons.shopping_bag,
    Icons.inventory_2,
    Icons.work,
    Icons.laptop_mac,
    Icons.card_giftcard,
    Icons.savings,
    Icons.trending_up,
    Icons.attach_money,
    Icons.home,
    Icons.flight,
    Icons.pets,
    Icons.sports_esports,
    Icons.fitness_center,
    Icons.school,
    Icons.local_cafe,
    Icons.subscriptions,
    Icons.build,
    Icons.category,
  ];

  IconData get iconData {
    for (final icon in iconOptions) {
      if (icon.codePoint == iconCodePoint) return icon;
    }
    return Icons.category;
  }

  Color get color {
    final cleaned = colorHex.replaceAll('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return const Color(0xFF10B981);
    return Color(cleaned.length == 6 ? (0xFF000000 | value) : value);
  }

  MovementCategory copyWith({
    String? id,
    String? name,
    bool? isExpense,
    bool? isIncome,
    int? iconCodePoint,
    String? colorHex,
    List<String>? keywords,
  }) {
    return MovementCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      isExpense: isExpense ?? this.isExpense,
      isIncome: isIncome ?? this.isIncome,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorHex: colorHex ?? this.colorHex,
      keywords: keywords ?? this.keywords,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isExpense': isExpense,
        'isIncome': isIncome,
        'iconCodePoint': iconCodePoint,
        'colorHex': colorHex,
        'keywords': keywords,
      };

  factory MovementCategory.fromJson(Map<String, dynamic> json) {
    final isIncome = json['isIncome'] as bool? ?? false;
    final isExpense = json['isExpense'] as bool? ?? !isIncome;
    final rawKeywords = (json['keywords'] as List<dynamic>?) ?? const [];
    final keywords = rawKeywords
        .map((e) => normalizeText(e.toString()))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    return MovementCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      isExpense: isExpense,
      isIncome: isIncome,
      iconCodePoint: (json['iconCodePoint'] as int?) ?? Icons.category.codePoint,
      colorHex: (json['colorHex'] as String?) ?? '#10B981',
      keywords: keywords,
    );
  }

  static List<MovementCategory> defaultCategories() => [
        // Gastos
        MovementCategory(
          id: 'cat_exp_comida',
          name: 'Comida',
          isIncome: false,
          iconCodePoint: Icons.restaurant.codePoint,
          colorHex: '#F97316',
        ),
        MovementCategory(
          id: 'cat_exp_transporte',
          name: 'Transporte',
          isIncome: false,
          iconCodePoint: Icons.directions_car.codePoint,
          colorHex: '#3B82F6',
        ),
        MovementCategory(
          id: 'cat_exp_super',
          name: 'Supermercado',
          isIncome: false,
          iconCodePoint: Icons.shopping_cart.codePoint,
          colorHex: '#10B981',
        ),
        MovementCategory(
          id: 'cat_exp_servicios',
          name: 'Servicios',
          isIncome: false,
          iconCodePoint: Icons.bolt.codePoint,
          colorHex: '#F59E0B',
        ),
        MovementCategory(
          id: 'cat_exp_entretenimiento',
          name: 'Entretenimiento',
          isIncome: false,
          iconCodePoint: Icons.movie.codePoint,
          colorHex: '#8B5CF6',
        ),
        MovementCategory(
          id: 'cat_exp_salud',
          name: 'Salud',
          isIncome: false,
          iconCodePoint: Icons.medical_services.codePoint,
          colorHex: '#EF4444',
        ),
        MovementCategory(
          id: 'cat_exp_compras',
          name: 'Compras',
          isIncome: false,
          iconCodePoint: Icons.shopping_bag.codePoint,
          colorHex: '#EC4899',
        ),
        MovementCategory(
          id: 'cat_exp_varios',
          name: 'Varios',
          isIncome: false,
          iconCodePoint: Icons.inventory_2.codePoint,
          colorHex: '#64748B',
        ),
        // Ingresos
        MovementCategory(
          id: 'cat_inc_sueldo',
          name: 'Sueldo',
          isExpense: false,
          isIncome: true,
          iconCodePoint: Icons.work.codePoint,
          colorHex: '#10B981',
        ),
        MovementCategory(
          id: 'cat_inc_freelance',
          name: 'Freelance',
          isExpense: false,
          isIncome: true,
          iconCodePoint: Icons.laptop_mac.codePoint,
          colorHex: '#06B6D4',
        ),
        MovementCategory(
          id: 'cat_inc_bono',
          name: 'Bono / Regalo',
          isExpense: false,
          isIncome: true,
          iconCodePoint: Icons.card_giftcard.codePoint,
          colorHex: '#EC4899',
        ),
        MovementCategory(
          id: 'cat_inc_reembolso',
          name: 'Reembolso',
          isExpense: false,
          isIncome: true,
          iconCodePoint: Icons.savings.codePoint,
          colorHex: '#14B8A6',
        ),
        MovementCategory(
          id: 'cat_inc_rendimientos',
          name: 'Rendimientos',
          isExpense: false,
          isIncome: true,
          iconCodePoint: Icons.trending_up.codePoint,
          colorHex: '#3B82F6',
        ),
        MovementCategory(
          id: 'cat_inc_otro',
          name: 'Otro Ingreso',
          isExpense: false,
          isIncome: true,
          iconCodePoint: Icons.attach_money.codePoint,
          colorHex: '#F59E0B',
        ),
      ];
}

