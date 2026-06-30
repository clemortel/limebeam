import "package:flutter/material.dart";

import "../theme/app_theme.dart";

/// Text input (§2.7). Helper slot under the field doubles as the error slot.
/// Password fields get a reveal eye. Validation/error text is supplied by the
/// caller (computed in a notifier) — this widget holds no business logic.
class AppInput extends StatefulWidget {
  const AppInput({
    required this.controller,
    required this.placeholder,
    this.label,
    this.helperText,
    this.errorText,
    this.obscure = false,
    this.keyboardType,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.onEditingComplete,
    super.key,
  });

  final TextEditingController controller;
  final String placeholder;
  final String? label;
  final String? helperText;
  final String? errorText;
  final bool obscure;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final bool hasError = widget.errorText != null;

    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: t.radius.smAll,
          borderSide: BorderSide(color: color),
        );

    final Widget? suffix = widget.obscure
        ? GestureDetector(
            onTap: () => setState(() => _hidden = !_hidden),
            child: Icon(
              _hidden ? Icons.visibility_off : Icons.visibility,
              size: 20,
              color: t.colors.textTertiary,
            ),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.label != null) ...<Widget>[
          Text(
            widget.label!,
            style: t.typography.caption.copyWith(color: t.colors.textSecondary),
          ),
          SizedBox(height: t.space.x1),
        ],
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          obscureText: widget.obscure && _hidden,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onChanged: widget.onChanged,
          onEditingComplete: widget.onEditingComplete,
          style: t.typography.body.copyWith(color: t.colors.textPrimary),
          cursorColor: t.colors.accent,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: t.colors.bgInput,
            hintText: widget.placeholder,
            hintStyle: t.typography.body.copyWith(color: t.colors.textTertiary),
            contentPadding: EdgeInsets.symmetric(
              horizontal: t.space.x3,
              vertical: t.space.x3,
            ),
            suffixIcon: suffix,
            suffixIconConstraints: BoxConstraints(minWidth: t.space.x8),
            enabledBorder: border(t.colors.borderDefault),
            focusedBorder: border(t.colors.borderStrong),
            errorBorder: border(t.colors.error),
            focusedErrorBorder: border(t.colors.error),
          ),
        ),
        if (widget.helperText != null || hasError) ...<Widget>[
          SizedBox(height: t.space.x1),
          Text(
            widget.errorText ?? widget.helperText!,
            style: t.typography.caption.copyWith(
              color: hasError ? t.colors.error : t.colors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}
