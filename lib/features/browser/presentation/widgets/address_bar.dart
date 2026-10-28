import 'package:flutter/material.dart';

class AddressBar extends StatelessWidget {
  const AddressBar({
    super.key,
    required this.controller,
    required this.onOpen,
    required this.onReload,
    required this.onBack,
  });
  final TextEditingController controller;
  final VoidCallback onOpen;
  final VoidCallback onReload;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.go,
            autocorrect: false,
            keyboardType: TextInputType.url,
            onSubmitted: (_) => onOpen(),
            decoration: const InputDecoration(
              hintText: 'Search Google or enter a URL',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Go',
          onPressed: onOpen,
          icon: const Icon(Icons.arrow_forward),
        ),
        IconButton(
          tooltip: 'Reload',
          onPressed: onReload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
  );
}
