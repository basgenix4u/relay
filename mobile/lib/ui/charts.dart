import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'theme.dart';

class WelcomeBanner extends StatelessWidget {
  final VoidCallback onCreate;
  const WelcomeBanner({super.key, required this.onCreate});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (ctx, c) => Container(
            width: double.infinity,
            height: c.maxWidth > 660
                ? 125
                : c.maxWidth < 340
                    ? 180
                    : 155,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: const Color(0xFFEDF3E4),
                border: Border.all(color: const Color(0xFFE2EADA)),
                borderRadius: BorderRadius.circular(12)),
            child: Stack(children: [
              if (c.maxWidth > 660)
                Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 350,
                    child: CustomPaint(painter: _BannerLines())),
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('LESS BROADCAST. MORE CONNECTION.',
                            style: TextStyle(
                                fontSize: 8,
                                letterSpacing: 1.55,
                                fontWeight: FontWeight.w600,
                                color: forest)),
                        const SizedBox(height: 8),
                        const Text('Big reach. Personal touch.',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -.8,
                                height: 1.1)),
                        const SizedBox(height: 7),
                        const Text(
                            'Bring your people together, one thoughtful message at a time.',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF78816F))),
                        const SizedBox(height: 8),
                        InkWell(
                            onTap: onCreate,
                            child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Create your next campaign',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: forest,
                                          fontWeight: FontWeight.w600)),
                                  SizedBox(width: 7),
                                  Icon(Icons.arrow_forward_rounded,
                                      size: 13, color: forest)
                                ])),
                      ])),
              if (c.maxWidth > 760)
                Positioned(
                    right: 37,
                    top: 21,
                    child: Transform.rotate(
                        angle: -.075,
                        child: Container(
                            width: 213,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 10),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                      color: const Color(0xFF3A482E)
                                          .withOpacity(.05),
                                      blurRadius: 16,
                                      offset: const Offset(0, 5))
                                ]),
                            child: Row(children: [
                              Container(
                                  width: 27,
                                  height: 27,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFFE7F3DC),
                                      shape: BoxShape.circle),
                                  child: const Icon(
                                      Icons.favorite_border_rounded,
                                      size: 14,
                                      color: forest)),
                              const SizedBox(width: 10),
                              const Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text('A little something for you 💚',
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600)),
                                    SizedBox(height: 3),
                                    Text('Made personal. Sent with care.',
                                        style: TextStyle(
                                            fontSize: 8, color: muted))
                                  ]))
                            ])))),
              if (c.maxWidth > 760)
                Positioned(
                    right: 23,
                    bottom: 14,
                    child: Transform.rotate(
                        angle: .055,
                        child: Container(
                            width: 184,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                                color: const Color(0xFFD8EBB5),
                                borderRadius: BorderRadius.circular(9)),
                            child: const Row(children: [
                              Icon(Icons.done_all_rounded,
                                  size: 15, color: forest),
                              SizedBox(width: 8),
                              Text('The right message. Every time.',
                                  style: TextStyle(
                                      fontSize: 8,
                                      color: forest,
                                      fontWeight: FontWeight.w500))
                            ])))),
              if (c.maxWidth > 760)
                const Positioned(
                    right: 280,
                    top: 49,
                    child: Icon(Icons.auto_awesome_rounded,
                        size: 23, color: Color(0xFFB1C792))),
            ]),
          ));
}

class _BannerLines extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDBE6CD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(size.width - 110, 75), 85, paint);
    canvas.drawCircle(Offset(size.width - 110, 75), 112, paint);
    canvas.drawCircle(Offset(size.width - 110, 75), 138, paint);
    canvas.drawCircle(
        const Offset(52, 24), 3, Paint()..color = const Color(0xFFBCD59A));
    canvas.drawCircle(Offset(size.width - 27, 18), 4,
        Paint()..color = const Color(0xFFC0D79F));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MetricGrid extends StatelessWidget {
  final Map<String, dynamic> data;
  const MetricGrid(this.data, {super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, c) {
        final cols = c.maxWidth < 700 ? 2 : 4;
        final width = (c.maxWidth - (cols - 1) * 16) / cols;
        final metrics = [
          [
            'Total contacts',
            number(data['total_contacts']),
            '${number(data['new_contacts'])} new in this period',
            Icons.people_outline_rounded
          ],
          [
            'Messages sent',
            number(data['messages_sent']),
            '${number(data['delivered'])} successfully delivered',
            Icons.send_outlined
          ],
          [
            'Delivery rate',
            '${data['delivery_rate'] ?? 0}%',
            '${data['read_rate'] ?? 0}% read rate',
            Icons.task_alt_rounded
          ],
          [
            'Active campaigns',
            number(data['active_campaigns']),
            '${number(data['total_campaigns'])} campaigns in your workspace',
            Icons.campaign_outlined
          ],
        ];
        return Wrap(
            spacing: 16,
            runSpacing: 14,
            children: metrics.asMap().entries.map((entry) {
              final m = entry.value;
              return SizedBox(
                  width: width,
                  child: Surface(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 15),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text('${m[0]}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: muted,
                                          fontWeight: FontWeight.w500))),
                              Icon(m[3] as IconData,
                                  size: 17, color: const Color(0xFF87917F))
                            ]),
                            const SizedBox(height: 10),
                            Text('${m[1]}',
                                style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -1.05,
                                    height: 1.05)),
                            const SizedBox(height: 10),
                            Row(children: [
                              Icon(
                                  entry.key == 3
                                      ? Icons.circle
                                      : Icons.north_east_rounded,
                                  size: entry.key == 3 ? 5 : 10,
                                  color: forest),
                              const SizedBox(width: 5),
                              Expanded(
                                  child: Text('${m[2]}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 9,
                                          color: Color(0xFF869080))))
                            ]),
                          ])));
            }).toList());
      });
}

class PerformanceChart extends StatefulWidget {
  final Map<String, dynamic> data;
  final double height;
  final VoidCallback? onExport;
  const PerformanceChart(this.data,
      {super.key, this.height = 284, this.onExport});
  @override
  State<PerformanceChart> createState() => _PerformanceChartState();
}

class _PerformanceChartState extends State<PerformanceChart> {
  final Set<String> enabled = {'sent', 'delivered', 'read'};
  int? hover;
  @override
  Widget build(BuildContext context) {
    final points = (widget.data['chart'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return Surface(
        child: SizedBox(
            height: widget.height,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Expanded(
                            child: Text('Message performance',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -.25))),
                        if (widget.onExport != null)
                          PopupMenuButton<String>(
                              tooltip: 'Chart options',
                              onSelected: (_) => widget.onExport!(),
                              itemBuilder: (_) => [
                                    const PopupMenuItem(
                                        value: 'export',
                                        child: Text('Export campaign report',
                                            style: TextStyle(fontSize: 12)))
                                  ],
                              child: const Icon(Icons.more_horiz_rounded,
                                  size: 18, color: muted))
                      ]),
                      const SizedBox(height: 5),
                      const Text('A closer look at how your messages connect.',
                          style: TextStyle(fontSize: 10, color: muted)),
                      const SizedBox(height: 14),
                      Row(children: [
                        ...[
                          ('sent', 'Sent', const Color(0xFFC1CCC0)),
                          ('delivered', 'Delivered', const Color(0xFF9CC478)),
                          ('read', 'Read', forest)
                        ].map((e) => Padding(
                            padding: const EdgeInsets.only(right: 18),
                            child: InkWell(
                                onTap: () => setState(() =>
                                    enabled.contains(e.$1)
                                        ? enabled.remove(e.$1)
                                        : enabled.add(e.$1)),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                              color: enabled.contains(e.$1)
                                                  ? e.$3
                                                  : line,
                                              shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      Text(e.$2,
                                          style: TextStyle(
                                              fontSize: 9,
                                              color: enabled.contains(e.$1)
                                                  ? muted
                                                  : const Color(0xFFC6CBC4)))
                                    ])))),
                        const Spacer(),
                        if (hover != null && hover! < points.length)
                          Text(
                              '${shortDate(points[hover!]['date'])} · ${number(points[hover!]['sent'])} sent',
                              style:
                                  const TextStyle(fontSize: 9, color: forest)),
                      ]),
                      const SizedBox(height: 14),
                      Expanded(
                          child: points.isEmpty ||
                                  points.every((p) => (p['sent'] ?? 0) == 0)
                              ? const Center(
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                      Icon(Icons.insights_outlined,
                                          color: Color(0xFFBBC8B0), size: 30),
                                      SizedBox(height: 9),
                                      Text(
                                          'Your first campaign starts the story.',
                                          style: TextStyle(
                                              fontSize: 11, color: muted))
                                    ]))
                              : LayoutBuilder(
                                  builder: (_, c) => MouseRegion(
                                      onHover: (e) => setState(() => hover =
                                          (((e.localPosition.dx - 37) / (c.maxWidth - 52)) *
                                                  (points.length - 1))
                                              .round()
                                              .clamp(0, points.length - 1)),
                                      onExit: (_) =>
                                          setState(() => hover = null),
                                      child: CustomPaint(
                                          size: Size(c.maxWidth, c.maxHeight),
                                          painter: _LineChartPainter(
                                              points, enabled, hover))))),
                    ]))));
  }
}

class _LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> points;
  final Set<String> enabled;
  final int? hover;
  _LineChartPainter(this.points, Set<String> value, this.hover)
      : enabled = Set.of(value);
  void label(Canvas canvas, String text, Offset at,
      {Color color = muted, bool center = false}) {
    final p = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(fontFamily: 'Inter', fontSize: 8, color: color)),
        textDirection: TextDirection.ltr)
      ..layout();
    p.paint(canvas, at - (center ? Offset(p.width / 2, 0) : Offset.zero));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 38.0, top = 6.0;
    final bottom = size.height - 22,
        right = size.width - 8,
        width = right - left,
        height = bottom - top;
    if (width <= 0 || height <= 0 || points.length < 2) return;
    final maxValue =
        points.fold<num>(0, (a, b) => math.max(a, b['sent'] as num));
    final maxY = math.max(500.0, (maxValue / 500).ceil() * 500.0);
    final grid = Paint()
      ..color = const Color(0xFFECEFE9)
      ..strokeWidth = 1;
    for (int i = 0; i < 5; i++) {
      final y = top + height * i / 4;
      label(canvas, compactNumber(maxY * (1 - i / 4)), Offset(0, y - 5));
      for (double x = left; x < right; x += 7) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 3, right), y), grid);
      }
    }
    for (int i = 0; i < points.length; i++) {
      if (points.length > 14 && i % 5 != 0 && i != points.length - 1) continue;
      if (points.length > 7 &&
          points.length <= 14 &&
          i % 2 != 0 &&
          i != points.length - 1) continue;
      final date = DateTime.tryParse('${points[i]['date']}');
      label(
          canvas,
          date == null
              ? ''
              : DateFormat(points.length <= 7 ? 'EEE' : 'MMM d').format(date),
          Offset(left + width * i / (points.length - 1), bottom + 10),
          center: true);
    }
    final colors = {
      'sent': const Color(0xFFBBC8B5),
      'delivered': const Color(0xFF9AC473),
      'read': forest
    };
    for (final key in ['sent', 'delivered', 'read']) {
      if (!enabled.contains(key)) continue;
      final offsets = points
          .asMap()
          .entries
          .map((e) => Offset(left + width * e.key / (points.length - 1),
              bottom - ((e.value[key] as num) / maxY) * height))
          .toList();
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (int i = 0; i < offsets.length - 1; i++) {
        final before = offsets[math.max(0, i - 1)],
            a = offsets[i],
            b = offsets[i + 1],
            after = offsets[math.min(i + 2, offsets.length - 1)];
        path.cubicTo(
            a.dx + (b.dx - before.dx) / 6,
            (a.dy + (b.dy - before.dy) / 6).clamp(top, bottom),
            b.dx - (after.dx - a.dx) / 6,
            (b.dy - (after.dy - a.dy) / 6).clamp(top, bottom),
            b.dx,
            b.dy);
      }
      if (key == 'read') {
        final area = Path.from(path)
          ..lineTo(right, bottom)
          ..lineTo(left, bottom)
          ..close();
        canvas.drawPath(
            area,
            Paint()
              ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFD8E9C7).withOpacity(.45),
                    const Color(0xFFD8E9C7).withOpacity(.03)
                  ]).createShader(Rect.fromLTWH(left, top, width, height)));
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = colors[key]!
            ..style = PaintingStyle.stroke
            ..strokeWidth = key == 'read' ? 2.2 : 1.6
            ..strokeCap = StrokeCap.round);
      if (hover != null && hover! < offsets.length) {
        final point = offsets[hover!];
        canvas.drawLine(
            Offset(point.dx, top),
            Offset(point.dx, bottom),
            Paint()
              ..color = line
              ..strokeWidth = 1);
        canvas.drawCircle(point, 4, Paint()..color = Colors.white);
        canvas.drawCircle(point, 2.5, Paint()..color = colors[key]!);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.points != points ||
      old.hover != hover ||
      !setEqualsLocal(old.enabled, enabled);
  bool setEqualsLocal(Set a, Set b) => a.length == b.length && a.containsAll(b);
}

class AudienceChart extends StatelessWidget {
  final Map<String, dynamic> data;
  const AudienceChart(this.data, {super.key});
  @override
  Widget build(BuildContext context) {
    final segments = (data['segments'] as List? ?? [])
        .map((s) => Map<String, dynamic>.from(s))
        .toList();
    const colors = {
      'opted_in': forest,
      'pending': Color(0xFFD5E6B9),
      'unsubscribed': Color(0xFFE2E6DE)
    };
    final total = data['total_contacts'] ?? 0;
    return Surface(
        padding: const EdgeInsets.all(23),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Your audience',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 5),
          const Text('Healthy lists make stronger connections.',
              style: TextStyle(fontSize: 10, color: muted)),
          const SizedBox(height: 25),
          Center(
              child: SizedBox(
                  width: 170,
                  height: 170,
                  child: Stack(alignment: Alignment.center, children: [
                    CustomPaint(
                        size: const Size(170, 170),
                        painter: _DonutPainter(segments, total, colors)),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(number(total),
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1)),
                      const SizedBox(height: 4),
                      const Text('total contacts',
                          style: TextStyle(fontSize: 10, color: muted))
                    ])
                  ]))),
          const SizedBox(height: 26),
          ...segments.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: colors[s['status']], shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        s['status'] == 'opted_in'
                            ? 'Opted in'
                            : s['status'] == 'pending'
                                ? 'Pending opt-in'
                                : 'Unsubscribed',
                        style: const TextStyle(fontSize: 11, color: muted))),
                Text(number(s['count']),
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500))
              ]))),
        ]));
  }
}

class _DonutPainter extends CustomPainter {
  final List<Map<String, dynamic>> segments;
  final int total;
  final Map<String, Color> colors;
  _DonutPainter(this.segments, this.total, this.colors);
  @override
  void paint(Canvas c, Size s) {
    final rect = Rect.fromLTWH(11, 11, s.width - 22, s.height - 22);
    if (total == 0) {
      c.drawArc(
          rect,
          0,
          math.pi * 2,
          false,
          Paint()
            ..color = line
            ..style = PaintingStyle.stroke
            ..strokeWidth = 15);
      return;
    }
    double angle = -math.pi / 2;
    for (final seg in segments) {
      final sweep = (seg['count'] as int) / total * 2 * math.pi;
      c.drawArc(
          rect,
          angle + .025,
          math.max(0, sweep - .05),
          false,
          Paint()
            ..color = colors[seg['status']] ?? muted
            ..style = PaintingStyle.stroke
            ..strokeWidth = 15
            ..strokeCap = StrokeCap.round);
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
