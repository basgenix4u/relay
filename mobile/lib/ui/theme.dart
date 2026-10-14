import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const ink = Color(0xFF202723);
const muted = Color(0xFF7E8581);
const line = Color(0xFFE8EBE7);
const background = Color(0xFFF7F8F6);
const lime = Color(0xFFCFEB94);
const forest = Color(0xFF3D6549);
const paleGreen = Color(0xFFF0F5E9);

String number(dynamic n) => NumberFormat('#,##0').format(n is num ? n : 0);
String compactNumber(dynamic n) =>
    NumberFormat.compact().format(n is num ? n : 0);
String shortDate(dynamic value, {bool year = false}) {
  if (value == null || '$value'.isEmpty) return '—';
  try {
    return DateFormat(year ? 'MMM d, yyyy' : 'MMM d')
        .format(DateTime.parse('$value').toLocal());
  } catch (_) {
    return '—';
  }
}

String timeAgo(dynamic value) {
  try {
    final diff = DateTime.now().difference(DateTime.parse('$value').toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  } catch (_) {
    return '';
  }
}

Color hexColor(dynamic value, [Color fallback = paleGreen]) {
  try {
    return Color(
        int.parse('$value'.replaceAll('#', ''), radix: 16) + 0xFF000000);
  } catch (_) {
    return fallback;
  }
}

ThemeData relayTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
          seedColor: forest,
          primary: ink,
          secondary: forest,
          surface: Colors.white),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 13, color: ink, height: 1.4),
        bodySmall: TextStyle(fontSize: 11, color: muted, height: 1.4),
        titleLarge: TextStyle(
            fontSize: 21,
            color: ink,
            fontWeight: FontWeight.w600,
            letterSpacing: -.6),
        titleMedium: TextStyle(
            fontSize: 15,
            color: ink,
            fontWeight: FontWeight.w600,
            letterSpacing: -.25),
        labelLarge:
            TextStyle(fontSize: 12, color: ink, fontWeight: FontWeight.w500),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        hintStyle: const TextStyle(color: Color(0xFF9BA09C), fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: forest, width: 1.5)),
      ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: forest,
              textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7)))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: ink,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
              textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: ink,
              backgroundColor: Colors.white,
              side: const BorderSide(color: line),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
              textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)))),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      checkboxTheme: CheckboxThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          side: const BorderSide(color: Color(0xFFD7DDD5)),
          fillColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? forest : Colors.white),
          checkColor: WidgetStateProperty.all(Colors.white),
          visualDensity: VisualDensity.compact),
      tooltipTheme: TooltipThemeData(
          decoration:
              BoxDecoration(color: ink, borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(color: Colors.white, fontSize: 11)),
      popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 6,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: line)),
          textStyle:
              const TextStyle(fontFamily: 'Inter', fontSize: 12, color: ink)),
      dialogTheme: DialogTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: forest, linearTrackColor: paleGreen),
    );

class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color color;
  final double radius;
  const Surface(
      {super.key,
      required this.child,
      this.padding,
      this.color = Colors.white,
      this.radius = 12});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: color,
            border: Border.all(color: line),
            borderRadius: BorderRadius.circular(radius)),
        padding: padding,
        child: child,
      );
}

class ActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary, accent, busy, small;
  const ActionButton(this.label,
      {super.key,
      this.icon,
      this.onPressed,
      this.primary = false,
      this.accent = false,
      this.busy = false,
      this.small = false});
  @override
  Widget build(BuildContext context) {
    final content = Row(mainAxisSize: MainAxisSize.min, children: [
      if (busy) ...[
        SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: primary ? Colors.white : forest)),
        const SizedBox(width: 8)
      ] else if (icon != null) ...[
        Icon(icon, size: small ? 14 : 16),
        const SizedBox(width: 8)
      ],
      Text(label, style: TextStyle(fontSize: small ? 11 : 12)),
    ]);
    final padding = EdgeInsets.symmetric(
        horizontal: small ? 12 : 16, vertical: small ? 12 : 17);
    if (primary || accent) {
      return ElevatedButton(
          onPressed: busy ? null : onPressed,
          style: ElevatedButton.styleFrom(
              backgroundColor: accent ? lime : ink,
              foregroundColor: accent ? ink : Colors.white,
              padding: padding,
              minimumSize: Size(0, small ? 34 : 40)),
          child: content);
    }
    return OutlinedButton(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
            padding: padding, minimumSize: Size(0, small ? 34 : 40)),
        child: content);
  }
}

class StatusPill extends StatelessWidget {
  final String status;
  final bool dot;
  const StatusPill(this.status, {super.key, this.dot = true});
  @override
  Widget build(BuildContext context) {
    String text = status;
    Color color = muted, bg = const Color(0xFFF1F3F1);
    if ([
      'Completed',
      'Approved',
      'Demo approved',
      'opted_in',
      'delivered',
      'read'
    ].contains(status)) {
      color = const Color(0xFF4E7657);
      bg = const Color(0xFFEDF5EA);
    }
    if (['Scheduled', 'sent'].contains(status)) {
      color = const Color(0xFF667DB0);
      bg = const Color(0xFFEDF1FA);
    }
    if (['Sending', 'Pending', 'pending', 'queued'].contains(status)) {
      color = const Color(0xFFAF8A3F);
      bg = const Color(0xFFFAF4E8);
    }
    if (['Failed', 'Rejected', 'unsubscribed', 'failed'].contains(status)) {
      color = const Color(0xFFB16B67);
      bg = const Color(0xFFFAEEEE);
    }
    if (status == 'opted_in') text = 'Opted in';
    if (status == 'pending') text = 'Pending opt-in';
    if (status == 'unsubscribed') text = 'Unsubscribed';
    if (['read', 'delivered', 'sent', 'failed', 'queued'].contains(status)) {
      text = status[0].toUpperCase() + status.substring(1);
    }
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot) ...[
            Container(
                width: 4.5,
                height: 4.5,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 5)
          ],
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w500)),
        ]));
  }
}

class InitialAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const InitialAvatar(this.name, {super.key, this.size = 34, this.color});
  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0])
        .join()
        .toUpperCase();
    const colors = [
      Color(0xFFE8EDDF),
      Color(0xFFE9E3EF),
      Color(0xFFF2E5DA),
      Color(0xFFDFEAEB),
      Color(0xFFE5E9F2)
    ];
    return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: color ??
                colors[name.codeUnits.fold(0, (a, b) => a + b) % colors.length],
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5)),
        child: Text(initials,
            style: TextStyle(
                fontSize: size * .31,
                fontWeight: FontWeight.w600,
                color: ink.withOpacity(.65))));
  }
}

class Brand extends StatelessWidget {
  final bool compact;
  const Brand({super.key, this.compact = false});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: compact ? 28 : 33,
            height: compact ? 28 : 33,
            decoration: BoxDecoration(
                color: ink, borderRadius: BorderRadius.circular(9)),
            child: Center(
                child: Transform.rotate(
                    angle: -.14,
                    child: Icon(Icons.forum_rounded,
                        size: compact ? 17 : 20, color: lime)))),
        const SizedBox(width: 10),
        Text('relay',
            style: TextStyle(
                fontSize: compact ? 22 : 27,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.3,
                color: ink)),
        if (!compact)
          const Padding(
              padding: EdgeInsets.only(left: 3, top: 11),
              child: Text('•', style: TextStyle(color: forest, fontSize: 17))),
      ]);
}

class PageHeading extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> actions;
  final Widget? eyebrow;
  const PageHeading(this.title, this.subtitle,
      {super.key, this.actions = const [], this.eyebrow});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, c) {
        final text =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (eyebrow != null) ...[eyebrow!, const SizedBox(height: 8)],
          Text(title,
              style: TextStyle(
                  fontSize: c.maxWidth < 600 ? 26 : 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.05,
                  height: 1.3)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(color: muted, fontSize: 12, height: 1.5)),
        ]);
        if (c.maxWidth < 780) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 17),
                  Wrap(spacing: 8, runSpacing: 8, children: actions)
                ]
              ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: text),
          Wrap(spacing: 9, children: actions)
        ]);
      });
}

class SearchInput extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  const SearchInput(
      {super.key, this.hint = 'Search...', this.onChanged, this.controller});
  @override
  Widget build(BuildContext context) => TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: muted),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13)));
}

class TabPill extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  final dynamic count;
  const TabPill(this.text,
      {super.key, required this.selected, required this.onTap, this.count});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
              color: selected ? paleGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                  color:
                      selected ? const Color(0xFFDDE8D4) : Colors.transparent)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(text,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? forest : muted)),
            if (count != null) ...[
              const SizedBox(width: 7),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                      color: selected ? Colors.white : const Color(0xFFEDF0EC),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(number(count),
                      style: TextStyle(
                          fontSize: 9, color: selected ? forest : muted)))
            ]
          ])));
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, description;
  final Widget? action;
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.description,
      this.action});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      child: Column(children: [
        Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
                color: paleGreen, borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: forest, size: 28)),
        const SizedBox(height: 18),
        Text(title,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -.4)),
        const SizedBox(height: 7),
        ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330),
            child: Text(description,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: muted, fontSize: 12, height: 1.6))),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ]));
}

class InfoBanner extends StatelessWidget {
  final String title, description;
  final IconData icon;
  final Color color;
  final Widget? action;
  const InfoBanner(this.title, this.description,
      {super.key,
      this.icon = Icons.verified_user_outlined,
      this.color = paleGreen,
      this.action});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: line)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 22, color: forest),
        const SizedBox(width: 13),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(description,
              style: const TextStyle(color: muted, fontSize: 11, height: 1.6))
        ])),
        if (action != null) ...[const SizedBox(width: 10), action!]
      ]));
}

class FieldLabel extends StatelessWidget {
  final String label;
  final Widget child;
  final String? help;
  const FieldLabel(this.label, {super.key, required this.child, this.help});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 7),
        child,
        if (help != null) ...[
          const SizedBox(height: 5),
          Text(help!,
              style: const TextStyle(fontSize: 10, color: muted, height: 1.5))
        ]
      ]);
}

Widget moreMenu(Map<String, IconData> options, ValueChanged<String> onSelect) =>
    PopupMenuButton<String>(
      tooltip: 'More actions',
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_horiz_rounded, size: 20, color: muted),
      onSelected: onSelect,
      itemBuilder: (_) => options.entries
          .map((e) => PopupMenuItem<String>(
              value: e.key,
              height: 40,
              child: Row(children: [
                Icon(e.value,
                    size: 16,
                    color: e.key == 'Delete' ? const Color(0xFFB16B67) : muted),
                const SizedBox(width: 10),
                Text(e.key,
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            e.key == 'Delete' ? const Color(0xFFB16B67) : ink))
              ])))
          .toList(),
    );
