import 'package:flutter/material.dart';

import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppLockController();
  await controller.load();
  runApp(AppLockApp(controller: controller));
}
