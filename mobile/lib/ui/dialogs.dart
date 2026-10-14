import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/controller.dart';
import '../core/contact_saver.dart';
import '../core/download.dart';
import 'theme.dart';

final messengerKey = GlobalKey<ScaffoldMessengerState>();
void toast(String text, {bool error = false}) {
  messengerKey.currentState?.hideCurrentSnackBar();
  messengerKey.currentState?.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFF834E4B) : ink,
      width: math.min(
          420, MediaQuery.sizeOf(messengerKey.currentContext!).width - 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      content: Row(children: [
        Icon(
            error
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: error ? Colors.white : lime,
            size: 17),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontFamily: 'Inter', fontSize: 12, color: Colors.white)))
      ])));
}

class DialogFrame extends StatelessWidget {
  final String title, subtitle;
  final Widget child;
  final List<Widget> actions;
  final double width;
  final bool busy;
  const DialogFrame(
      {super.key,
      required this.title,
      this.subtitle = '',
      required this.child,
      this.actions = const [],
      this.width = 560,
      this.busy = false});
  @override
  Widget build(BuildContext context) => Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: SizedBox(
          width: math.min(width, MediaQuery.sizeOf(context).width - 36),
          child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .9),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                        padding: const EdgeInsets.fromLTRB(24, 22, 16, 18),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(title,
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -.6)),
                                    if (subtitle.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(subtitle,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: muted,
                                              height: 1.5))
                                    ]
                                  ])),
                              IconButton(
                                  tooltip: 'Close dialog',
                                  onPressed: busy
                                      ? null
                                      : () => Navigator.pop(context),
                                  icon: const Icon(Icons.close_rounded,
                                      size: 18, color: muted))
                            ])),
                    const Divider(),
                    Flexible(
                        child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24), child: child)),
                    if (actions.isNotEmpty) ...[
                      const Divider(),
                      Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 17),
                          child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 9,
                              runSpacing: 9,
                              children: actions))
                    ],
                  ]))));
}

Widget errorBox(String? error) => error == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFFAEEEE),
                borderRadius: BorderRadius.circular(7)),
            child: Text(error,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF9F5E5A), height: 1.5))));
Widget input(TextEditingController c,
        {String? hint,
        int lines = 1,
        bool obscure = false,
        ValueChanged<String>? onChanged,
        bool readOnly = false,
        TextInputType? keyboard}) =>
    TextField(
        controller: c,
        maxLines: lines,
        obscureText: obscure,
        onChanged: onChanged,
        readOnly: readOnly,
        keyboardType: keyboard,
        style: const TextStyle(fontSize: 12, height: 1.5),
        decoration: InputDecoration(hintText: hint));
Widget gap([double h = 17]) => SizedBox(height: h);

class MessagePreview extends StatelessWidget {
  final String message, workspace;
  const MessagePreview(this.message,
      {super.key, this.workspace = 'Acme Studio'});
  @override
  Widget build(BuildContext context) => Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: const Color(0xFFF0EEE7),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
            padding: const EdgeInsets.all(13),
            color: const Color(0xFF315447),
            child: Row(children: [
              Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                      color: Color(0xFF547669), shape: BoxShape.circle),
                  child: const Icon(Icons.storefront_outlined,
                      color: Colors.white, size: 15)),
              const SizedBox(width: 9),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(workspace,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const Text('Business account',
                        style: TextStyle(color: Color(0xFFBFD0C7), fontSize: 8))
                  ])),
              const Icon(Icons.more_vert_rounded, color: Colors.white, size: 17)
            ])),
        Padding(
            padding: const EdgeInsets.fromLTRB(14, 19, 24, 20),
            child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(.03),
                          offset: const Offset(0, 2),
                          blurRadius: 3)
                    ]),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          message.isEmpty
                              ? 'Your message preview will appear here.'
                              : message
                                  .replaceAll('{{1}}', 'Amara')
                                  .replaceAll('{{2}}', 'your offer'),
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF3E453E),
                              height: 1.65)),
                      const SizedBox(height: 9),
                      const Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('10:42',
                                style: TextStyle(fontSize: 8, color: muted)),
                            SizedBox(width: 4),
                            Icon(Icons.done_all_rounded,
                                size: 13, color: Color(0xFF70A9B8))
                          ])
                    ]))),
      ]));
}

class Dialogs {
  final AppController c;
  final BuildContext context;
  Dialogs(this.context, this.c);

  Future<bool> confirm(String title, String description,
          {String button = 'Delete', bool danger = true}) async =>
      await showDialog<bool>(
          context: context,
          builder: (ctx) => DialogFrame(
              title: title,
              actions: [
                ActionButton('Cancel',
                    onPressed: () => Navigator.pop(ctx, false)),
                ActionButton(button,
                    primary: true, onPressed: () => Navigator.pop(ctx, true))
              ],
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: danger ? const Color(0xFFFAEEEE) : paleGreen,
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(
                            danger
                                ? Icons.delete_outline_rounded
                                : Icons.send_outlined,
                            color: danger ? const Color(0xFFB16B67) : forest,
                            size: 22)),
                    gap(),
                    Text(description,
                        style: const TextStyle(
                            color: muted, fontSize: 12, height: 1.7))
                  ]))) ??
      false;

  Future<void> delete(String resource, int id, String name) async {
    final extra = resource == 'groups'
        ? 'Contacts will stay in your workspace. Any unsent drafts for this group will also be removed.'
        : 'This action cannot be undone.';
    if (!await confirm(
        'Delete ${resource == 'contacts' ? 'contact' : resource == 'groups' ? 'group' : resource == 'templates' ? 'template' : 'campaign'}?',
        '“$name” will be removed. $extra')) return;
    try {
      await c.remove(resource, id);
      toast('Removed successfully.');
    } catch (e) {
      toast(e.toString(), error: true);
    }
  }

  Future<void> contactEditor([Map<String, dynamic>? record]) async {
    final first = TextEditingController(text: record?['first_name'] ?? ''),
        last = TextEditingController(text: record?['last_name'] ?? ''),
        phone = TextEditingController(text: record?['phone'] ?? ''),
        email = TextEditingController(text: record?['email'] ?? ''),
        company = TextEditingController(text: record?['company'] ?? ''),
        source = TextEditingController(text: record?['consent_source'] ?? '');
    String status = record?['consent_status'] ?? 'pending';
    int? groupId = (record?['groups'] as List?)?.isNotEmpty == true
        ? record!['groups'][0]['id']
        : c.contactGroup;
    final originalGroup = groupId;
    final otherGroups = (record?['groups'] as List? ?? [])
        .where((g) => g['id'] != originalGroup)
        .map<int>((g) => g['id'] as int)
        .toList();
    bool attested = status == 'opted_in', busy = false;
    String? error;
    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => DialogFrame(
                title: record == null ? 'Add a contact' : 'Edit contact',
                subtitle: 'A real person. A better connection.',
                busy: busy,
                actions: [
                  ActionButton('Cancel',
                      onPressed: busy ? null : () => Navigator.pop(ctx)),
                  ActionButton(record == null ? 'Add contact' : 'Save changes',
                      primary: true, busy: busy, onPressed: () async {
                    set(() => error = null);
                    if (first.text.trim().isEmpty ||
                        phone.text.trim().isEmpty) {
                      set(() => error =
                          'First name and an international phone number are required.');
                      return;
                    }
                    if (status == 'opted_in' &&
                        (!attested || source.text.trim().isEmpty)) {
                      set(() => error =
                          'Confirm the opt-in and record its source before saving.');
                      return;
                    }
                    set(() => busy = true);
                    try {
                      final payload = {
                        'first_name': first.text,
                        'last_name': last.text,
                        'phone': phone.text,
                        'email': email.text,
                        'company': company.text,
                        'consent_status': status,
                        'consent_source': source.text,
                        'group_ids': groupId == null
                            ? []
                            : {groupId, ...otherGroups}.toList(),
                        'tags': record?['tags'] ?? []
                      };
                      if (record == null) {
                        await c.api.post('/contacts', payload);
                      } else {
                        await c.api.put('/contacts/${record['id']}', payload);
                      }
                      await c.refresh();
                      if (ctx.mounted) Navigator.pop(ctx);
                      toast(record == null
                          ? 'Contact added. Welcome to the community.'
                          : 'Contact updated.');
                    } catch (e) {
                      if (ctx.mounted) {
                        set(() {
                          busy = false;
                          error = e.toString();
                        });
                      }
                    }
                  })
                ],
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      errorBox(error),
                      Row(children: [
                        Expanded(
                            child: FieldLabel('First name *',
                                child: input(first, hint: 'Amara'))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: FieldLabel('Last name',
                                child: input(last, hint: 'Okafor')))
                      ]),
                      gap(),
                      FieldLabel('WhatsApp number *',
                          help:
                              'Use the international format, including the country code.',
                          child: input(phone,
                              hint: '+234 803 123 4567',
                              keyboard: TextInputType.phone)),
                      gap(),
                      FieldLabel('Email address',
                          child: input(email,
                              hint: 'amara@example.com',
                              keyboard: TextInputType.emailAddress)),
                      gap(),
                      Row(children: [
                        Expanded(
                            child: FieldLabel('Company',
                                child: input(company, hint: 'Optional'))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: FieldLabel('Contact group',
                                child: DropdownButtonFormField<int>(
                                    value: groupId,
                                    isExpanded: true,
                                    style: const TextStyle(
                                        fontSize: 11, color: ink),
                                    decoration: const InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 13)),
                                    items: [
                                      const DropdownMenuItem<int>(
                                          value: null, child: Text('No group')),
                                      ...c.groups.map((g) =>
                                          DropdownMenuItem<int>(
                                              value: g['id'],
                                              child: Text(g['name'],
                                                  overflow:
                                                      TextOverflow.ellipsis)))
                                    ],
                                    onChanged: (v) => set(() => groupId = v))))
                      ]),
                      gap(),
                      FieldLabel('Messaging permission',
                          child: DropdownButtonFormField<String>(
                              value: status,
                              style: const TextStyle(fontSize: 12, color: ink),
                              items: const [
                                DropdownMenuItem(
                                    value: 'pending',
                                    child: Text('Pending opt-in')),
                                DropdownMenuItem(
                                    value: 'opted_in', child: Text('Opted in')),
                                DropdownMenuItem(
                                    value: 'unsubscribed',
                                    child: Text('Unsubscribed'))
                              ],
                              onChanged: (v) => set(() => status = v!))),
                      if (status == 'opted_in') ...[
                        gap(),
                        FieldLabel('Permission source *',
                            help:
                                'For example: store opt-in form, event sign-up, or written permission.',
                            child: input(source,
                                hint: 'Where did this person opt in?')),
                        gap(6),
                        CheckboxListTile(
                            value: attested,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (v) => set(() => attested = v ?? false),
                            title: const Text(
                                'I confirm this contact agreed to receive marketing messages.',
                                style: TextStyle(
                                    fontSize: 11, color: muted, height: 1.5)))
                      ],
                      if (record?['is_demo'] == true) ...[
                        gap(),
                        const InfoBanner('Fictional demo contact',
                            'This contact can be used for demo campaigns, never for live delivery.',
                            icon: Icons.science_outlined)
                      ],
                    ]))));
    for (final t in [first, last, phone, email, company, source]) {
      t.dispose();
    }
  }

  Future<void> groupEditor([Map<String, dynamic>? record]) async {
    final name = TextEditingController(text: record?['name'] ?? ''),
        desc = TextEditingController(text: record?['description'] ?? '');
    String color = record?['color'] ?? '#C9DDB2';
    bool busy = false;
    String? error;
    const colors = [
      '#C9DDB2',
      '#C6D4ED',
      '#E7C6EA',
      '#F1D8B3',
      '#B8DEDA',
      '#D7D1EE'
    ];
    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => DialogFrame(
                title: record == null
                    ? 'Create a contact group'
                    : 'Edit contact group',
                subtitle: 'Give your audience a place to belong.',
                busy: busy,
                actions: [
                  ActionButton('Cancel',
                      onPressed: busy ? null : () => Navigator.pop(ctx)),
                  ActionButton(record == null ? 'Create group' : 'Save changes',
                      primary: true, busy: busy, onPressed: () async {
                    set(() => busy = true);
                    try {
                      final payload = {
                        'name': name.text,
                        'description': desc.text,
                        'color': color
                      };
                      if (record == null) {
                        await c.api.post('/groups', payload);
                      } else {
                        await c.api.put('/groups/${record['id']}', payload);
                      }
                      await c.loadCore();
                      if (ctx.mounted) Navigator.pop(ctx);
                      toast(record == null
                          ? 'Your new group is ready.'
                          : 'Group updated.');
                    } catch (e) {
                      if (ctx.mounted) {
                        set(() {
                          busy = false;
                          error = e.toString();
                        });
                      }
                    }
                  })
                ],
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      errorBox(error),
                      FieldLabel('Group name *',
                          child: input(name, hint: 'e.g. Abuja founders')),
                      gap(),
                      FieldLabel('Description',
                          child: input(desc,
                              hint: 'What brings this community together?',
                              lines: 3)),
                      gap(),
                      FieldLabel('Group color',
                          child: Wrap(
                              spacing: 12,
                              children: colors
                                  .map((v) => InkWell(
                                      onTap: () => set(() => color = v),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                              color: hexColor(v),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: color == v
                                                      ? forest
                                                      : Colors.transparent,
                                                  width: 2)),
                                          child: color == v
                                              ? const Icon(Icons.check_rounded,
                                                  size: 17, color: forest)
                                              : null)))
                                  .toList())),
                      gap(22),
                      const InfoBanner(
                          'A workspace group, not a WhatsApp connection',
                          'Add members from your contacts or upload a consented CSV. WhatsApp does not expose the member lists of existing personal-account groups.')
                    ]))));
    name.dispose();
    desc.dispose();
  }

  Future<void> templateEditor([Map<String, dynamic>? record]) async {
    final title = TextEditingController(text: record?['title'] ?? ''),
        name = TextEditingController(text: record?['name'] ?? ''),
        body = TextEditingController(
            text:
                record?['body'] ?? 'Hi {{1}} 👋\n\n\n\nReply STOP to opt out.');
    String category = record?['category'] ?? 'MARKETING';
    bool busy = false;
    String? error;
    final managed = record?['meta_id'] != null;
    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => DialogFrame(
                width: 790,
                title: managed
                    ? 'WhatsApp template'
                    : record == null
                        ? 'Create a message template'
                        : 'Edit message template',
                subtitle: 'Make your message feel a little more personal.',
                busy: busy,
                actions: [
                  ActionButton(managed ? 'Close' : 'Cancel',
                      onPressed: busy ? null : () => Navigator.pop(ctx)),
                  if (!managed)
                    ActionButton(
                        record == null ? 'Create template' : 'Save changes',
                        primary: true,
                        busy: busy, onPressed: () async {
                      set(() => busy = true);
                      try {
                        final payload = {
                          'title': title.text,
                          'name': name.text,
                          'body': body.text,
                          'category': category,
                          'language': record?['language'] ?? 'en',
                          'color': record?['color'] ?? '#ECF2E4'
                        };
                        if (record == null) {
                          await c.api.post('/templates', payload);
                        } else {
                          await c.api
                              .put('/templates/${record['id']}', payload);
                        }
                        await c.loadCore();
                        if (ctx.mounted) Navigator.pop(ctx);
                        toast(record == null
                            ? 'Template created. Try it in a demo campaign.'
                            : 'Template saved as a draft.');
                      } catch (e) {
                        if (ctx.mounted) {
                          set(() {
                            busy = false;
                            error = e.toString();
                          });
                        }
                      }
                    })
                ],
                child: LayoutBuilder(builder: (ctx, size) {
                  final form = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        errorBox(error),
                        FieldLabel('Template title *',
                            child: input(title,
                                hint: 'e.g. A little thank-you',
                                readOnly: managed, onChanged: (s) {
                              if (record == null) {
                                set(() => name.text = s
                                    .toLowerCase()
                                    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                                    .replaceAll(RegExp(r'_+$'), ''));
                              }
                            })),
                        gap(),
                        FieldLabel('Template name *',
                            help:
                                'Lowercase letters, numbers, and underscores.',
                            child: input(name,
                                hint: 'customer_thank_you', readOnly: managed)),
                        gap(),
                        FieldLabel('Category',
                            child: DropdownButtonFormField<String>(
                                value: category,
                                style:
                                    const TextStyle(fontSize: 12, color: ink),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'MARKETING',
                                      child: Text('Marketing')),
                                  DropdownMenuItem(
                                      value: 'UTILITY', child: Text('Utility'))
                                ],
                                onChanged: managed
                                    ? null
                                    : (v) => set(() => category = v!))),
                        gap(),
                        FieldLabel('Message *',
                            help:
                                'Use {{1}} for the first name. Body limit: 1,024 characters.',
                            child: input(body,
                                lines: 7,
                                readOnly: managed,
                                onChanged: (_) => set(() => {}))),
                        gap(6),
                        Text('${body.text.length}/1024 characters',
                            style: const TextStyle(fontSize: 9, color: muted)),
                        gap(),
                        const InfoBanner('Drafts stay in your workspace',
                            'Test any draft in demo mode. For live campaigns, create a text template in WhatsApp Manager, have it approved by Meta, then sync it here.')
                      ]);
                  final preview = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('MESSAGE PREVIEW',
                            style: TextStyle(
                                fontSize: 9,
                                color: muted,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1)),
                        gap(10),
                        MessagePreview(body.text,
                            workspace: c.user!['workspace']),
                        gap(12),
                        if (managed) StatusPill(record?['status'] ?? 'Pending')
                      ]);
                  if (size.maxWidth < 580) {
                    return Column(children: [form, gap(25), preview]);
                  }
                  return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: form),
                        const SizedBox(width: 24),
                        Expanded(flex: 3, child: preview)
                      ]);
                }))));
    title.dispose();
    name.dispose();
    body.dispose();
  }

  Future<void> campaignEditor(
      {Map<String, dynamic>? record, int? templateId, int? groupId}) async {
    final name = TextEditingController(text: record?['name'] ?? '');
    templateId = record?['template_id'] ??
        templateId ??
        (c.templates.isNotEmpty ? c.templates.first['id'] : null);
    groupId = record?['group_id'] ?? groupId;
    Map<String, dynamic>? selectedTemplate() {
      for (final t in c.templates) {
        if (t['id'] == templateId) return Map<String, dynamic>.from(t);
      }
      return null;
    }

    final body = TextEditingController(
        text: record?['message'] ?? selectedTemplate()?['body'] ?? '');
    final extraVars = List.generate(
        4,
        (i) => TextEditingController(
            text: (record?['variables'] as List? ?? []).length > i
                ? record!['variables'][i]
                : ''));
    String mode = record?['mode'] ?? 'demo';
    bool busy = false;
    String? error;
    DateTime? scheduled = record?['scheduled_at'] != null
        ? DateTime.tryParse(record!['scheduled_at'])?.toLocal()
        : null;
    bool schedule = scheduled != null && scheduled.isAfter(DateTime.now());
    if (!schedule) {
      scheduled = DateTime.now().add(const Duration(days: 1));
    }
    bool liveConfirmed = false;
    final canLive =
        c.integration['connected'] == true && c.user?['demo'] != true;
    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
              final eligible = groupId == null
                  ? c.dashboard['opted_in'] ?? 0
                  : c.groups.firstWhere((g) => g['id'] == groupId,
                      orElse: () => {'opted_in': 0})['opted_in'];
              Future<void> save(bool send) async {
                set(() => error = null);
                if (name.text.trim().isEmpty || body.text.trim().isEmpty) {
                  set(() =>
                      error = 'Give your campaign a name and add a message.');
                  return;
                }
                if (mode == 'live' && (send || schedule) && !liveConfirmed) {
                  set(() => error =
                      'Confirm that you are sending an approved template to people who opted in.');
                  return;
                }
                set(() => busy = true);
                try {
                  final payload = {
                    'name': name.text,
                    'template_id': templateId,
                    'group_id': groupId,
                    'message': body.text,
                    'mode': mode,
                    'confirm_live_schedule':
                        mode == 'live' && schedule && liveConfirmed,
                    'scheduled_at':
                        schedule ? scheduled!.toUtc().toIso8601String() : null,
                    'variables': extraVars
                        .take(math.max(0,
                            (selectedTemplate()?['variable_count'] ?? 1) - 1))
                        .map((v) => v.text)
                        .toList(),
                    'color': selectedTemplate()?['color'] ?? '#ECF2E4'
                  };
                  final created = record == null
                      ? await c.api.post('/campaigns', payload)
                      : await c.api.put('/campaigns/${record['id']}', payload);
                  if (send && !schedule) {
                    await c.api.post('/campaigns/${created['id']}/send',
                        {'confirm_live': mode == 'live' && liveConfirmed});
                  }
                  await c.loadCore();
                  if (ctx.mounted) Navigator.pop(ctx);
                  toast(schedule
                      ? 'Campaign scheduled. You’re all set.'
                      : send
                          ? (mode == 'demo'
                              ? 'Demo campaign started. No real messages are sent.'
                              : 'Campaign started. Delivery receipts will update automatically.')
                          : 'Campaign saved as a draft.');
                  c.navigate(AppPage.campaigns);
                } catch (e) {
                  if (ctx.mounted) {
                    set(() {
                      busy = false;
                      error = e.toString();
                    });
                  }
                }
              }

              return DialogFrame(
                  width: 830,
                  title: record == null ? 'Create a campaign' : 'Edit campaign',
                  subtitle:
                      'The right words. The right people. One thoughtful campaign.',
                  busy: busy,
                  actions: [
                    ActionButton('Cancel',
                        onPressed: busy ? null : () => Navigator.pop(ctx)),
                    if (!schedule)
                      ActionButton('Save draft',
                          onPressed: busy ? null : () => save(false)),
                    ActionButton(
                        schedule
                            ? 'Schedule ${mode == 'demo' ? 'demo' : 'campaign'}'
                            : mode == 'demo'
                                ? 'Run demo campaign'
                                : 'Send live campaign',
                        icon: schedule
                            ? Icons.schedule_rounded
                            : Icons.arrow_forward_rounded,
                        primary: true,
                        busy: busy,
                        onPressed: () => save(!schedule))
                  ],
                  child: LayoutBuilder(builder: (ctx, size) {
                    final form = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          errorBox(error),
                          FieldLabel('Campaign name *',
                              child:
                                  input(name, hint: 'e.g. Weekend flash sale')),
                          gap(),
                          FieldLabel('Audience',
                              child: DropdownButtonFormField<int>(
                                  value: groupId,
                                  isExpanded: true,
                                  style:
                                      const TextStyle(fontSize: 12, color: ink),
                                  items: [
                                    const DropdownMenuItem<int>(
                                        value: null,
                                        child: Text('All opted-in contacts')),
                                    ...c.groups.map((g) => DropdownMenuItem<
                                            int>(
                                        value: g['id'],
                                        child: Text(
                                            '${g['name']} · ${number(g['opted_in'])}',
                                            overflow: TextOverflow.ellipsis)))
                                  ],
                                  onChanged: (v) => set(() => groupId = v))),
                          gap(7),
                          Row(children: [
                            const Icon(Icons.verified_user_outlined,
                                size: 12, color: forest),
                            const SizedBox(width: 5),
                            Text(
                                '${number(eligible)} opted-in contacts · unsubscribed contacts excluded',
                                style:
                                    const TextStyle(fontSize: 9, color: forest))
                          ]),
                          gap(),
                          FieldLabel('Message template',
                              child: DropdownButtonFormField<int>(
                                  value: templateId,
                                  isExpanded: true,
                                  style:
                                      const TextStyle(fontSize: 12, color: ink),
                                  items: [
                                    const DropdownMenuItem<int>(
                                        value: null,
                                        child: Text(
                                            'Write a custom demo message')),
                                    ...c.templates.map((t) =>
                                        DropdownMenuItem<int>(
                                            value: t['id'],
                                            child: Text(t['title'],
                                                overflow:
                                                    TextOverflow.ellipsis)))
                                  ],
                                  onChanged: (v) => set(() {
                                        templateId = v;
                                        body.text =
                                            selectedTemplate()?['body'] ?? '';
                                      }))),
                          gap(),
                          FieldLabel('Your message *',
                              help: mode == 'live'
                                  ? 'Live messages must match the approved template.'
                                  : '{{1}} is replaced with each person’s first name. Max 1,024 characters.',
                              child: input(body,
                                  lines: 6,
                                  readOnly: mode == 'live',
                                  onChanged: (_) => set(() => {}))),
                          if ((selectedTemplate()?['variable_count'] ?? 1) >
                              1) ...[
                            gap(),
                            ...List.generate(
                                math.max(
                                    0,
                                    (selectedTemplate()?['variable_count'] ??
                                            1) -
                                        1),
                                (i) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: FieldLabel('Value for {{${i + 2}}}',
                                        child: input(extraVars[i],
                                            hint:
                                                'Enter a value for every recipient'))))
                          ],
                          gap(),
                          FieldLabel('Delivery mode',
                              child: DropdownButtonFormField<String>(
                                  value: mode,
                                  style:
                                      const TextStyle(fontSize: 12, color: ink),
                                  items: [
                                    const DropdownMenuItem(
                                        value: 'demo',
                                        child:
                                            Text('Demo · simulated delivery')),
                                    DropdownMenuItem(
                                        value: 'live',
                                        enabled: canLive,
                                        child: Text(
                                            canLive
                                                ? 'Live · WhatsApp Business'
                                                : 'Live · connect WhatsApp in Settings',
                                            style: TextStyle(
                                                color: canLive ? ink : muted)))
                                  ],
                                  onChanged: (v) => set(() => mode = v!))),
                          gap(5),
                          SwitchListTile.adaptive(
                              value: schedule,
                              onChanged: (v) => set(() => schedule = v),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              activeColor: forest,
                              title: const Text('Schedule for later',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500)),
                              subtitle: const Text(
                                  'Your campaign runs even when the app is closed.',
                                  style: TextStyle(fontSize: 9, color: muted))),
                          if (schedule) ...[
                            gap(5),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              ActionButton(
                                  DateFormat('MMM d, yyyy').format(scheduled!),
                                  icon: Icons.calendar_today_outlined,
                                  onPressed: () async {
                                final date = await showDatePicker(
                                    context: ctx,
                                    initialDate: scheduled!,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)));
                                if (date != null) {
                                  set(() => scheduled = DateTime(
                                      date.year,
                                      date.month,
                                      date.day,
                                      scheduled!.hour,
                                      scheduled!.minute));
                                }
                              }),
                              ActionButton(
                                  DateFormat('h:mm a').format(scheduled!),
                                  icon: Icons.schedule_rounded,
                                  onPressed: () async {
                                final t = await showTimePicker(
                                    context: ctx,
                                    initialTime:
                                        TimeOfDay.fromDateTime(scheduled!));
                                if (t != null) {
                                  set(() => scheduled = DateTime(
                                      scheduled!.year,
                                      scheduled!.month,
                                      scheduled!.day,
                                      t.hour,
                                      t.minute));
                                }
                              })
                            ]),
                            gap(7),
                            const Text(
                                'Displayed in your device’s local timezone.',
                                style: TextStyle(fontSize: 9, color: muted))
                          ],
                          if (mode == 'live') ...[
                            gap(),
                            CheckboxListTile(
                                value: liveConfirmed,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: (v) =>
                                    set(() => liveConfirmed = v ?? false),
                                title: const Text(
                                    'I confirm this approved marketing message is going only to contacts with recorded opt-in.',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: forest,
                                        height: 1.5)))
                          ],
                        ]);
                    final preview = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('MESSAGE PREVIEW',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: muted,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1)),
                          gap(10),
                          MessagePreview(body.text,
                              workspace: c.user!['workspace']),
                          gap(16),
                          InfoBanner(
                              mode == 'demo'
                                  ? 'You’re in demo mode'
                                  : 'Consent comes first',
                              mode == 'demo'
                                  ? 'Explore the full workflow safely. Delivery and read receipts are simulated. No messages are sent to WhatsApp.'
                                  : 'Fictional demo contacts, pending contacts, and unsubscribed contacts are always excluded.',
                              icon: mode == 'demo'
                                  ? Icons.science_outlined
                                  : Icons.verified_user_outlined)
                        ]);
                    if (size.maxWidth < 620) {
                      return Column(children: [form, gap(23), preview]);
                    }
                    return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: form),
                          const SizedBox(width: 25),
                          Expanded(flex: 3, child: preview)
                        ]);
                  }));
            }));
    name.dispose();
    body.dispose();
    for (final v in extraVars) {
      v.dispose();
    }
  }

  Future<void> importContacts({int? groupId}) async {
    bool busy = false, hasConsent = false;
    String? error;
    String filename = '';
    Map<String, dynamic>? preview;
    final source = TextEditingController();
    const sample =
        'first_name,last_name,phone,email,consent_status\nAmara,Okafor,+12025550101,amara@demo.example,opted_in\nDavid,Chen,+12025550102,david@demo.example,opted_in\nSarah,Johnson,+12025550103,sarah@demo.example,pending\nFatima,Ibrahim,+12025550104,fatima@demo.example,opted_in\nTunde,Olawale,+12025550105,tunde@demo.example,opted_in\n';
    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
              Future<void> pick() async {
                try {
                  final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['csv'],
                      withData: true);
                  if (result == null) return;
                  final f = result.files.single;
                  if (f.bytes == null) {
                    throw Exception('The file could not be read.');
                  }
                  set(() {
                    busy = true;
                    error = null;
                  });
                  final resultPreview = await c.api.uploadCsv(f.name, f.bytes!);
                  if (ctx.mounted) {
                    set(() {
                      preview = Map<String, dynamic>.from(resultPreview);
                      filename = f.name;
                      busy = false;
                    });
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    set(() {
                      error = e.toString();
                      busy = false;
                    });
                  }
                }
              }

              final rows = (preview?['contacts'] as List? ?? []);
              return DialogFrame(
                  width: 650,
                  title: preview == null
                      ? 'Import your contacts'
                      : 'Review your contact import',
                  subtitle: 'One list. A whole community of possibilities.',
                  busy: busy,
                  actions: [
                    ActionButton('Cancel',
                        onPressed: busy ? null : () => Navigator.pop(ctx)),
                    if (preview != null)
                      ActionButton('Import ${rows.length} contacts',
                          primary: true,
                          busy: busy,
                          onPressed: rows.isEmpty
                              ? null
                              : () async {
                                  set(() => busy = true);
                                  try {
                                    final result =
                                        await c.api.post('/contacts/import', {
                                      'contacts': rows,
                                      'group_id': groupId,
                                      'has_consent': hasConsent,
                                      'consent_source': source.text
                                    });
                                    await c.refresh();
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    toast(
                                        '${result['imported']} contacts imported. ${result['duplicates']} duplicates skipped.');
                                    c.navigate(AppPage.contacts);
                                    if (groupId != null) {
                                      await c.openGroup(groupId!);
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      set(() {
                                        busy = false;
                                        error = e.toString();
                                      });
                                    }
                                  }
                                })
                  ],
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        errorBox(error),
                        Row(children: [
                          Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                  color: forest, shape: BoxShape.circle),
                              child: const Text('1',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 10))),
                          const SizedBox(width: 8),
                          const Text('Upload a list',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w500)),
                          const Expanded(
                              child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 13),
                                  child: Divider())),
                          Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: preview == null ? line : forest,
                                  shape: BoxShape.circle),
                              child: Text('2',
                                  style: TextStyle(
                                      color: preview == null
                                          ? muted
                                          : Colors.white,
                                      fontSize: 10))),
                          const SizedBox(width: 8),
                          const Text('Review & save',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w500))
                        ]),
                        gap(22),
                        if (preview == null) ...[
                          Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 29, horizontal: 20),
                              decoration: BoxDecoration(
                                  color: background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: line)),
                              child: Column(children: [
                                Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                        color: paleGreen,
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: const Icon(
                                        Icons.upload_file_outlined,
                                        color: forest,
                                        size: 25)),
                                gap(14),
                                const Text('Bring your people to Relay',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                gap(6),
                                const Text(
                                    'Upload a CSV file · up to 5,000 contacts · max 2 MB',
                                    style:
                                        TextStyle(fontSize: 10, color: muted)),
                                gap(16),
                                ActionButton('Choose CSV file',
                                    icon: Icons.add_rounded,
                                    onPressed: busy ? null : pick,
                                    busy: busy,
                                    primary: true)
                              ])),
                          gap(12),
                          Row(children: [
                            const Expanded(
                                child: Text('Need the right format?',
                                    style:
                                        TextStyle(fontSize: 10, color: muted))),
                            TextButton.icon(
                                onPressed: () => saveBytes(
                                    Uint8List.fromList(utf8.encode(sample)),
                                    'relay-sample-contacts.csv',
                                    'text/csv'),
                                icon: const Icon(Icons.file_download_outlined,
                                    size: 14),
                                label: const Text('Download sample CSV',
                                    style: TextStyle(fontSize: 10)))
                          ]),
                          gap(9),
                          const InfoBanner(
                              'Import from a group, with permission',
                              'Select a destination group below and upload a member list you are authorized to use. This is not WhatsApp group scraping. Chat exports do not prove membership or consent.')
                        ] else ...[
                          Surface(
                              padding: const EdgeInsets.all(14),
                              color: paleGreen,
                              child: Row(children: [
                                const Icon(Icons.description_outlined,
                                    color: forest, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(filename,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                      Text(
                                          '${preview!['valid']} valid contacts · ${preview!['invalid']} invalid rows',
                                          style: const TextStyle(
                                              fontSize: 10, color: muted))
                                    ])),
                                TextButton(
                                    onPressed: busy ? null : pick,
                                    child: const Text('Change file',
                                        style: TextStyle(fontSize: 10)))
                              ])),
                          gap(14),
                          Surface(
                              child: Column(children: [
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                color: background,
                                child: const Row(children: [
                                  Expanded(
                                      child: Text('CONTACT',
                                          style: TextStyle(
                                              fontSize: 9, color: muted))),
                                  Expanded(
                                      child: Text('PHONE',
                                          style: TextStyle(
                                              fontSize: 9, color: muted))),
                                  Text('OPT-IN',
                                      style:
                                          TextStyle(fontSize: 9, color: muted))
                                ])),
                            ...rows.take(5).map((r) => Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 11),
                                child: Row(children: [
                                  Expanded(
                                      child: Text(
                                          '${r['first_name']} ${r['last_name']}',
                                          style: const TextStyle(fontSize: 10),
                                          overflow: TextOverflow.ellipsis)),
                                  Expanded(
                                      child: Text(r['phone'],
                                          style: const TextStyle(
                                              fontSize: 10, color: muted))),
                                  SizedBox(
                                      width: 42,
                                      child: Text(
                                          r['consent_status'] == 'opted_in'
                                              ? 'Yes'
                                              : 'No',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: r['consent_status'] ==
                                                      'opted_in'
                                                  ? forest
                                                  : muted)))
                                ]))),
                            if (rows.length > 5)
                              Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(
                                      'And ${rows.length - 5} more contacts',
                                      style: const TextStyle(
                                          fontSize: 10, color: muted)))
                          ])),
                          if ((preview!['invalid'] ?? 0) > 0) ...[
                            gap(12),
                            Text(
                                'Invalid rows will be skipped. ${(preview!['errors'] as List).take(2).map((e) => 'Row ${e['row']}: ${e['reason']}').join(' ')}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFB16B67),
                                    height: 1.5))
                          ],
                          gap(12),
                          const Text(
                              'Duplicate phone numbers are skipped automatically. Existing opt-in records are never overwritten.',
                              style: TextStyle(
                                  fontSize: 10, color: muted, height: 1.5)),
                        ],
                        gap(19),
                        FieldLabel('Save to contact group',
                            child: DropdownButtonFormField<int>(
                                value: groupId,
                                isExpanded: true,
                                style:
                                    const TextStyle(fontSize: 12, color: ink),
                                items: [
                                  const DropdownMenuItem<int>(
                                      value: null,
                                      child: Text('No group · all contacts')),
                                  ...c.groups.map((g) => DropdownMenuItem<int>(
                                      value: g['id'],
                                      child: Text(g['name'],
                                          overflow: TextOverflow.ellipsis)))
                                ],
                                onChanged: (v) => set(() => groupId = v))),
                        if (preview != null) ...[
                          gap(12),
                          CheckboxListTile(
                              value: hasConsent,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) =>
                                  set(() => hasConsent = v ?? false),
                              title: const Text(
                                  'I am authorized to save this list, and contacts marked opted_in gave permission to receive marketing messages.',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: muted,
                                      height: 1.5))),
                          if (hasConsent) ...[
                            gap(8),
                            FieldLabel('Opt-in source *',
                                child: input(source,
                                    hint:
                                        'e.g. event registration form, October 2026'))
                          ],
                          gap(8),
                          const Text(
                              'Without permission confirmation, contacts are saved as pending and cannot receive campaigns. Replace sample rows with your own contacts.',
                              style: TextStyle(
                                  fontSize: 10, color: muted, height: 1.5))
                        ],
                      ]));
            }));
    source.dispose();
  }

  Future<void> exportContacts(
      {String format = 'vcf',
      int? groupId,
      List<int>? ids,
      bool all = false}) async {
    try {
      final selection = all
          ? <int>[]
          : ids ?? (groupId != null ? <int>[] : c.selectedContacts.toList());
      final bytes = await c.api.download('/contacts/export', {
        'format': format,
        if (!all && (groupId != null || c.contactGroup != null))
          'group_id': '${groupId ?? c.contactGroup}',
        if (selection.isNotEmpty) 'ids': selection.join(',')
      });
      await saveBytes(bytes, 'relay-contacts.$format',
          format == 'vcf' ? 'text/vcard' : 'text/csv');
      toast(format == 'vcf'
          ? 'vCard ready. Open it to import all contacts at once.'
          : 'Your contact CSV is ready.');
    } catch (e) {
      toast(e.toString(), error: true);
    }
  }

  Future<void> saveContacts({int? groupId}) async {
    bool busy = false;
    String? error;
    final count = groupId == null && c.selectedContacts.isNotEmpty
        ? c.selectedContacts.length
        : groupId != null
            ? c.groups.firstWhere((g) => g['id'] == groupId,
                orElse: () => {'total': 0})['total']
            : c.contactData['total'];
    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => DialogFrame(
                title: 'Save contacts in one go',
                subtitle:
                    '${number(count)} contacts · no copy-and-paste needed.',
                busy: busy,
                actions: [
                  ActionButton('Cancel',
                      onPressed: busy ? null : () => Navigator.pop(ctx)),
                  if (!kIsWeb)
                    ActionButton('Save to address book', busy: busy,
                        onPressed: () async {
                      set(() => busy = true);
                      try {
                        final count = await saveToDevice(c.api,
                            ids: groupId == null
                                ? c.selectedContacts.toList()
                                : [],
                            groupId: groupId ?? c.contactGroup);
                        if (ctx.mounted) Navigator.pop(ctx);
                        toast(
                            '$count new contacts saved to your address book.');
                      } catch (e) {
                        if (ctx.mounted) {
                          set(() {
                            busy = false;
                            error = e.toString();
                          });
                        }
                      }
                    }),
                  ActionButton('Download vCard',
                      icon: Icons.file_download_outlined,
                      primary: true,
                      onPressed: busy
                          ? null
                          : () async {
                              await exportContacts(groupId: groupId);
                              if (ctx.mounted) Navigator.pop(ctx);
                            })
                ],
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      errorBox(error),
                      Center(
                          child: Container(
                              width: 66,
                              height: 66,
                              decoration: BoxDecoration(
                                  color: paleGreen,
                                  borderRadius: BorderRadius.circular(18)),
                              child: const Icon(Icons.contact_phone_outlined,
                                  size: 31, color: forest))),
                      gap(22),
                      const Text('Your community, in your address book.',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      gap(9),
                      const Text(
                          'Download a single vCard (.vcf) file and open it on your phone. Android and iOS let you import the complete list at once.',
                          style: TextStyle(
                              fontSize: 12, color: muted, height: 1.7)),
                      gap(18),
                      const InfoBanner(
                          kIsWeb ? 'Browser preview' : 'Native contact saving',
                          kIsWeb
                              ? 'Browsers cannot write directly to your address book. In the Android/iOS app, the Save to address book button requests contacts permission and saves the list directly.'
                              : 'Direct saving requests your permission, skips existing phone numbers, and never adds fictional demo contacts.',
                          icon: Icons.phone_android_outlined),
                      if (c.user?['demo'] == true) ...[
                        gap(12),
                        const Text(
                            'Demo numbers are fictional. Use real contacts you are authorized to save on your own device.',
                            style: TextStyle(
                                fontSize: 10, color: muted, height: 1.5))
                      ]
                    ]))));
  }

  Future<void> reportExport() async {
    try {
      final bytes = await c.api.download('/reports/export');
      await saveBytes(bytes, 'relay-campaign-report.csv', 'text/csv');
      toast('Your campaign report is ready.');
    } catch (e) {
      toast(e.toString(), error: true);
    }
  }

  Future<void> campaignDetail(int id) async {
    final future = c.api.get('/campaigns/$id');
    await showDialog(
        context: context,
        builder: (ctx) => FutureBuilder(
            future: future,
            builder: (ctx, snapshot) {
              if (!snapshot.hasData) {
                return DialogFrame(
                    title: 'Campaign overview',
                    child: snapshot.hasError
                        ? errorBox(snapshot.error.toString())
                        : const Padding(
                            padding: EdgeInsets.all(30),
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))));
              }
              final data = Map<String, dynamic>.from(snapshot.data as Map);
              return DialogFrame(
                  width: 820,
                  title: data['name'],
                  subtitle:
                      '${data['audience']} · ${data['mode'] == 'demo' ? 'Simulated campaign' : 'WhatsApp Business'}',
                  actions: [
                    ActionButton('Close', onPressed: () => Navigator.pop(ctx)),
                    if (['Scheduled', 'Sending'].contains(data['status']))
                      ActionButton('Cancel campaign', onPressed: () async {
                        try {
                          await c.api.post('/campaigns/$id/cancel');
                          await c.loadCore();
                          if (ctx.mounted) Navigator.pop(ctx);
                          toast('Campaign canceled.');
                        } catch (e) {
                          toast(e.toString(), error: true);
                        }
                      }),
                    if (data['status'] == 'Draft')
                      ActionButton(
                          data['mode'] == 'demo'
                              ? 'Run demo'
                              : 'Send live campaign',
                          primary: true,
                          icon: Icons.send_outlined, onPressed: () async {
                        if (data['mode'] == 'live' &&
                            !await confirm('Send live campaign?',
                                'This approved template will be sent to ${number(data['audience_count'])} contacts with recorded permission. Meta messaging fees may apply.',
                                button: 'Send campaign', danger: false)) return;
                        try {
                          await c.api.post('/campaigns/$id/send',
                              {'confirm_live': data['mode'] == 'live'});
                          await c.loadCore();
                          if (ctx.mounted) Navigator.pop(ctx);
                          toast(data['mode'] == 'demo'
                              ? 'Demo campaign started.'
                              : 'Live campaign started.');
                        } catch (e) {
                          toast(e.toString(), error: true);
                        }
                      }),
                    if (!['Draft', 'Sending', 'Scheduled']
                        .contains(data['status']))
                      ActionButton('Duplicate campaign',
                          primary: true,
                          icon: Icons.copy_outlined, onPressed: () async {
                        try {
                          await c.api.post('/campaigns/$id/duplicate');
                          await c.loadCore();
                          if (ctx.mounted) Navigator.pop(ctx);
                          toast('Campaign duplicated as a draft.');
                          c.navigate(AppPage.campaigns);
                        } catch (e) {
                          toast(e.toString(), error: true);
                        }
                      })
                  ],
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          StatusPill(data['status']),
                          const Spacer(),
                          Text(shortDate(data['created_at'], year: true),
                              style:
                                  const TextStyle(fontSize: 10, color: muted))
                        ]),
                        gap(20),
                        Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              ('Recipients', data['total']),
                              ('Delivered', data['delivered']),
                              ('Read', data['read']),
                              ('Failed', data['failed'])
                            ]
                                .map((e) => SizedBox(
                                    width: math.min(
                                        160,
                                        (MediaQuery.sizeOf(ctx).width - 96) /
                                            2),
                                    child: Surface(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(e.$1,
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      color: muted)),
                                              gap(7),
                                              Text(number(e.$2),
                                                  style: const TextStyle(
                                                      fontSize: 24,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      letterSpacing: -.8))
                                            ]))))
                                .toList()),
                        gap(22),
                        if ((data['last_error'] ?? '').isNotEmpty)
                          errorBox(data['last_error']),
                        LayoutBuilder(builder: (ctx, size) {
                          final preview = MessagePreview(data['message'],
                              workspace: c.user!['workspace']);
                          final detail = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('CAMPAIGN DETAILS',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: muted,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1)),
                                gap(13),
                                _detailRow('Audience', data['audience']),
                                _detailRow('Eligible contacts',
                                    number(data['audience_count'])),
                                _detailRow(
                                    'Template',
                                    data['template']?['title'] ??
                                        'Custom demo message'),
                                _detailRow(
                                    'Scheduled',
                                    data['scheduled_at'] != null
                                        ? DateFormat('MMM d, h:mm a').format(
                                            DateTime.parse(data['scheduled_at'])
                                                .toLocal())
                                        : 'Not scheduled'),
                                _detailRow(
                                    'Mode',
                                    data['mode'] == 'demo'
                                        ? 'Demo · no real messages'
                                        : 'Live WhatsApp Business'),
                                gap(16),
                                InfoBanner(
                                    'Permission-first delivery',
                                    data['mode'] == 'demo'
                                        ? 'All delivery and read receipts shown here are simulated.'
                                        : 'Only contacts with recorded opt-in are eligible. Unsubscribed and fictional demo contacts are excluded.')
                              ]);
                          if (size.maxWidth < 620) {
                            return Column(children: [preview, gap(20), detail]);
                          }
                          return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: preview),
                                const SizedBox(width: 24),
                                Expanded(child: detail)
                              ]);
                        }),
                        if ((data['messages'] as List).isNotEmpty) ...[
                          gap(25),
                          const Text('Recent delivery receipts',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          gap(12),
                          ...(data['messages'] as List).take(8).map((m) =>
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 9),
                                  child: Row(children: [
                                    InitialAvatar(
                                        '${m['first_name'] ?? 'Removed'} ${m['last_name'] ?? 'contact'}',
                                        size: 28),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(
                                              '${m['first_name'] ?? 'Removed'} ${m['last_name'] ?? 'contact'}',
                                              style: const TextStyle(
                                                  fontSize: 11)),
                                          Text(m['phone'],
                                              style: const TextStyle(
                                                  fontSize: 9, color: muted))
                                        ])),
                                    StatusPill(m['status'])
                                  ])))
                        ],
                      ]));
            }));
  }

  Widget _detailRow(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, color: muted)),
        gap(3),
        Text(value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))
      ]));

  Future<void> connectWhatsApp() async {
    final phone = TextEditingController(),
        business = TextEditingController(),
        token = TextEditingController();
    bool busy = false;
    String? error;
    final demo = c.user?['demo'] == true;
    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => DialogFrame(
                title: 'Connect WhatsApp Business',
                subtitle:
                    'Official API. Real conversations. Your own business number.',
                busy: busy,
                actions: [
                  ActionButton('Close',
                      onPressed: busy ? null : () => Navigator.pop(ctx)),
                  if (demo)
                    ActionButton('Create your own workspace', primary: true,
                        onPressed: () async {
                      Navigator.pop(ctx);
                      await c.signOut();
                      toast(
                          'Choose Create an account to set up your workspace.');
                    })
                  else
                    ActionButton('Verify & connect', primary: true, busy: busy,
                        onPressed: () async {
                      set(() => busy = true);
                      try {
                        await c.api.post('/integrations/whatsapp', {
                          'phone_number_id': phone.text.trim(),
                          'business_account_id': business.text.trim(),
                          'access_token': token.text.trim()
                        });
                        await c.loadCore();
                        if (ctx.mounted) Navigator.pop(ctx);
                        toast(
                            'WhatsApp Business connected. Sync your templates next.');
                      } catch (e) {
                        if (ctx.mounted) {
                          set(() {
                            busy = false;
                            error = e.toString();
                          });
                        }
                      }
                    })
                ],
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      errorBox(error),
                      InfoBanner(
                          demo
                              ? 'Create your own workspace first'
                              : 'Connect your Meta business account',
                          demo
                              ? 'This demo workspace is isolated from live messaging. Sign out and create a workspace to securely connect your own credentials.'
                              : 'Use a system-user access token with WhatsApp messaging and management permissions. Credentials are verified with Meta and encrypted at rest.',
                          icon: Icons.link_rounded),
                      gap(21),
                      if (!demo) ...[
                        FieldLabel('Phone number ID',
                            child: input(phone,
                                hint: 'Your Meta phone number ID')),
                        gap(),
                        FieldLabel('WhatsApp Business Account ID',
                            child: input(business, hint: 'Your WABA ID')),
                        gap(),
                        FieldLabel('System-user access token',
                            child: input(token,
                                hint: 'Paste your access token',
                                obscure: true)),
                        gap(14)
                      ],
                      const Text(
                          '1. Set up a WhatsApp Business account in Meta Business Suite.\n2. Add and verify your business phone number.\n3. Generate a system-user token for the Cloud API.\n4. Connect here and sync your approved text templates.\n5. Configure delivery webhooks on your server.',
                          style:
                              TextStyle(fontSize: 11, color: muted, height: 2)),
                      gap(15),
                      TextButton.icon(
                          onPressed: () => launchUrl(
                              Uri.parse(
                                  'https://developers.facebook.com/docs/whatsapp/cloud-api/get-started'),
                              mode: LaunchMode.externalApplication),
                          icon: const Icon(Icons.open_in_new_rounded, size: 13),
                          label: const Text('Open Meta setup guide',
                              style: TextStyle(fontSize: 11))),
                    ]))));
    phone.dispose();
    business.dispose();
    token.dispose();
  }

  Future<void> notifications() async {
    await showDialog(
        context: context,
        builder: (ctx) => DialogFrame(
            width: 520,
            title: 'Workspace activity',
            subtitle: 'The little moments that keep your community growing.',
            child: c.visibleActivities.isEmpty
                ? const EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'All quiet for now',
                    description:
                        'Contact imports and campaign updates will appear here.')
                : Column(
                    children: c.visibleActivities
                        .take(12)
                        .map((a) => Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                          color: paleGreen,
                                          borderRadius:
                                              BorderRadius.circular(9)),
                                      child: Icon(activityIcon(a['kind']),
                                          size: 16, color: forest)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(a['title'],
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500)),
                                        gap(4),
                                        Text(a['description'],
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: muted,
                                                height: 1.5)),
                                        gap(4),
                                        Text(timeAgo(a['created_at']),
                                            style: const TextStyle(
                                                fontSize: 9, color: muted))
                                      ]))
                                ])))
                        .toList())));
  }

  Future<void> search() async {
    final query = TextEditingController();
    Timer? debounce;
    Map<String, dynamic>? result;
    bool busy = false;
    int version = 0;
    String? error;
    await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => DialogFrame(
                width: 600,
                title: 'Find your next connection',
                subtitle: 'Search contacts, groups, and campaigns.',
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                          controller: query,
                          autofocus: true,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                              hintText: 'Try “Amara”, “VIP”, or a phone number',
                              prefixIcon: Icon(Icons.search_rounded,
                                  size: 19, color: muted)),
                          onChanged: (q) {
                            debounce?.cancel();
                            final current = ++version;
                            if (q.trim().length < 2) {
                              set(() => result = null);
                              return;
                            }
                            set(() => busy = true);
                            debounce = Timer(const Duration(milliseconds: 250),
                                () async {
                              try {
                                final data =
                                    await c.api.get('/search', {'q': q});
                                if (ctx.mounted && version == current) {
                                  set(() {
                                    result = Map<String, dynamic>.from(data);
                                    busy = false;
                                    error = null;
                                  });
                                }
                              } catch (e) {
                                if (ctx.mounted && version == current) {
                                  set(() {
                                    busy = false;
                                    error = e.toString();
                                  });
                                }
                              }
                            });
                          }),
                      gap(18),
                      errorBox(error),
                      if (busy)
                        const Center(
                            child: Padding(
                                padding: EdgeInsets.all(25),
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)))
                      else if (result == null)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                                child: Text(
                                    'A person, a group, a campaign. Start with two characters.',
                                    style:
                                        TextStyle(fontSize: 11, color: muted))))
                      else if ((result!['contacts'] as List).isEmpty &&
                          (result!['groups'] as List).isEmpty &&
                          (result!['campaigns'] as List).isEmpty)
                        const EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No matches just yet',
                            description:
                                'Try another name, group, or international phone number.')
                      else ...[
                        if ((result!['contacts'] as List).isNotEmpty) ...[
                          const Text('CONTACTS',
                              style: TextStyle(
                                  fontSize: 9, color: muted, letterSpacing: 1)),
                          gap(8),
                          ...(result!['contacts'] as List).map((r) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: InitialAvatar(
                                  '${r['first_name']} ${r['last_name']}'),
                              title: Text(
                                  '${r['first_name']} ${r['last_name']}',
                                  style: const TextStyle(fontSize: 12)),
                              subtitle: Text(r['phone'],
                                  style: const TextStyle(
                                      fontSize: 10, color: muted)),
                              trailing: const Icon(Icons.arrow_forward_rounded,
                                  size: 15, color: muted),
                              onTap: () async {
                                Navigator.pop(ctx);
                                c.contactSearch =
                                    '${r['first_name']} ${r['last_name']}';
                                c.contactGroup = null;
                                c.contactStatus = '';
                                c.contactPage = 1;
                                c.navigate(AppPage.contacts);
                                await c.loadContacts();
                              })),
                          gap(14)
                        ],
                        if ((result!['groups'] as List).isNotEmpty) ...[
                          const Text('CONTACT GROUPS',
                              style: TextStyle(
                                  fontSize: 9, color: muted, letterSpacing: 1)),
                          gap(8),
                          ...(result!['groups'] as List).map((r) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                      color: hexColor(r['color']),
                                      borderRadius: BorderRadius.circular(9)),
                                  child: const Icon(Icons.workspaces_outline,
                                      size: 17, color: forest)),
                              title: Text(r['name'],
                                  style: const TextStyle(fontSize: 12)),
                              trailing: const Icon(Icons.arrow_forward_rounded,
                                  size: 15, color: muted),
                              onTap: () {
                                Navigator.pop(ctx);
                                c.openGroup(r['id']);
                              })),
                          gap(14)
                        ],
                        if ((result!['campaigns'] as List).isNotEmpty) ...[
                          const Text('CAMPAIGNS',
                              style: TextStyle(
                                  fontSize: 9, color: muted, letterSpacing: 1)),
                          gap(8),
                          ...(result!['campaigns'] as List).map((r) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: const Icon(Icons.send_outlined,
                                  size: 21, color: forest),
                              title: Text(r['name'],
                                  style: const TextStyle(fontSize: 12)),
                              trailing: StatusPill(r['status']),
                              onTap: () {
                                Navigator.pop(ctx);
                                campaignDetail(r['id']);
                              }))
                        ],
                      ],
                    ]))));
    debounce?.cancel();
    query.dispose();
  }

  Future<void> help() async => showDialog(
      context: context,
      builder: (ctx) => DialogFrame(
          width: 600,
          title: 'A little help, a lot of possibility.',
          subtitle: 'Your quick guide to building thoughtful connections.',
          child: Column(children: [
            const InfoBanner('Built for people, not spam',
                'Relay only targets contacts with recorded opt-in. Use clear messages, respect opt-outs, and follow local privacy rules.'),
            gap(18),
            ...[
              (
                'Can Relay extract existing WhatsApp group members?',
                'No. WhatsApp does not provide an API to read the member lists of existing personal-account groups. Upload a CSV member list you are authorized to use, select a destination group, confirm the opt-in source, and save the contacts together.'
              ),
              (
                'How do I save all contacts at once?',
                'Open Contacts or a contact group, then choose Save to phone. In the browser, download the .vcf file and open it on your phone to import the whole list. On Android/iOS, you can grant contacts permission and save directly. Duplicate phone numbers and fictional demo contacts are skipped on the device.'
              ),
              (
                'Can I send real marketing messages?',
                'Yes, after creating your own workspace, connecting an official WhatsApp Business Cloud API account, and syncing Meta-approved text templates. Contacts must have recorded opt-in. Demo workspaces cannot send real messages. Meta messaging fees and business policies apply.'
              ),
              (
                'What happens when someone opts out?',
                'Mark the contact Unsubscribed. They are excluded from every future campaign. In a live integration, a signed webhook with STOP, UNSUBSCRIBE, CANCEL, or OPT OUT automatically records their opt-out.'
              ),
              (
                'What is the CSV format?',
                'Use first_name, last_name, phone, email, and consent_status. Phone numbers must include the country code, such as +2348031234567. Set consent_status to opted_in only when you have permission, and confirm its source during import. Download the sample CSV from the import dialog.'
              ),
              (
                'Where is my data stored?',
                'Contacts, groups, campaigns, templates, preferences, and delivery history are persisted in the SQLite backend. Each private workspace is isolated. The shared demo has fictional seeded data; sign up for an empty workspace of your own.'
              ),
            ].map((e) => ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 14),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(e.$1,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                    children: [
                      Text(e.$2,
                          style: const TextStyle(
                              fontSize: 11, color: muted, height: 1.8))
                    ])),
            gap(14),
            const Text(
                'Made for meaningful marketing. A little personal goes a long way.',
                style: TextStyle(fontSize: 10, color: muted),
                textAlign: TextAlign.center),
          ])));
}

IconData activityIcon(dynamic kind) {
  if (kind == 'campaign') return Icons.done_all_rounded;
  if (kind == 'schedule') return Icons.schedule_rounded;
  if (kind == 'group') return Icons.workspaces_outline;
  if (kind == 'template') return Icons.description_outlined;
  if (kind == 'workspace') return Icons.auto_awesome_outlined;
  return Icons.person_add_alt_1_outlined;
}
