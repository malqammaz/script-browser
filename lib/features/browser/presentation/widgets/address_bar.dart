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
          tooltip: 'رجوع',
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
              hintText: 'ابحث في Google أو أدخل رابطاً',
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
