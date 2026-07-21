import 'package:flutter/material.dart';

class CompanyMark extends StatelessWidget {
  const CompanyMark({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(compact ? 12 : 18),
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 10 : 14),
            child: Icon(
              Icons.precision_manufacturing_outlined,
              color: colorScheme.onPrimary,
              size: compact ? 26 : 38,
            ),
          ),
        ),
        SizedBox(width: compact ? 12 : 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ARTE IN FERRO',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontSize: compact ? 17 : 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
            ),
            Text(
              'LASCARI APP',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.secondary,
                    letterSpacing: 2.2,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
