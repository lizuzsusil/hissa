import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../theme/app_theme.dart';

/// A large, currency-aware amount input with Indian digit grouping.
class AmountField extends StatefulWidget {
  final Money? value;
  final ValueChanged<Money> onChanged;
  final String? label;
  final String? hint;
  final String? errorText;
  final bool autofocus;
  final bool enabled;

  const AmountField({
    super.key,
    this.value,
    required this.onChanged,
    this.label,
    this.hint,
    this.errorText,
    this.autofocus = false,
    this.enabled = true,
  });

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  late final TextEditingController _controller;
  Money _money = Money.zero();

  static final NumberFormat _numWhole = NumberFormat.decimalPattern('en_IN');
  static final NumberFormat _numDecimal = NumberFormat.currency(
    symbol: '',
    decimalDigits: 2,
    locale: 'en_IN',
  );

  @override
  void initState() {
    super.initState();
    _money = widget.value ?? Money.zero();
    _controller = TextEditingController(text: _format(_money));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _format(Money money) {
    if (money.isZero) return '';
    final major = money.paisa.abs() / 100;
    final isWhole = major == major.roundToDouble();
    if (isWhole) {
      return _numWhole.format(major.round());
    }
    return _numDecimal.format(major);
  }

  void _onChanged(String raw) {
    final cleaned = raw.replaceAll(',', '').trim();
    if (cleaned.isEmpty) {
      _money = Money.zero();
      widget.onChanged(Money.zero());
      return;
    }
    final parsed = double.tryParse(cleaned);
    if (parsed == null) {
      _controller.value = _controller.value.copyWith(
        text: _format(_money),
        selection: TextSelection.collapsed(offset: _format(_money).length),
      );
      return;
    }
    _money = Money((parsed * 100).round());
    widget.onChanged(_money);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _controller,
          autofocus: widget.autofocus,
          enabled: widget.enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          onChanged: _onChanged,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          decoration: InputDecoration(
            hintText: widget.hint ?? '0.00',
            errorText: widget.errorText,
            errorMaxLines: 2,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 6),
              child: Text(
                'Rs.',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
          ),
        ),
      ],
    );
  }
}
