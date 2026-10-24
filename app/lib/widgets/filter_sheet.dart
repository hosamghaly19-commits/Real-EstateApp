import '../data/district_store.dart';
import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/property.dart';
import '../models/property_filters.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class FilterSheet extends StatefulWidget {
  final PropertyFilters initial;
  final String listingType; // بيع / إيجار

  const FilterSheet({
    super.key,
    required this.initial,
    required this.listingType,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late Set<String> _districts;
  late double _maxPrice;
  String? _finishing;
  String? _payment;

  double get _limit => widget.listingType == 'بيع' ? 10000000 : 30000;

  @override
  void initState() {
    super.initState();
    _districts = {...widget.initial.districts};
    _maxPrice = (widget.initial.maxPrice ?? _limit).clamp(0, _limit);
    _finishing = widget.initial.finishing;
    _payment = widget.initial.payment;
  }

  void _reset() => setState(() {
        _districts.clear();
        _maxPrice = _limit;
        _finishing = null;
        _payment = null;
      });

  void _apply() {
    Navigator.pop(
      context,
      PropertyFilters(
        districts: _districts,
        maxPrice: _maxPrice >= _limit ? null : _maxPrice,
        finishing: _finishing,
        payment: _payment,
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(t,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.amber : AppTheme.outline(context)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.black : null)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMax = _maxPrice >= _limit;
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .88),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 20 + MediaQuery.of(context).viewPadding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.muted(context).withOpacity(.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text('تصفية النتائج',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              TextButton(
                onPressed: _reset,
                child: Text('إعادة ضبط',
                    style: TextStyle(color: AppTheme.accentText(context))),
              ),
            ],
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('الحي'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final d in DistrictStore.instance.names)
                        _chip(
                          label: d,
                          selected: _districts.contains(d),
                          onTap: () => setState(() => _districts.contains(d)
                              ? _districts.remove(d)
                              : _districts.add(d)),
                        ),
                    ],
                  ),
                  _label(widget.listingType == 'بيع'
                      ? 'أقصى سعر'
                      : 'أقصى إيجار شهري'),
                  Row(
                    children: [
                      Text(
                        isMax ? 'بدون حد' : '${formatNumber(_maxPrice.round())} ج.م',
                        style: TextStyle(
                            color: AppTheme.accentText(context),
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  Slider(
                    value: _maxPrice,
                    min: 0,
                    max: _limit,
                    divisions: 20,
                    onChanged: (v) => setState(() => _maxPrice = v),
                  ),
                  _label('التشطيب'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in finishingOptions)
                        _chip(
                          label: f,
                          selected: _finishing == f,
                          onTap: () => setState(
                              () => _finishing = _finishing == f ? null : f),
                        ),
                    ],
                  ),
                  _label('طريقة الدفع'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in paymentOptions)
                        _chip(
                          label: m,
                          selected: _payment == m,
                          onTap: () => setState(
                              () => _payment = _payment == m ? null : m),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _apply, child: const Text('عرض النتائج')),
        ],
      ),
    );
  }
}
