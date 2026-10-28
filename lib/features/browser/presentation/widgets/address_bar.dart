import 'package:flutter/material.dart';

class AddressBar extends StatelessWidget {
  const AddressBar({
    super.key,
    required this.controller,
    required this.onOpen,
    required this.onReload,
  });
  final TextEditingController controller;
  final VoidCallback onOpen;
  final VoidCallback onReload;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.url,
            onSubmitted: (_) => onOpen(),
            decoration: const InputDecoration(
              hintText: 'https://example.com',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        IconButton(
          tooltip: 'فتح',
          onPressed: onOpen,
          icon: const Icon(Icons.arrow_forward),
        ),
        IconButton(
          tooltip: 'إعادة تحميل',
          onPressed: onReload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
  );
}
