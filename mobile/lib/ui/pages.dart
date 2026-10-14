import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/controller.dart';
import 'theme.dart';
import 'charts.dart';
import 'dialogs.dart';

class PeriodPicker extends StatelessWidget {
  final AppController c;
  const PeriodPicker(this.c, {super.key});
  @override
  Widget build(BuildContext context) => Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.calendar_today_outlined, size: 13, color: muted),
        const SizedBox(width: 8),
        DropdownButtonHideUnderline(
            child: DropdownButton<int>(
                value: c.days,
                isDense: true,
                icon: const Padding(
                    padding: EdgeInsets.only(left: 9),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: muted)),
                style: const TextStyle(
                    fontFamily: 'Inter', fontSize: 11, color: ink),
                borderRadius: BorderRadius.circular(8),
                items: const [
                  DropdownMenuItem(value: 7, child: Text('Last 7 days')),
                  DropdownMenuItem(value: 14, child: Text('Last 14 days')),
                  DropdownMenuItem(value: 30, child: Text('Last 30 days'))
                ],
                onChanged: (v) async {
                  if (v != null) {
                    try {
                      await c.setDays(v);
                    } catch (e) {
                      toast(e.toString(), error: true);
                    }
                  }
                }))
      ]));
}

class OverviewPage extends StatelessWidget {
  final AppController c;
  const OverviewPage(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    final d = Dialogs(context, c);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PageHeading('Welcome back, ${c.user!['name'].split(' ').first} 👋',
          'Let’s turn your next message into a meaningful connection.',
          actions: [
            PeriodPicker(c),
            ActionButton('New campaign',
                icon: Icons.add_rounded,
                primary: true,
                onPressed: () => d.campaignEditor())
          ]),
      const SizedBox(height: 22),
      WelcomeBanner(onCreate: () => d.campaignEditor()),
      const SizedBox(height: 20),
      MetricGrid(c.dashboard),
      const SizedBox(height: 24),
      LayoutBuilder(builder: (ctx, size) {
        final chart = PerformanceChart(c.dashboard, onExport: d.reportExport);
        final activity = ActivityCard(c, onViewAll: d.notifications);
        if (size.maxWidth < 880) {
          return Column(
              children: [chart, const SizedBox(height: 20), activity]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 7, child: chart),
          const SizedBox(width: 20),
          Expanded(flex: 3, child: activity)
        ]);
      }),
      const SizedBox(height: 24),
      Surface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 15),
            child: Row(children: [
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Recent campaigns',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.25)),
                    SizedBox(height: 4),
                    Text('Your latest conversations, at a glance.',
                        style: TextStyle(fontSize: 10, color: muted))
                  ])),
              TextButton(
                  onPressed: () => c.navigate(AppPage.campaigns),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('View all campaigns', style: TextStyle(fontSize: 10)),
                    SizedBox(width: 5),
                    Icon(Icons.arrow_forward_rounded, size: 13)
                  ]))
            ])),
        CampaignTable(c,
            (c.dashboard['recent_campaigns'] as List? ?? []).take(4).toList(),
            recent: true)
      ])),
      const SizedBox(height: 24),
      LayoutBuilder(builder: (ctx, size) {
        final invite = Surface(
            padding: const EdgeInsets.all(22),
            child: Row(children: [
              Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: paleGreen,
                      borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.person_add_alt_1_outlined,
                      size: 24, color: forest)),
              const SizedBox(width: 16),
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Your next connection starts here.',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.3)),
                    SizedBox(height: 5),
                    Text('Import your opt-in list and grow together.',
                        style: TextStyle(fontSize: 11, color: muted))
                  ])),
              const SizedBox(width: 10),
              ActionButton('Import contacts',
                  icon: Icons.file_upload_outlined,
                  small: true,
                  onPressed: () => d.importContacts())
            ]));
        if (size.maxWidth < 620) {
          return Surface(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your next connection starts here.',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    const Text('Import your opt-in list and grow together.',
                        style: TextStyle(fontSize: 11, color: muted)),
                    const SizedBox(height: 16),
                    ActionButton('Import contacts',
                        icon: Icons.file_upload_outlined,
                        onPressed: () => d.importContacts())
                  ]));
        }
        return invite;
      }),
      const SizedBox(height: 24),
      const Center(
          child: Text('Made for meaningful marketing. Built with permission.',
              style: TextStyle(fontSize: 9, color: Color(0xFFA2AAA0)))),
    ]);
  }
}

class ActivityCard extends StatelessWidget {
  final AppController c;
  final VoidCallback onViewAll;
  const ActivityCard(this.c, {super.key, required this.onViewAll});
  @override
  Widget build(BuildContext context) {
    final items = (c.dashboard['activities'] as List? ?? [])
        .where(c.activityVisible)
        .toList();
    return Surface(
        child: SizedBox(
            height: 284,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 17, 18, 13),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Expanded(
                            child: Text('Recent activity',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -.2))),
                        InkWell(
                            onTap: onViewAll,
                            child: const Icon(Icons.arrow_outward_rounded,
                                size: 15, color: muted))
                      ]),
                      const SizedBox(height: 17),
                      if (items.isEmpty)
                        const Expanded(
                            child: Center(
                                child: Text('Your workspace story starts here.',
                                    style:
                                        TextStyle(fontSize: 11, color: muted))))
                      else
                        ...items.take(4).map((a) => Expanded(
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                          color: a['kind'] == 'schedule'
                                              ? const Color(0xFFEEF1F8)
                                              : paleGreen,
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Icon(activityIcon(a['kind']),
                                          size: 14,
                                          color: a['kind'] == 'schedule'
                                              ? const Color(0xFF7B8CB2)
                                              : forest)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(a['title'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                height: 1.3)),
                                        const SizedBox(height: 4),
                                        Text(a['description'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 9,
                                                color: muted,
                                                height: 1.3)),
                                        const SizedBox(height: 4),
                                        Text(timeAgo(a['created_at']),
                                            style: const TextStyle(
                                                fontSize: 8,
                                                color: Color(0xFFA3AAA0),
                                                height: 1.2))
                                      ]))
                                ]))),
                    ]))));
  }
}

class CampaignTable extends StatelessWidget {
  final AppController c;
  final List<dynamic> items;
  final bool recent;
  const CampaignTable(this.c, this.items, {super.key, this.recent = false});
  @override
  Widget build(BuildContext context) {
    final d = Dialogs(context, c);
    if (items.isEmpty) {
      return EmptyState(
          icon: Icons.send_outlined,
          title: 'Your first campaign is waiting.',
          description:
              'Choose your audience, write something thoughtful, and start a new conversation.',
          action: ActionButton('Create a campaign',
              primary: true,
              icon: Icons.add_rounded,
              onPressed: () => d.campaignEditor()));
    }
    return LayoutBuilder(builder: (ctx, size) {
      if (size.maxWidth < 770) {
        return Column(
            children: items
                .map((r) => Column(children: [
                      const Divider(),
                      InkWell(
                          onTap: () => d.campaignDetail(r['id']),
                          child: Padding(
                              padding: const EdgeInsets.all(17),
                              child: Column(children: [
                                Row(children: [
                                  _campaignIcon(r),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(r['name'],
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text(r['audience'],
                                            style: const TextStyle(
                                                fontSize: 10, color: muted))
                                      ])),
                                  _campaignMenu(context, r)
                                ]),
                                const SizedBox(height: 14),
                                Row(children: [
                                  StatusPill(r['status']),
                                  const Spacer(),
                                  Text(
                                      r['total'] > 0
                                          ? '${number(r['delivered'])} delivered'
                                          : r['status'] == 'Scheduled'
                                              ? '${shortDate(r['scheduled_at'])} · scheduled'
                                              : '${number(r['audience_count'])} eligible',
                                      style: const TextStyle(
                                          fontSize: 10, color: muted))
                                ])
                              ])))
                    ]))
                .toList());
      }
      return Column(children: [
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
                color: Color(0xFFFAFBF9),
                border: Border(
                    top: BorderSide(color: line),
                    bottom: BorderSide(color: line))),
            child: const Row(children: [
              Expanded(flex: 4, child: Text('CAMPAIGN', style: _tableHead)),
              Expanded(flex: 3, child: Text('AUDIENCE', style: _tableHead)),
              Expanded(flex: 2, child: Text('STATUS', style: _tableHead)),
              Expanded(flex: 2, child: Text('DELIVERY', style: _tableHead)),
              Expanded(flex: 2, child: Text('CREATED', style: _tableHead)),
              SizedBox(width: 30)
            ])),
        ...items.map((r) => Column(children: [
              InkWell(
                  onTap: () => d.campaignDetail(r['id']),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      child: Row(children: [
                        Expanded(
                            flex: 4,
                            child: Row(children: [
                              _campaignIcon(r),
                              const SizedBox(width: 11),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(r['name'],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(
                                        '${r['mode'] == 'demo' ? 'Demo' : 'Live'} · ${r['template'] != null ? 'Template campaign' : 'Custom message'}',
                                        style: const TextStyle(
                                            fontSize: 9, color: muted))
                                  ]))
                            ])),
                        Expanded(
                            flex: 3,
                            child: Padding(
                                padding: const EdgeInsets.only(right: 15),
                                child: Text(r['audience'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 10, color: muted)))),
                        Expanded(
                            flex: 2,
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child: StatusPill(r['status']))),
                        Expanded(
                            flex: 2,
                            child: Padding(
                                padding: const EdgeInsets.only(right: 24),
                                child: _delivery(r))),
                        Expanded(
                            flex: 2,
                            child: Text(shortDate(r['created_at'], year: true),
                                style: const TextStyle(
                                    fontSize: 10, color: muted))),
                        SizedBox(
                            width: 30,
                            height: 27,
                            child: _campaignMenu(context, r))
                      ]))),
              if (r != items.last) const Divider()
            ]))
      ]);
    });
  }

  Widget _campaignIcon(dynamic r) => Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
          color: hexColor(r['color']), borderRadius: BorderRadius.circular(9)),
      child: Icon(
          r['status'] == 'Scheduled'
              ? Icons.schedule_rounded
              : Icons.campaign_outlined,
          size: 18,
          color: forest));
  Widget _delivery(dynamic r) => r['total'] == 0
      ? const Text('—', style: TextStyle(fontSize: 12, color: muted))
      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              '${((r['delivered'] as num) / (r['total'] as num) * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w500, color: forest)),
          const SizedBox(height: 5),
          ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                  value: r['delivered'] / r['total'],
                  minHeight: 3,
                  backgroundColor: const Color(0xFFEBF0E6),
                  color: const Color(0xFFA2C982))),
          const SizedBox(height: 4),
          Text('${number(r['delivered'])} / ${number(r['total'])}',
              style: const TextStyle(fontSize: 8, color: muted))
        ]);
  Widget _campaignMenu(BuildContext context, dynamic r) {
    final d = Dialogs(context, c);
    return moreMenu({
      'View details': Icons.visibility_outlined,
      if (['Draft', 'Scheduled', 'Failed'].contains(r['status']))
        'Edit': Icons.edit_outlined,
      'Duplicate': Icons.copy_outlined,
      if (r['status'] != 'Sending') 'Delete': Icons.delete_outline_rounded
    }, (action) async {
      if (action == 'View details') d.campaignDetail(r['id']);
      if (action == 'Edit') {
        d.campaignEditor(record: Map<String, dynamic>.from(r));
      }
      if (action == 'Duplicate') {
        try {
          await c.api.post('/campaigns/${r['id']}/duplicate');
          await c.loadCore();
          toast('Campaign duplicated as a draft.');
        } catch (e) {
          toast(e.toString(), error: true);
        }
      }
      if (action == 'Delete') d.delete('campaigns', r['id'], r['name']);
    });
  }
}

const _tableHead = TextStyle(
    fontSize: 8,
    fontWeight: FontWeight.w500,
    color: Color(0xFF899185),
    letterSpacing: .7);

class ContactsPage extends StatefulWidget {
  final AppController c;
  const ContactsPage(this.c, {super.key});
  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  late final TextEditingController query;
  AppController get c => widget.c;
  @override
  void initState() {
    super.initState();
    query = TextEditingController(text: c.contactSearch);
  }

  @override
  void didUpdateWidget(covariant ContactsPage old) {
    super.didUpdateWidget(old);
    if (query.text != c.contactSearch) query.text = c.contactSearch;
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = Dialogs(context, c), items = c.contactData['items'] as List;
    final counts = c.contactData['counts'] as Map;
    final group = c.contactGroup != null
        ? c.groups.firstWhere((g) => g['id'] == c.contactGroup,
            orElse: () => {'name': 'Contact group'})
        : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PageHeading(
          group != null ? group['name'] : 'Your contacts',
          group != null
              ? 'A community of people who want to hear from you.'
              : 'Real connections start with the right people.',
          eyebrow: group != null
              ? InkWell(
                  onTap: () => c.filterContacts(clearGroup: true),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.arrow_back_rounded, size: 12, color: muted),
                    SizedBox(width: 5),
                    Text('All contacts',
                        style: TextStyle(fontSize: 10, color: muted))
                  ]))
              : null,
          actions: [
            ActionButton('Save to phone',
                icon: Icons.contact_phone_outlined,
                onPressed: () => d.saveContacts(groupId: c.contactGroup)),
            ActionButton('Import contacts',
                icon: Icons.file_upload_outlined,
                onPressed: () => d.importContacts(groupId: c.contactGroup)),
            ActionButton('Add contact',
                icon: Icons.add_rounded,
                primary: true,
                onPressed: () => d.contactEditor())
          ]),
      const SizedBox(height: 25),
      Surface(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    TabPill('All contacts',
                        selected: c.contactStatus.isEmpty,
                        count: c.dashboard['total_contacts'],
                        onTap: () => _filter('')),
                    const SizedBox(width: 5),
                    TabPill('Opted in',
                        selected: c.contactStatus == 'opted_in',
                        count: counts['opted_in'] ?? 0,
                        onTap: () => _filter('opted_in')),
                    const SizedBox(width: 5),
                    TabPill('Pending',
                        selected: c.contactStatus == 'pending',
                        count: counts['pending'] ?? 0,
                        onTap: () => _filter('pending')),
                    const SizedBox(width: 5),
                    TabPill('Unsubscribed',
                        selected: c.contactStatus == 'unsubscribed',
                        count: counts['unsubscribed'] ?? 0,
                        onTap: () => _filter('unsubscribed'))
                  ])),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (ctx, size) {
                final search = SearchInput(
                    hint: 'Search by name, number, or email...',
                    controller: query,
                    onChanged: c.searchContacts);
                final groupPicker = DropdownButtonFormField<int>(
                    value: c.contactGroup,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 11, color: ink),
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.filter_list_rounded,
                            size: 16, color: muted),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                    items: [
                      const DropdownMenuItem<int>(
                          value: null, child: Text('All groups')),
                      ...c.groups.map((g) => DropdownMenuItem<int>(
                          value: g['id'],
                          child:
                              Text(g['name'], overflow: TextOverflow.ellipsis)))
                    ],
                    onChanged: (v) async {
                      try {
                        await c.filterContacts(
                            groupId: v, clearGroup: v == null);
                      } catch (e) {
                        toast(e.toString(), error: true);
                      }
                    });
                if (size.maxWidth < 620) {
                  return Column(children: [
                    search,
                    const SizedBox(height: 10),
                    groupPicker
                  ]);
                }
                return Row(children: [
                  Expanded(child: search),
                  const SizedBox(width: 12),
                  SizedBox(width: 210, child: groupPicker),
                  const SizedBox(width: 12),
                  Tooltip(
                      message: 'Export contacts as CSV',
                      child: ActionButton('Export',
                          icon: Icons.file_download_outlined,
                          onPressed: () => d.exportContacts(format: 'csv')))
                ]);
              }),
            ])),
        if (c.selectedContacts.isNotEmpty)
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: paleGreen,
              child: Wrap(
                  spacing: 15,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${c.selectedContacts.length} contacts selected',
                        style: const TextStyle(
                            fontSize: 11,
                            color: forest,
                            fontWeight: FontWeight.w600)),
                    TextButton.icon(
                        onPressed: () => d.saveContacts(),
                        icon:
                            const Icon(Icons.contact_phone_outlined, size: 14),
                        label: const Text('Save selected',
                            style: TextStyle(fontSize: 10))),
                    TextButton.icon(
                        onPressed: () => _bulkDelete(d),
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 14, color: Color(0xFFB16B67)),
                        label: const Text('Delete selected',
                            style: TextStyle(
                                fontSize: 10, color: Color(0xFFB16B67)))),
                    TextButton(
                        onPressed: () {
                          c.selectedContacts.clear();
                          c.changed();
                        },
                        child: const Text('Clear selection',
                            style: TextStyle(fontSize: 10)))
                  ])),
        if (c.contactsLoading) const LinearProgressIndicator(minHeight: 2),
        if (c.contactsError != null)
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: errorBox(c.contactsError)),
        if (items.isEmpty)
          EmptyState(
              icon: c.contactSearch.isEmpty
                  ? Icons.people_outline_rounded
                  : Icons.search_off_rounded,
              title: c.contactSearch.isEmpty
                  ? 'Your community starts here.'
                  : 'No matching contacts.',
              description: c.contactSearch.isEmpty
                  ? 'Add a contact or import a consented CSV list. Your contacts will be saved securely in this workspace.'
                  : 'Try a different search, status, or group filter.',
              action: c.contactSearch.isEmpty
                  ? ActionButton('Import contacts',
                      primary: true,
                      onPressed: () =>
                          d.importContacts(groupId: c.contactGroup))
                  : ActionButton('Clear filters', onPressed: () async {
                      query.clear();
                      c.contactSearch = '';
                      await c.filterContacts(status: '', clearGroup: true);
                    })),
        if (items.isNotEmpty)
          LayoutBuilder(builder: (ctx, size) {
            if (size.maxWidth < 860) {
              return Column(
                  children: items
                      .map((r) => Column(children: [
                            const Divider(),
                            Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                child: Row(children: [
                                  Checkbox(
                                      value:
                                          c.selectedContacts.contains(r['id']),
                                      onChanged: (_) =>
                                          c.toggleContact(r['id'])),
                                  InitialAvatar(
                                      '${r['first_name']} ${r['last_name']}',
                                      size: 34),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: InkWell(
                                          onTap: () => d.contactEditor(
                                              Map<String, dynamic>.from(r)),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    '${r['first_name']} ${r['last_name']}',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500)),
                                                const SizedBox(height: 4),
                                                Text(r['phone'],
                                                    style: const TextStyle(
                                                        fontSize: 10,
                                                        color: muted)),
                                                const SizedBox(height: 7),
                                                StatusPill(r['consent_status'])
                                              ]))),
                                  _contactMenu(d, r)
                                ]))
                          ]))
                      .toList());
            }
            return Column(children: [
              Container(
                  padding: const EdgeInsets.fromLTRB(8, 6, 20, 6),
                  decoration: const BoxDecoration(
                      color: Color(0xFFFAFBF9),
                      border: Border(
                          top: BorderSide(color: line),
                          bottom: BorderSide(color: line))),
                  child: Row(children: [
                    SizedBox(
                        width: 40,
                        child: Checkbox(
                            value: items.every(
                                (r) => c.selectedContacts.contains(r['id'])),
                            onChanged: (_) => c.toggleAllContacts())),
                    const Expanded(
                        flex: 4, child: Text('CONTACT', style: _tableHead)),
                    const Expanded(
                        flex: 3,
                        child: Text('PHONE NUMBER', style: _tableHead)),
                    const Expanded(
                        flex: 3, child: Text('GROUP', style: _tableHead)),
                    const Expanded(
                        flex: 3, child: Text('PERMISSION', style: _tableHead)),
                    const Expanded(
                        flex: 2, child: Text('SOURCE', style: _tableHead)),
                    const SizedBox(width: 30)
                  ])),
              ...items.map((r) => Column(children: [
                    Padding(
                        padding: const EdgeInsets.fromLTRB(8, 13, 20, 13),
                        child: Row(children: [
                          SizedBox(
                              width: 40,
                              child: Checkbox(
                                  value: c.selectedContacts.contains(r['id']),
                                  onChanged: (_) => c.toggleContact(r['id']))),
                          Expanded(
                              flex: 4,
                              child: InkWell(
                                  onTap: () => d.contactEditor(
                                      Map<String, dynamic>.from(r)),
                                  child: Row(children: [
                                    InitialAvatar(
                                        '${r['first_name']} ${r['last_name']}',
                                        size: 32),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(
                                              '${r['first_name']} ${r['last_name']}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500)),
                                          const SizedBox(height: 4),
                                          Text(
                                              r['email'].isEmpty
                                                  ? 'No email address'
                                                  : r['email'],
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 8, color: muted))
                                        ]))
                                  ]))),
                          Expanded(
                              flex: 3,
                              child: Text(r['phone'],
                                  style: const TextStyle(
                                      fontSize: 10, color: muted))),
                          Expanded(flex: 3, child: _groupTag(r)),
                          Expanded(
                              flex: 3,
                              child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: StatusPill(r['consent_status']))),
                          Expanded(
                              flex: 2,
                              child: Text(r['source'],
                                  style: const TextStyle(
                                      fontSize: 9, color: muted))),
                          SizedBox(
                              width: 30, height: 28, child: _contactMenu(d, r))
                        ])),
                    if (r != items.last) const Divider()
                  ]))
            ]);
          }),
        const Divider(),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              Expanded(
                  child: Text(
                      'Showing ${items.isEmpty ? 0 : (c.contactPage - 1) * 12 + 1}–${math.min(c.contactPage * 12, c.contactData['total'] as int)} of ${number(c.contactData['total'])} contacts',
                      style: const TextStyle(fontSize: 10, color: muted))),
              IconButton(
                  tooltip: 'Previous page',
                  onPressed: c.contactPage > 1 && !c.contactsLoading
                      ? () async {
                          c.contactPage--;
                          try {
                            await c.loadContacts();
                          } catch (e) {
                            toast(e.toString(), error: true);
                          }
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded, size: 18)),
              Text('${c.contactPage}',
                  style: const TextStyle(fontSize: 10, color: muted)),
              IconButton(
                  tooltip: 'Next page',
                  onPressed:
                      c.contactPage * 12 < (c.contactData['total'] as int) &&
                              !c.contactsLoading
                          ? () async {
                              c.contactPage++;
                              try {
                                await c.loadContacts();
                              } catch (e) {
                                toast(e.toString(), error: true);
                              }
                            }
                          : null,
                  icon: const Icon(Icons.chevron_right_rounded, size: 18))
            ])),
      ])),
      const SizedBox(height: 16),
      const Row(children: [
        Icon(Icons.verified_user_outlined, size: 12, color: muted),
        SizedBox(width: 7),
        Expanded(
            child: Text(
                'Only contacts with recorded opt-in can receive campaigns. Your people. Their permission.',
                style: TextStyle(fontSize: 10, color: muted)))
      ]),
    ]);
  }

  Future<void> _filter(String status) async {
    try {
      await c.filterContacts(status: status);
    } catch (e) {
      toast(e.toString(), error: true);
    }
  }

  Widget _groupTag(dynamic r) {
    final gs = r['groups'] as List;
    if (gs.isEmpty) {
      return const Text('—', style: TextStyle(color: muted, fontSize: 11));
    }
    return Align(
        alignment: Alignment.centerLeft,
        child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
                color: hexColor(gs.first['color']).withOpacity(.3),
                borderRadius: BorderRadius.circular(5)),
            child: Text(gs.first['name'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 9, color: Color(0xFF647059)))));
  }

  Widget _contactMenu(Dialogs d, dynamic r) => moreMenu({
        'Edit': Icons.edit_outlined,
        'Export vCard': Icons.contact_phone_outlined,
        'Delete': Icons.delete_outline_rounded
      }, (v) {
        if (v == 'Edit') d.contactEditor(Map<String, dynamic>.from(r));
        if (v == 'Export vCard') d.exportContacts(ids: [r['id']]);
        if (v == 'Delete') {
          d.delete('contacts', r['id'], '${r['first_name']} ${r['last_name']}');
        }
      });
  Future<void> _bulkDelete(Dialogs d) async {
    if (!await d.confirm('Remove selected contacts?',
        '${c.selectedContacts.length} contacts will be permanently removed from your workspace.')) {
      return;
    }
    try {
      final ids = c.selectedContacts.toList();
      final old = Map<String, dynamic>.from(c.contactData);
      c.contactData = {
        ...old,
        'items':
            (old['items'] as List).where((r) => !ids.contains(r['id'])).toList()
      };
      c.selectedContacts.clear();
      c.changed();
      await c.api.post('/contacts/bulk-delete', {'ids': ids});
      await c.refresh();
      toast('${ids.length} contacts removed.');
    } catch (e) {
      await c.refresh();
      toast(e.toString(), error: true);
    }
  }
}

class GroupsPage extends StatefulWidget {
  final AppController c;
  const GroupsPage(this.c, {super.key});
  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final c = widget.c, d = Dialogs(context, widget.c);
    final items = c.groups
        .where((g) =>
            (g['name'] as String).toLowerCase().contains(query.toLowerCase()))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PageHeading('Contact groups', 'A place for every part of your community.',
          actions: [
            ActionButton('Import members',
                icon: Icons.file_upload_outlined,
                onPressed: () => d.importContacts()),
            ActionButton('New group',
                primary: true,
                icon: Icons.add_rounded,
                onPressed: () => d.groupEditor())
          ]),
      const SizedBox(height: 25),
      const InfoBanner('Your groups. Your permission. Your people.',
          'Choose a group to view its contacts, import a consented member list, or save everyone to your phone at once. Existing WhatsApp group member lists are not accessible through the official API.',
          icon: Icons.workspaces_outline),
      const SizedBox(height: 22),
      Row(children: [
        Text('${c.groups.length} contact groups',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const Spacer(),
        SizedBox(
            width: MediaQuery.sizeOf(context).width < 550 ? 180 : 270,
            child: SearchInput(
                hint: 'Find a group...',
                onChanged: (s) => setState(() => query = s)))
      ]),
      const SizedBox(height: 20),
      if (items.isEmpty)
        Surface(
            child: EmptyState(
                icon: Icons.workspaces_outline,
                title: query.isEmpty
                    ? 'Bring your community together.'
                    : 'No matching groups.',
                description: query.isEmpty
                    ? 'Create a group for your customers, events, or your next big idea. Then add a consented contact list.'
                    : 'Try a different group name.',
                action: query.isEmpty
                    ? ActionButton('Create a group',
                        primary: true, onPressed: () => d.groupEditor())
                    : null)),
      LayoutBuilder(builder: (ctx, size) {
        final cols = size.maxWidth < 630
            ? 1
            : size.maxWidth < 1020
                ? 2
                : 3;
        final width = (size.maxWidth - (cols - 1) * 18) / cols;
        return Wrap(
            spacing: 18,
            runSpacing: 18,
            children: items
                .map((g) =>
                    SizedBox(width: width, child: _groupCard(context, c, d, g)))
                .toList());
      }),
    ]);
  }

  Widget _groupCard(
          BuildContext context, AppController c, Dialogs d, dynamic g) =>
      Surface(
          child: InkWell(
              onTap: () => c.openGroup(g['id']),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                  color: hexColor(g['color']).withOpacity(.5),
                                  borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.workspaces_outline,
                                  color: forest, size: 22)),
                          const Spacer(),
                          SizedBox(
                              width: 27,
                              height: 30,
                              child: moreMenu({
                                'View contacts': Icons.people_outline_rounded,
                                'Import members': Icons.file_upload_outlined,
                                'Save to phone': Icons.contact_phone_outlined,
                                'Edit': Icons.edit_outlined,
                                'Delete': Icons.delete_outline_rounded
                              }, (v) {
                                if (v == 'View contacts') c.openGroup(g['id']);
                                if (v == 'Import members') {
                                  d.importContacts(groupId: g['id']);
                                }
                                if (v == 'Save to phone') {
                                  d.saveContacts(groupId: g['id']);
                                }
                                if (v == 'Edit') {
                                  d.groupEditor(Map<String, dynamic>.from(g));
                                }
                                if (v == 'Delete') {
                                  d.delete('groups', g['id'], g['name']);
                                }
                              }))
                        ]),
                        const SizedBox(height: 17),
                        Text(g['name'],
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -.4)),
                        const SizedBox(height: 8),
                        SizedBox(
                            height: 36,
                            child: Text(
                                g['description'].isEmpty
                                    ? 'A new community, ready for your contacts.'
                                    : g['description'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 10, color: muted, height: 1.7))),
                        const SizedBox(height: 19),
                        Row(children: [
                          SizedBox(
                              width: 78,
                              height: 25,
                              child: Stack(
                                  children: (g['preview'] as List)
                                      .asMap()
                                      .entries
                                      .map((e) => Positioned(
                                          left: e.key * 17.0,
                                          child: InitialAvatar(
                                              '${e.value['first_name']} ${e.value['last_name']}',
                                              size: 25)))
                                      .toList())),
                          Text('${number(g['total'])} members',
                              style:
                                  const TextStyle(fontSize: 10, color: muted)),
                          const Spacer(),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 4),
                              decoration: BoxDecoration(
                                  color: background,
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text(g['source'],
                                  style: const TextStyle(
                                      fontSize: 8, color: muted)))
                        ]),
                        const SizedBox(height: 17),
                        const Divider(),
                        const SizedBox(height: 11),
                        Row(children: [
                          const Icon(Icons.verified_user_outlined,
                              size: 12, color: forest),
                          const SizedBox(width: 5),
                          Text('${number(g['opted_in'])} opted in',
                              style:
                                  const TextStyle(fontSize: 9, color: forest)),
                          const Spacer(),
                          const Text('View group',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: forest)),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 13, color: forest)
                        ]),
                      ]))));
}

class CampaignsPage extends StatefulWidget {
  final AppController c;
  const CampaignsPage(this.c, {super.key});
  @override
  State<CampaignsPage> createState() => _CampaignsPageState();
}

class _CampaignsPageState extends State<CampaignsPage> {
  String query = '', status = '';
  @override
  Widget build(BuildContext context) {
    final c = widget.c, d = Dialogs(context, widget.c);
    final items = c.campaigns
        .where((r) =>
            (r['name'] as String).toLowerCase().contains(query.toLowerCase()) &&
            (status.isEmpty || r['status'] == status))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PageHeading(
          'Your campaigns', 'Less noise. More conversations that matter.',
          actions: [
            ActionButton('Export report',
                icon: Icons.file_download_outlined, onPressed: d.reportExport),
            ActionButton('New campaign',
                primary: true,
                icon: Icons.add_rounded,
                onPressed: () => d.campaignEditor())
          ]),
      const SizedBox(height: 25),
      if (c.campaigns.any((r) => r['status'] == 'Sending')) ...[
        InfoBanner(
            'A campaign is on its way.',
            c.campaigns
                    .any((r) => r['status'] == 'Sending' && r['mode'] == 'live')
                ? 'We’re submitting approved messages to WhatsApp. Delivery receipts update automatically.'
                : 'Demo delivery is running. No real messages leave this workspace.',
            icon: Icons.send_outlined,
            color: const Color(0xFFF8F4E7)),
        const SizedBox(height: 20)
      ],
      Surface(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(builder: (ctx, size) {
              final tabs = SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    TabPill('All campaigns',
                        selected: status.isEmpty,
                        count: c.campaigns.length,
                        onTap: () => setState(() => status = '')),
                    ...['Draft', 'Scheduled', 'Completed'].map((s) => Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: TabPill(s == 'Draft' ? 'Drafts' : s,
                            selected: status == s,
                            count: c.campaigns
                                .where((r) => r['status'] == s)
                                .length,
                            onTap: () => setState(() => status = s))))
                  ]));
              final search = SearchInput(
                  hint: 'Search campaigns...',
                  onChanged: (v) => setState(() => query = v));
              if (size.maxWidth < 950) {
                return Column(
                    children: [tabs, const SizedBox(height: 14), search]);
              }
              return Row(children: [
                Expanded(child: tabs),
                const SizedBox(width: 20),
                SizedBox(width: 220, child: search)
              ]);
            })),
        CampaignTable(c, items),
        const Divider(),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              Text('${items.length} campaigns',
                  style: const TextStyle(fontSize: 10, color: muted)),
              const Spacer(),
              const Icon(Icons.verified_user_outlined, size: 12, color: muted),
              const SizedBox(width: 5),
              const Text('Permission-first marketing',
                  style: TextStyle(fontSize: 9, color: muted))
            ]))
      ])),
    ]);
  }
}

class TemplatesPage extends StatefulWidget {
  final AppController c;
  const TemplatesPage(this.c, {super.key});
  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  String query = '', category = '';
  bool syncing = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.c, d = Dialogs(context, widget.c);
    final items = c.templates
        .where((t) =>
            (t['title'] as String)
                .toLowerCase()
                .contains(query.toLowerCase()) &&
            (category.isEmpty || t['category'] == category))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PageHeading(
          'Message templates', 'The words that make your community feel seen.',
          actions: [
            ActionButton('Sync from WhatsApp',
                icon: Icons.sync_rounded, busy: syncing, onPressed: () async {
              if (c.integration['connected'] != true) {
                d.connectWhatsApp();
                return;
              }
              setState(() => syncing = true);
              try {
                final r = await c.api.post('/templates/sync');
                await c.loadCore();
                toast('${r['synced']} text templates synced.');
              } catch (e) {
                toast(e.toString(), error: true);
              }
              if (mounted) setState(() => syncing = false);
            }),
            ActionButton('New template',
                icon: Icons.add_rounded,
                primary: true,
                onPressed: () => d.templateEditor())
          ]),
      const SizedBox(height: 25),
      LayoutBuilder(builder: (ctx, size) {
        final tabs = Row(mainAxisSize: MainAxisSize.min, children: [
          TabPill('All templates',
              selected: category.isEmpty,
              onTap: () => setState(() => category = '')),
          const SizedBox(width: 5),
          TabPill('Marketing',
              selected: category == 'MARKETING',
              onTap: () => setState(() => category = 'MARKETING')),
          const SizedBox(width: 5),
          TabPill('Utility',
              selected: category == 'UTILITY',
              onTap: () => setState(() => category = 'UTILITY'))
        ]);
        final search = SearchInput(
            hint: 'Find the right words...',
            onChanged: (s) => setState(() => query = s));
        if (size.maxWidth < 700) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal, child: tabs),
                const SizedBox(height: 13),
                search
              ]);
        }
        return Row(children: [
          tabs,
          const Spacer(),
          SizedBox(width: 250, child: search)
        ]);
      }),
      const SizedBox(height: 21),
      if (items.isEmpty)
        Surface(
            child: EmptyState(
                icon: Icons.description_outlined,
                title: query.isEmpty
                    ? 'Good words start here.'
                    : 'No matching templates.',
                description: query.isEmpty
                    ? 'Create your first template and make your next campaign feel personal.'
                    : 'Try a different title or category.',
                action: query.isEmpty
                    ? ActionButton('Create a template',
                        primary: true, onPressed: () => d.templateEditor())
                    : null)),
      LayoutBuilder(builder: (ctx, size) {
        final cols = size.maxWidth < 640
            ? 1
            : size.maxWidth < 1030
                ? 2
                : 3;
        final width = (size.maxWidth - (cols - 1) * 18) / cols;
        return Wrap(
            spacing: 18,
            runSpacing: 18,
            children: items
                .map((t) => SizedBox(
                    width: width,
                    child: Surface(
                        child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                        width: 31,
                                        height: 31,
                                        decoration: BoxDecoration(
                                            color: hexColor(t['color']),
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Icon(
                                            t['category'] == 'UTILITY'
                                                ? Icons.inventory_2_outlined
                                                : Icons.auto_awesome_outlined,
                                            size: 16,
                                            color: forest)),
                                    const SizedBox(width: 9),
                                    Text(
                                        t['category'] == 'UTILITY'
                                            ? 'UTILITY'
                                            : 'MARKETING',
                                        style: const TextStyle(
                                            fontSize: 8,
                                            color: muted,
                                            letterSpacing: .7)),
                                    const Spacer(),
                                    SizedBox(
                                        width: 27,
                                        height: 25,
                                        child: moreMenu({
                                          'Edit': Icons.edit_outlined,
                                          'Duplicate': Icons.copy_outlined,
                                          'Delete': Icons.delete_outline_rounded
                                        }, (v) async {
                                          if (v == 'Edit') {
                                            d.templateEditor(
                                                Map<String, dynamic>.from(t));
                                          }
                                          if (v == 'Delete') {
                                            d.delete('templates', t['id'],
                                                t['title']);
                                          }
                                          if (v == 'Duplicate') {
                                            try {
                                              await c.api.post('/templates', {
                                                'title': '${t['title']} (copy)',
                                                'name':
                                                    '${t['name']}_copy_${DateTime.now().millisecondsSinceEpoch}',
                                                'body': t['body'],
                                                'category': t['category'],
                                                'language': t['language'],
                                                'color': t['color']
                                              });
                                              await c.loadCore();
                                              toast(
                                                  'Template duplicated as a draft.');
                                            } catch (e) {
                                              toast(e.toString(), error: true);
                                            }
                                          }
                                        }))
                                  ]),
                                  const SizedBox(height: 16),
                                  Text(t['title'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -.35)),
                                  const SizedBox(height: 13),
                                  Container(
                                      height: 160,
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                          color: background,
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                                child: Text(
                                                    (t['body'] as String)
                                                        .replaceAll(
                                                            '{{1}}', 'Amara'),
                                                    maxLines: 7,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 10,
                                                        color:
                                                            Color(0xFF747D6F),
                                                        height: 1.8))),
                                            const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  Text('10:42',
                                                      style: TextStyle(
                                                          fontSize: 7,
                                                          color: muted)),
                                                  SizedBox(width: 4),
                                                  Icon(Icons.done_all_rounded,
                                                      size: 11,
                                                      color: Color(0xFF91B79C))
                                                ])
                                          ])),
                                  const SizedBox(height: 16),
                                  Row(children: [
                                    StatusPill(t['status']),
                                    const Spacer(),
                                    Text(
                                        '${t['variable_count']} ${(t['variable_count'] as int) == 1 ? 'variable' : 'variables'}',
                                        style: const TextStyle(
                                            fontSize: 8, color: muted))
                                  ]),
                                  const SizedBox(height: 15),
                                  const Divider(),
                                  const SizedBox(height: 10),
                                  InkWell(
                                      onTap: () =>
                                          d.campaignEditor(templateId: t['id']),
                                      child: const Padding(
                                          padding:
                                              EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.send_outlined,
                                                    size: 13, color: forest),
                                                SizedBox(width: 7),
                                                Text('Use this template',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: forest))
                                              ])))
                                ])))))
                .toList());
      }),
      const SizedBox(height: 22),
      const InfoBanner('A draft today. A stronger connection tomorrow.',
          'Draft and demo-approved templates are for simulated campaigns. Only templates approved by Meta and synced from your connected account can be sent live.',
          icon: Icons.lightbulb_outline_rounded),
    ]);
  }
}

class AnalyticsPage extends StatelessWidget {
  final AppController c;
  const AnalyticsPage(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    final d = Dialogs(context, c);
    final best = List<dynamic>.from(c.campaigns.where((r) => r['total'] > 0))
      ..sort(
          (a, b) => (b['delivered'] as int).compareTo(a['delivered'] as int));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PageHeading('A little insight goes a long way.',
          'See what’s working. Make your next conversation even better.',
          actions: [
            PeriodPicker(c),
            ActionButton('Export report',
                icon: Icons.file_download_outlined,
                primary: true,
                onPressed: d.reportExport)
          ]),
      const SizedBox(height: 25),
      MetricGrid(c.dashboard),
      const SizedBox(height: 24),
      PerformanceChart(c.dashboard, height: 345, onExport: d.reportExport),
      const SizedBox(height: 24),
      LayoutBuilder(builder: (ctx, size) {
        final audience = AudienceChart(c.dashboard);
        final performance = Surface(
            padding: const EdgeInsets.all(23),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Campaigns your people loved',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.3)),
              const SizedBox(height: 5),
              const Text('Ranked by successful deliveries · all-time',
                  style: TextStyle(fontSize: 10, color: muted)),
              const SizedBox(height: 24),
              if (best.isEmpty)
                const EmptyState(
                    icon: Icons.insights_outlined,
                    title: 'Your story is just beginning.',
                    description:
                        'Complete your first campaign to see it here.'),
              ...best.take(5).map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 23),
                  child: InkWell(
                      onTap: () => d.campaignDetail(r['id']),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text(r['name'],
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500))),
                              Text('${number(r['delivered'])} delivered',
                                  style: const TextStyle(
                                      fontSize: 10, color: muted))
                            ]),
                            const SizedBox(height: 9),
                            ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                    value: (r['delivered'] as int) /
                                        math.max(
                                            1, best.first['delivered'] as int),
                                    minHeight: 5,
                                    color: hexColor(r['color']) == paleGreen
                                        ? forest
                                        : const Color(0xFFB4CE92),
                                    backgroundColor: background)),
                            const SizedBox(height: 5),
                            Text(
                                '${r['total'] == 0 ? 0 : ((r['read'] as int) / (r['total'] as int) * 100).toStringAsFixed(1)}% read · ${shortDate(r['sent_at'])}',
                                style:
                                    const TextStyle(fontSize: 8, color: muted))
                          ]))))
            ]));
        if (size.maxWidth < 780) {
          return Column(
              children: [audience, const SizedBox(height: 20), performance]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 4, child: audience),
          const SizedBox(width: 20),
          Expanded(flex: 6, child: performance)
        ]);
      }),
      const SizedBox(height: 22),
      InfoBanner(
          'Metrics that tell the whole story',
          c.user!['demo'] == true
              ? 'You’re exploring synthetic demo data. Live accounts receive delivery and read receipts through verified WhatsApp webhooks. All-time reports can be downloaded as CSV.'
              : 'Live analytics update from signed Meta delivery webhooks. Read receipts depend on the recipient’s privacy settings. Reports can be downloaded as CSV.',
          icon: Icons.insights_outlined),
    ]);
  }
}

class SettingsPage extends StatefulWidget {
  final AppController c;
  const SettingsPage(this.c, {super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController name, workspace;
  late bool contactsAlerts, deliveryAlerts;
  late String timezone;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.c.user!['name']);
    workspace = TextEditingController(text: widget.c.user!['workspace']);
    final s = widget.c.user!['settings'] as Map;
    contactsAlerts = s['email_notifications'] ?? true;
    deliveryAlerts = s['delivery_notifications'] ?? true;
    timezone = s['timezone'] ?? 'Africa/Lagos';
  }

  @override
  void dispose() {
    name.dispose();
    workspace.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c,
        d = Dialogs(context, widget.c),
        connected = c.integration['connected'] == true;
    final profile = Surface(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Your workspace',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.3)),
          const SizedBox(height: 6),
          const Text('Make yourself at home.',
              style: TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 23),
          Row(children: [
            InitialAvatar(c.user!['name'],
                size: 48, color: const Color(0xFFEEDFCB)),
            const SizedBox(width: 13),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(c.user!['name'],
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(c.user!['email'],
                      style: const TextStyle(fontSize: 10, color: muted))
                ])),
            if (c.user!['demo'] == true) const StatusPill('Demo')
          ]),
          const SizedBox(height: 24),
          FieldLabel('Your name', child: input(name)),
          gap(),
          FieldLabel('Workspace name', child: input(workspace)),
          gap(),
          FieldLabel('Workspace timezone',
              child: DropdownButtonFormField<String>(
                  value: timezone,
                  style: const TextStyle(fontSize: 12, color: ink),
                  items: [
                    'Africa/Lagos',
                    'UTC',
                    'Europe/London',
                    'America/New_York'
                  ]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => timezone = v!))),
          gap(20),
          const Divider(),
          gap(20),
          const Text('Activity preferences',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          gap(9),
          SwitchListTile.adaptive(
              value: deliveryAlerts,
              onChanged: (v) => setState(() => deliveryAlerts = v),
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: forest,
              title: const Text('Delivery notifications',
                  style: TextStyle(fontSize: 11)),
              subtitle: const Text(
                  'Show campaign updates in your activity feed.',
                  style: TextStyle(fontSize: 9, color: muted))),
          SwitchListTile.adaptive(
              value: contactsAlerts,
              onChanged: (v) => setState(() => contactsAlerts = v),
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: forest,
              title: const Text('Contact activity',
                  style: TextStyle(fontSize: 11)),
              subtitle: const Text('Keep up with new imports and connections.',
                  style: TextStyle(fontSize: 9, color: muted))),
          gap(17),
          Align(
              alignment: Alignment.centerRight,
              child: ActionButton('Save changes', primary: true, busy: saving,
                  onPressed: () async {
                setState(() => saving = true);
                try {
                  final result = await c.api.put('/settings', {
                    'name': name.text,
                    'workspace': workspace.text,
                    'email_notifications': contactsAlerts,
                    'delivery_notifications': deliveryAlerts,
                    'timezone': timezone
                  });
                  c.user = Map<String, dynamic>.from(result);
                  c.changed();
                  toast('Workspace settings saved.');
                } catch (e) {
                  toast(e.toString(), error: true);
                }
                if (mounted) setState(() => saving = false);
              }))
        ]));
    final integrations = Column(children: [
      Surface(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: paleGreen,
                      borderRadius: BorderRadius.circular(11)),
                  child: const Icon(Icons.chat_bubble_outline_rounded,
                      size: 22, color: forest)),
              const SizedBox(width: 13),
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('WhatsApp Business',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text('Official Cloud API connection',
                        style: TextStyle(fontSize: 10, color: muted))
                  ])),
              StatusPill(connected ? 'Approved' : 'Demo mode')
            ]),
            gap(22),
            Text(
                connected
                    ? 'Your business account is connected. Sync your approved templates to start sending thoughtful campaigns.'
                    : 'Explore everything in demo mode, then connect your own business number when you’re ready for real conversations.',
                style:
                    const TextStyle(fontSize: 11, color: muted, height: 1.8)),
            gap(18),
            if (connected) ...[
              Text('Phone number ID: ${c.integration['phone_number_id']}',
                  style: const TextStyle(fontSize: 10, color: muted)),
              gap(8)
            ],
            Wrap(spacing: 9, runSpacing: 9, children: [
              ActionButton(connected ? 'Manage connection' : 'Connect WhatsApp',
                  icon: Icons.link_rounded,
                  primary: true,
                  onPressed: d.connectWhatsApp),
              if (connected)
                ActionButton('Disconnect', onPressed: () async {
                  if (!await d.confirm('Disconnect WhatsApp?',
                      'Live messaging will be disabled. Your contacts, templates, and campaign history will remain.',
                      button: 'Disconnect')) return;
                  try {
                    await c.api.delete('/integrations/whatsapp');
                    await c.loadCore();
                    toast('WhatsApp disconnected.');
                  } catch (e) {
                    toast(e.toString(), error: true);
                  }
                })
            ]),
            gap(22),
            const Divider(),
            gap(18),
            const Text('Delivery webhook',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
            gap(8),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: background, borderRadius: BorderRadius.circular(7)),
                child: Row(children: [
                  Expanded(
                      child: Text('${c.api.base}/api/webhooks/whatsapp',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9, color: muted))),
                  IconButton(
                      tooltip: 'Copy webhook URL',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                            text: '${c.api.base}/api/webhooks/whatsapp'));
                        toast('Webhook URL copied.');
                      },
                      icon: const Icon(Icons.copy_outlined,
                          size: 14, color: muted))
                ])),
            gap(8),
            const Text(
                'Set WHATSAPP_VERIFY_TOKEN and WHATSAPP_APP_SECRET on your server. Webhooks are signature-verified before processing.',
                style: TextStyle(fontSize: 9, color: muted, height: 1.7))
          ])),
      const SizedBox(height: 20),
      Surface(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Your data, always yours.',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.3)),
            gap(6),
            const Text('Take your contacts and campaign insights with you.',
                style: TextStyle(fontSize: 11, color: muted)),
            gap(18),
            Wrap(spacing: 9, runSpacing: 9, children: [
              ActionButton('Export contacts',
                  small: true,
                  icon: Icons.file_download_outlined,
                  onPressed: () => d.exportContacts(format: 'csv', all: true)),
              ActionButton('Campaign report',
                  small: true,
                  icon: Icons.insights_outlined,
                  onPressed: d.reportExport)
            ]),
            gap(21),
            const Divider(),
            gap(14),
            Row(children: [
              const Expanded(
                  child: Text('Need a break? Your workspace will be here.',
                      style: TextStyle(fontSize: 10, color: muted))),
              TextButton.icon(
                  onPressed: c.signOut,
                  icon: const Icon(Icons.logout_rounded, size: 13),
                  label: const Text('Sign out', style: TextStyle(fontSize: 10)))
            ])
          ]))
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const PageHeading(
          'Workspace settings', 'The details that make this space your own.'),
      const SizedBox(height: 25),
      LayoutBuilder(builder: (ctx, size) {
        if (size.maxWidth < 800) {
          return Column(
              children: [profile, const SizedBox(height: 20), integrations]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 5, child: profile),
          const SizedBox(width: 22),
          Expanded(flex: 5, child: integrations)
        ]);
      }),
      const SizedBox(height: 24),
      const InfoBanner('Built for permission. Designed for connection.',
          'No unofficial WhatsApp clients. No private group scraping. No messages to people who opted out. Keep consent records and respect applicable privacy and marketing rules.',
          icon: Icons.verified_user_outlined)
    ]);
  }
}
