import 'package:flutter/material.dart';

class CitationChip extends StatelessWidget {
  const CitationChip({super.key, required this.citation});

  final String citation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Chip(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        avatar: Icon(Icons.menu_book_outlined, size: 16, color: scheme.primary),
        label: Text(
          citation,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}
