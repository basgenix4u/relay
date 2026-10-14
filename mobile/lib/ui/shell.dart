import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/controller.dart';
import 'theme.dart';
import 'dialogs.dart';
import 'pages.dart';

const pageNames = {
  AppPage.overview: 'Overview',
  AppPage.contacts: 'Contacts',
  AppPage.groups: 'Contact groups',
  AppPage.campaigns: 'Campaigns',
  AppPage.templates: 'Templates',
  AppPage.analytics: 'Analytics',
  AppPage.settings: 'Settings'
};
const pageIcons = {
  AppPage.overview: Icons.grid_view_outlined,
  AppPage.contacts: Icons.people_outline_rounded,
  AppPage.groups: Icons.workspaces_outline,
  AppPage.campaigns: Icons.send_outlined,
  AppPage.templates: Icons.description_outlined,
  AppPage.analytics: Icons.bar_chart_rounded,
  AppPage.settings: Icons.settings_outlined
};

class SearchIntent extends Intent {
  const SearchIntent();
}

class AppShell extends StatefulWidget {
  final AppController c;
  const AppShell(this.c, {super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final scroll = ScrollController();
  AppPage? lastPage;
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    if (c.page != lastPage) {
      lastPage = c.page;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.jumpTo(0);
      });
    }
    final dialogs = Dialogs(context, c);
    return Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK):
              const SearchIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
              const SearchIntent()
        },
        child: Actions(
            actions: {
              SearchIntent: CallbackAction<SearchIntent>(onInvoke: (_) {
                dialogs.search();
                return null;
              })
            },
            child: LayoutBuilder(builder: (ctx, size) {
              final desktop = size.maxWidth >= 1050;
              Widget page;
              switch (c.page) {
                case AppPage.overview:
                  page = OverviewPage(c);
                  break;
                case AppPage.contacts:
                  page = ContactsPage(c);
                  break;
                case AppPage.groups:
                  page = GroupsPage(c);
                  break;
                case AppPage.campaigns:
                  page = CampaignsPage(c);
                  break;
                case AppPage.templates:
                  page = TemplatesPage(c);
                  break;
                case AppPage.analytics:
                  page = AnalyticsPage(c);
                  break;
                case AppPage.settings:
                  page = SettingsPage(c);
                  break;
              }
              return Scaffold(
                key: scaffoldKey,
                drawer: desktop
                    ? null
                    : Drawer(
                        width: 254,
                        backgroundColor: Colors.white,
                        surfaceTintColor: Colors.transparent,
                        child: SafeArea(
                            child: Sidebar(c, onNavigate: (p) {
                          Navigator.pop(context);
                          c.navigate(p);
                        }, onHelp: () {
                          Navigator.pop(context);
                          dialogs.help();
                        }))),
                body: SafeArea(
                    child: Row(children: [
                  if (desktop) ...[
                    SizedBox(
                        width: 222,
                        child: Sidebar(c,
                            onNavigate: c.navigate, onHelp: dialogs.help)),
                    const VerticalDivider(width: 1)
                  ],
                  Expanded(
                      child: Column(children: [
                    Header(c,
                        desktop: desktop,
                        onMenu: () => scaffoldKey.currentState?.openDrawer()),
                    if (c.refreshing)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                        child: Scrollbar(
                            controller: scroll,
                            child: SingleChildScrollView(
                                controller: scroll,
                                padding: EdgeInsets.fromLTRB(desktop ? 30 : 18,
                                    desktop ? 27 : 24, desktop ? 30 : 18, 28),
                                child: Align(
                                    alignment: Alignment.topCenter,
                                    child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                            maxWidth: 1350),
                                        child: AnimatedSwitcher(
                                            duration: const Duration(
                                                milliseconds: 180),
                                            layoutBuilder:
                                                (current, previous) => Stack(
                                                      alignment:
                                                          Alignment.topCenter,
                                                      children: [
                                                        ...previous,
                                                        if (current != null)
                                                          current
                                                      ],
                                                    ),
                                            child: KeyedSubtree(
                                                key: ValueKey(c.page),
                                                child: page)))))))
                  ])),
                ])),
                bottomNavigationBar: desktop
                    ? null
                    : NavigationBar(
                        height: 62,
                        backgroundColor: Colors.white,
                        surfaceTintColor: Colors.transparent,
                        indicatorColor: paleGreen,
                        labelBehavior:
                            NavigationDestinationLabelBehavior.alwaysShow,
                        selectedIndex: c.page == AppPage.overview
                            ? 0
                            : c.page == AppPage.contacts
                                ? 1
                                : c.page == AppPage.campaigns
                                    ? 2
                                    : 3,
                        onDestinationSelected: (i) {
                          if (i == 3) {
                            scaffoldKey.currentState?.openDrawer();
                            return;
                          }
                          c.navigate([
                            AppPage.overview,
                            AppPage.contacts,
                            AppPage.campaigns
                          ][i]);
                        },
                        destinations: const [
                            NavigationDestination(
                                icon: Icon(Icons.grid_view_outlined, size: 19),
                                label: 'Overview'),
                            NavigationDestination(
                                icon: Icon(Icons.people_outline_rounded,
                                    size: 20),
                                label: 'Contacts'),
                            NavigationDestination(
                                icon: Icon(Icons.send_outlined, size: 19),
                                label: 'Campaigns'),
                            NavigationDestination(
                                icon: Icon(Icons.menu_rounded, size: 20),
                                label: 'More')
                          ]),
              );
            })));
  }
}

class Sidebar extends StatelessWidget {
  final AppController c;
  final ValueChanged<AppPage> onNavigate;
  final VoidCallback onHelp;
  const Sidebar(this.c,
      {super.key, required this.onNavigate, required this.onHelp});
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final showPlan = constraints.maxHeight >= 820;
        return SingleChildScrollView(
            child: SizedBox(
          height: math.max(constraints.maxHeight, showPlan ? 810.0 : 650.0),
          child: _contents(context, showPlan),
        ));
      });
  Widget _contents(BuildContext context, bool showPlan) => Container(
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
            padding: EdgeInsets.fromLTRB(24, 26, 24, 33), child: Brand()),
        const Padding(
            padding: EdgeInsets.only(left: 24, bottom: 13),
            child: Text('WORKSPACE',
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.4,
                    color: Color(0xFFA0A69C)))),
        ...[
          AppPage.overview,
          AppPage.contacts,
          AppPage.groups,
          AppPage.campaigns,
          AppPage.templates,
          AppPage.analytics
        ].map((p) => _nav(p)),
        const SizedBox(height: 28),
        const Padding(
            padding: EdgeInsets.only(left: 24, bottom: 13),
            child: Text('PREFERENCES',
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.4,
                    color: Color(0xFFA0A69C)))),
        _nav(AppPage.settings),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
            child: InkWell(
                onTap: onHelp,
                borderRadius: BorderRadius.circular(7),
                child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(children: [
                      Icon(Icons.help_outline_rounded, size: 18, color: muted),
                      SizedBox(width: 12),
                      Text('Help & support',
                          style: TextStyle(fontSize: 12, color: muted))
                    ])))),
        const Spacer(),
        if (showPlan)
          Padding(
              padding: const EdgeInsets.fromLTRB(17, 20, 17, 19),
              child: Surface(
                  padding: const EdgeInsets.all(15),
                  color: const Color(0xFFFAFBF8),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.auto_awesome_outlined,
                              color: forest, size: 15),
                          SizedBox(width: 8),
                          Text('Room to grow.',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600))
                        ]),
                        const SizedBox(height: 7),
                        const Text(
                            'Thoughtful marketing starts\nwith a healthy community.',
                            style: TextStyle(
                                fontSize: 9, color: muted, height: 1.7)),
                        const SizedBox(height: 13),
                        ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                                value: ((c.dashboard['messages_sent'] ?? 0) /
                                        10000)
                                    .clamp(0.0, 1.0),
                                minHeight: 4,
                                backgroundColor: line,
                                color: const Color(0xFFBED997))),
                        const SizedBox(height: 7),
                        Text(
                            '${compactNumber(c.dashboard['messages_sent'])} messages this period',
                            style: const TextStyle(fontSize: 8, color: muted)),
                        const SizedBox(height: 13),
                        InkWell(
                            onTap: () => onNavigate(AppPage.settings),
                            child: const Row(children: [
                              Text('Manage workspace',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: forest)),
                              Spacer(),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 13, color: forest)
                            ]))
                      ]))),
        const Divider(),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
            child: Row(children: [
              InitialAvatar(c.user!['name'],
                  size: 34, color: const Color(0xFFEEDFCB)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(c.user!['name'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    const Text('Workspace admin',
                        style: TextStyle(fontSize: 9, color: muted))
                  ])),
              SizedBox(
                  width: 23,
                  height: 27,
                  child: moreMenu({
                    'Settings': Icons.settings_outlined,
                    'Sign out': Icons.logout_rounded
                  }, (s) {
                    if (s == 'Settings') {
                      onNavigate(AppPage.settings);
                    } else {
                      c.signOut();
                    }
                  }))
            ])),
      ]));
  Widget _nav(AppPage p) {
    final selected = c.page == p;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
        child: Semantics(
            button: true,
            selected: selected,
            label: pageNames[p],
            excludeSemantics: true,
            onTap: () => onNavigate(p),
            child: InkWell(
                onTap: () => onNavigate(p),
                borderRadius: BorderRadius.circular(7),
                child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                        color: selected ? paleGreen : Colors.transparent,
                        borderRadius: BorderRadius.circular(7)),
                    child: Row(children: [
                      Icon(pageIcons[p],
                          size: 18, color: selected ? forest : muted),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(pageNames[p]!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: selected ? forest : muted,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400))),
                      if (p == AppPage.contacts)
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFFF3F5F1),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(
                                compactNumber(c.dashboard['total_contacts']),
                                style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w500,
                                    color: selected
                                        ? forest
                                        : const Color(0xFF899182)))),
                      if (p == AppPage.campaigns &&
                          (c.dashboard['active_campaigns'] ?? 0) > 0)
                        Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                                color: Color(0xFFBCD991),
                                shape: BoxShape.circle))
                    ])))));
  }
}

class Header extends StatelessWidget {
  final AppController c;
  final bool desktop;
  final VoidCallback onMenu;
  const Header(this.c,
      {super.key, required this.desktop, required this.onMenu});
  @override
  Widget build(BuildContext context) {
    final d = Dialogs(context, c);
    final roomy = MediaQuery.sizeOf(context).width >= 1250;
    return Container(
        height: desktop ? 70 : 64,
        padding: EdgeInsets.symmetric(horizontal: desktop ? 30 : 12),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: line))),
        child: Row(children: [
          if (!desktop) ...[
            IconButton(
                tooltip: 'Open navigation',
                onPressed: onMenu,
                icon: const Icon(Icons.menu_rounded, size: 21, color: ink)),
            const SizedBox(width: 4),
            const Brand(compact: true)
          ] else ...[
            InkWell(
                onTap: () => c.navigate(AppPage.settings),
                child: Row(children: [
                  Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                          color: paleGreen,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.storefront_outlined,
                          size: 14, color: forest)),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(c.user!['workspace'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w500))),
                  const SizedBox(width: 6),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 13, color: muted)
                ])),
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 19),
                child: Text('/',
                    style: TextStyle(fontSize: 15, color: Color(0xFFCFD5CA)))),
            Text(pageNames[c.page]!,
                style: const TextStyle(fontSize: 11, color: muted)),
          ],
          const Spacer(),
          if (desktop && roomy)
            Semantics(
                button: true,
                label: 'Search workspace',
                excludeSemantics: true,
                onTap: d.search,
                child: InkWell(
                    onTap: d.search,
                    borderRadius: BorderRadius.circular(7),
                    child: Container(
                        width: 220,
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFAFBF9),
                            border: Border.all(color: line),
                            borderRadius: BorderRadius.circular(7)),
                        child: Row(children: [
                          const Icon(Icons.search_rounded,
                              size: 16, color: Color(0xFF9CA494)),
                          const SizedBox(width: 8),
                          const Expanded(
                              child: Text('Search anything...',
                                  style: TextStyle(
                                      fontSize: 10, color: Color(0xFFA0A69C)))),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: line),
                                  borderRadius: BorderRadius.circular(3)),
                              child: const Text('⌘ K',
                                  style: TextStyle(fontSize: 8, color: muted)))
                        ])))),
          if (desktop) const SizedBox(width: 16),
          if (desktop && c.user!['demo'] == true) ...[
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                    color: const Color(0xFFF8F5EA),
                    borderRadius: BorderRadius.circular(5)),
                child: const Row(children: [
                  Icon(Icons.circle, size: 4, color: Color(0xFFC3A85B)),
                  SizedBox(width: 5),
                  Text('Demo mode',
                      style: TextStyle(fontSize: 9, color: Color(0xFFA28E54)))
                ])),
            const SizedBox(width: 12)
          ],
          if (!desktop || !roomy)
            IconButton(
                tooltip: 'Search workspace',
                onPressed: d.search,
                icon: const Icon(Icons.search_rounded, size: 20, color: muted)),
          if (desktop)
            IconButton(
                tooltip: 'Refresh workspace',
                onPressed: c.refreshing
                    ? null
                    : () async {
                        try {
                          await c.refresh();
                          toast('Your workspace is up to date.');
                        } catch (e) {
                          toast(e.toString(), error: true);
                        }
                      },
                icon:
                    const Icon(Icons.refresh_rounded, size: 17, color: muted)),
          Stack(children: [
            IconButton(
                tooltip: 'Notifications',
                onPressed: d.notifications,
                icon: const Icon(Icons.notifications_none_rounded,
                    size: 20, color: muted)),
            if (c.visibleActivities.isNotEmpty &&
                c.user!['settings']['delivery_notifications'] != false)
              Positioned(
                  right: 12,
                  top: 10,
                  child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                          color: const Color(0xFFB6D57F),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white))))
          ]),
          const SizedBox(width: 9),
          PopupMenuButton<String>(
              tooltip: 'Your account',
              onSelected: (s) {
                if (s == 'Settings') {
                  c.navigate(AppPage.settings);
                } else {
                  c.signOut();
                }
              },
              itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'Settings',
                        child: Text('Workspace settings',
                            style: TextStyle(fontSize: 12))),
                    const PopupMenuItem(
                        value: 'Sign out',
                        child: Text('Sign out', style: TextStyle(fontSize: 12)))
                  ],
              child: InitialAvatar(c.user!['name'],
                  size: 32, color: const Color(0xFFEEDFCB))),
        ]));
  }
}
