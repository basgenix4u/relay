import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_app/core/controller.dart';
import 'package:relay_app/ui/theme.dart';
import 'package:relay_app/ui/shell.dart';
import 'package:relay_app/ui/dialogs.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
  });
  testWidgets('Brand and consent labels render', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: relayTheme(),
        home: const Scaffold(
            body: Column(children: [
          Brand(),
          StatusPill('opted_in'),
          StatusPill('unsubscribed')
        ]))));
    expect(find.text('relay'), findsOneWidget);
    expect(find.text('Opted in'), findsOneWidget);
    expect(find.text('Unsubscribed'), findsOneWidget);
  });

  for (final width in [390.0, 1440.0]) {
    for (final page in [
      AppPage.overview,
      AppPage.contacts,
      AppPage.groups,
      AppPage.campaigns,
      AppPage.templates,
      AppPage.analytics
    ]) {
      testWidgets('$page has a responsive empty state at width $width',
          (tester) async {
        tester.view.physicalSize = Size(width, 960);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = AppController();
        c.user = {
          'name': 'Alex Morgan',
          'workspace': 'Acme Studio',
          'email': 'alex@relay.demo',
          'demo': true,
          'settings': {'delivery_notifications': true}
        };
        c.page = page;
        c.dashboard = {
          'total_contacts': 0,
          'new_contacts': 0,
          'messages_sent': 0,
          'delivery_rate': 0,
          'read_rate': 0,
          'active_campaigns': 0,
          'total_campaigns': 0,
          'chart': [],
          'segments': [],
          'recent_campaigns': [],
          'activities': []
        };
        await tester.pumpWidget(MaterialApp(
            theme: relayTheme(),
            scaffoldMessengerKey: messengerKey,
            home: AppShell(c)));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
      });
    }
  }

  final fixture = jsonDecode(File('test/fixtures/demo.json').readAsStringSync())
      as Map<String, dynamic>;
  AppController populated(AppPage page) {
    final c = AppController();
    c.user = Map<String, dynamic>.from(fixture['user']);
    c.user!['workspace'] =
        'A very long business workspace name that should truncate safely in a narrow desktop header';
    c.dashboard = Map<String, dynamic>.from(fixture['dashboard']);
    c.contactData = Map<String, dynamic>.from(fixture['contactData']);
    c.groups = fixture['groups'];
    c.campaigns = fixture['campaigns'];
    c.templates = fixture['templates'];
    c.activities = fixture['activities'];
    c.integration = Map<String, dynamic>.from(fixture['integration']);
    c.page = page;
    return c;
  }

  for (final width in [320.0, 1100.0]) {
    for (final page in [
      AppPage.overview,
      AppPage.contacts,
      AppPage.groups,
      AppPage.campaigns,
      AppPage.templates,
      AppPage.analytics
    ]) {
      testWidgets('Populated $page fits width $width with long workspace names',
          (tester) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = populated(page);
        await tester.pumpWidget(MaterialApp(
            theme: relayTheme(),
            scaffoldMessengerKey: messengerKey,
            home: AppShell(c)));
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
      });
    }
  }
  testWidgets('Mobile drawer scrolls safely on a short screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = populated(AppPage.overview);
    await tester.pumpWidget(MaterialApp(
        theme: relayTheme(),
        scaffoldMessengerKey: messengerKey,
        home: AppShell(c)));
    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
}
