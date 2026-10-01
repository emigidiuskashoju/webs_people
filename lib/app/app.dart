import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme.dart';

class WebsApp extends StatelessWidget {
  const WebsApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Webs',
      theme: WebsTheme.light,

      // IMPORTANT:
      // Every time the app starts, show Login first.
      initialRoute: WebsRoutes.login,

      routes: WebsRoutes.routes,
    );
  }
}