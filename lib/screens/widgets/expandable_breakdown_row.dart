import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../services/advisor_engine.dart';

class ExpandableBreakdownRow extends StatefulWidget {
  final String label;
  final double amount;
  final Color color;
  final List<ProjectionLineItem> items;
  final bool negateItems;

  const ExpandableBreakdownRow({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
    this.items = const [],
    this.negateItems = false,
  });

  @override
  State<ExpandableBreakdownRow> createState() => _ExpandableBreakdownRowState();
}

class _ExpandableBreakdownRowState extends State<ExpandableBreakdownRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final hasItems = widget.items.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: hasItems ? () => setState(() => _expanded = !_expanded) : null,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.label,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasItems) ...[
                          const SizedBox(width: 4),
                          Icon(
                            _expanded ? Icons.expand_less : Icons.expand_more,
                            size: 15,
                            color: AppTheme.textMuted,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyFormat.formatMXN(widget.amount, includeDecimals: false),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && hasItems)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 4, left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surface.withOpacity(0.75),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: widget.color.withOpacity(0.6), width: 2),
                ),
              ),
              child: Column(
                children: widget.items.map((item) {
                  final displayAmt = widget.negateItems ? -item.amount : item.amount;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.subtitle != null && item.subtitle!.isNotEmpty)
                                Text(
                                  item.subtitle!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          CurrencyFormat.formatMXN(displayAmt, includeDecimals: false),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: widget.color.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

