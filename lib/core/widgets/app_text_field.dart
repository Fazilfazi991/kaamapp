import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.controller,
    this.onChanged,
    this.enabled,
    this.obscureText = false,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    this.inputFormatters,
  });

  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool? enabled;
  final bool obscureText;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      enabled: enabled,
      obscureText: obscureText,
      readOnly: readOnly,
      onTap: onTap,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
