import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'core/controller.dart';
import 'ui/theme.dart';
import 'ui/dialogs.dart';
import 'ui/shell.dart';
import 'ui/auth.dart';

SemanticsHandle? webSemanticsHandle;
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Make the Flutter web preview keyboard- and screen-reader-accessible immediately.
  if (kIsWeb) webSemanticsHandle = SemanticsBinding.instance.ensureSemantics();
  runApp(const RelayApp());
}

class RelayApp extends StatefulWidget {
  const RelayApp({super.key});
  @override
  State<RelayApp> createState() => _RelayAppState();
}

class _RelayAppState extends State<RelayApp> {
  final c = AppController();
  @override
  void initState() {
    super.initState();
    c.boot();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Relay · Thoughtful WhatsApp marketing',
        debugShowCheckedModeBanner: false,
        theme: relayTheme(),
        scaffoldMessengerKey: messengerKey,
        home: AnimatedBuilder(
            animation: c,
            builder: (context, _) {
              if (c.booting) {
                return const Scaffold(
                    body: Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                  Brand(),
                  SizedBox(height: 30),
                  SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(height: 18),
                  Text('Getting your workspace ready…',
                      style: TextStyle(fontSize: 11, color: muted))
                ])));
              }
              if (c.bootError != null) {
                return Scaffold(
                    body: Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 430),
                            child: EmptyState(
                                icon: Icons.wifi_off_rounded,
                                title: 'Let’s reconnect.',
                                description: c.bootError!,
                                action: ActionButton('Try again',
                                    primary: true, onPressed: c.boot)))));
              }
              if (c.user == null) return AuthPage(c);
              return AppShell(c);
            }),
      );
}
