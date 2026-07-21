import 'package:flutter/material.dart';

class CompanyMark extends StatelessWidget {
  const CompanyMark({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/logo_arte_in_ferro.png',
      height: compact ? 42 : 96,
      width: compact ? 190 : 330,
      fit: BoxFit.contain,
      semanticLabel: 'Arte In Ferro - dall’artigianato all’industria',
    );
  }
}
