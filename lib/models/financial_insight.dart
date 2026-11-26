enum InsightType {
  opportunity, // Lazy money, higher yield available
  warning,     // Credit card due soon, upcoming bill shock
  praise,      // Good savings rate, yield milestone reached
  projection,  // Runway estimate, year-end wealth projection
}

class FinancialInsight {
  final String id;
  final String title;
  final String message;
  final InsightType type;
  final String? actionableButtonText;
  final String? highlightMetric;

  const FinancialInsight({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.actionableButtonText,
    this.highlightMetric,
  });
}

