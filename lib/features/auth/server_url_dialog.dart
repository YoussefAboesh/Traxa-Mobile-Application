import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/env/server_config.dart';

/// Lets the user enter ONE server URL (local IP of the server machine,
/// e.g. `https://192.168.1.17:3443`, or the deployment URL, e.g.
/// `https://traxa-system.online`). Returns `true` if the URL was changed.
Future<bool> showServerUrlDialog(BuildContext context) async {
  final controller = TextEditingController(text: ServerConfig.currentUrl);
  final formKey = GlobalKey<FormState>();
  final theme = Theme.of(context);

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.dns_rounded, color: theme.primaryColor, size: 22.sp),
          SizedBox(width: 10.w),
          const Text('Server URL'),
        ],
      ),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the local IP of the server (e.g. https://192.168.1.17:3443) '
              'or the deployment URL (e.g. https://traxa-system.online).',
              style: TextStyle(fontSize: 12.sp, color: theme.hintColor),
            ),
            SizedBox(height: 14.h),
            TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'https://192.168.1.17:3443',
                border: OutlineInputBorder(),
              ),
              validator: (v) => ServerConfig.validate(v ?? ''),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            await ServerConfig.setUrl(controller.text);
            if (ctx.mounted) Navigator.pop(ctx, true);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );

  return saved ?? false;
}
