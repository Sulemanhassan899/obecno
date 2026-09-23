import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/features/clock/location_flags/domain/location_flag_evaluator.dart';

enum LocationFlagListFilter {
  all,
  missing,
  inOffice,
  outside,
  upcoming,
}

enum LocationFlagListSort { latest, oldest }

class LocationFlagCheckEntry {
  const LocationFlagCheckEntry({
    required this.at,
    required this.flag,
    required this.pending,
  });

  final DateTime at;
  final bool? flag;
  final bool pending;
}

class LocationFlagChecksCard extends StatefulWidget {
  const LocationFlagChecksCard({
    super.key,
    required this.entries,
    required this.statusLabel,
    required this.statusColor,
  });

  final List<LocationFlagCheckEntry> entries;
  final String statusLabel;
  final Color statusColor;

  @override
  State<LocationFlagChecksCard> createState() => _LocationFlagChecksCardState();
}

class _LocationFlagChecksCardState extends State<LocationFlagChecksCard> {
  LocationFlagListFilter _filter = LocationFlagListFilter.all;
  LocationFlagListSort _sort = LocationFlagListSort.latest;

  List<LocationFlagCheckEntry> get _visible {
    var list = widget.entries.where((entry) {
      switch (_filter) {
        case LocationFlagListFilter.all:
          return true;
        case LocationFlagListFilter.missing:
          return !entry.pending && entry.flag == null;
        case LocationFlagListFilter.inOffice:
          return entry.flag == true;
        case LocationFlagListFilter.outside:
          return entry.flag == false;
        case LocationFlagListFilter.upcoming:
          return entry.pending;
      }
    }).toList();

    list.sort((a, b) {
      final cmp = a.at.compareTo(b.at);
      return _sort == LocationFlagListSort.latest ? -cmp : cmp;
    });
    return list;
  }

  /// Groups filtered entries into hour blocks (e.g. 10:00–11:00).
  List<_HourBlock> get _hourBlocks {
    final rows = _visible;
    if (rows.isEmpty) return const [];

    final byHour = <DateTime, List<LocationFlagCheckEntry>>{};
    for (final entry in rows) {
      final hour = DateTime(
        entry.at.year,
        entry.at.month,
        entry.at.day,
        entry.at.hour,
      );
      byHour.putIfAbsent(hour, () => []).add(entry);
    }

    final hours = byHour.keys.toList()
      ..sort((a, b) {
        final cmp = a.compareTo(b);
        return _sort == LocationFlagListSort.latest ? -cmp : cmp;
      });

    return [
      for (final hour in hours)
        _HourBlock(
          hourStart: hour,
          hourEnd: hour.add(const Duration(hours: 1)),
          entries: () {
            final list = List<LocationFlagCheckEntry>.from(byHour[hour]!);
            list.sort((a, b) {
              final cmp = a.at.compareTo(b.at);
              return _sort == LocationFlagListSort.latest ? -cmp : cmp;
            });
            return list;
          }(),
        ),
    ];
  }

  String get _filterLabel {
    switch (_filter) {
      case LocationFlagListFilter.all:
        return 'All';
      case LocationFlagListFilter.missing:
        return 'Missing';
      case LocationFlagListFilter.inOffice:
        return 'In office';
      case LocationFlagListFilter.outside:
        return 'Outside';
      case LocationFlagListFilter.upcoming:
        return 'Upcoming';
    }
  }

  ({String label, Color color}) _statusForHour(
    List<LocationFlagCheckEntry> entries,
  ) {
    final settled = entries.where((e) => !e.pending).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    if (settled.isEmpty) {
      return (label: 'Upcoming', color: kGreyColor);
    }
    final latest = settled.last;
    if (latest.flag == true) {
      return (label: 'Inside office premises', color: kPrimaryColor);
    }
    if (latest.flag == false) {
      return (label: 'Out of office location', color: kredColor);
    }
    return (label: 'Missing', color: kOrangeColor);
  }

  @override
  Widget build(BuildContext context) {
    final blocks = _hourBlocks;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText.h6(
                  'Locations Flags Checks',
                  weight: FontWeight.w600,
                  align: TextAlign.left,
                ),
              ),
              PopupMenuButton<_MenuAction>(
                tooltip: 'Sort & filter',
                onSelected: _onMenuSelected,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    enabled: false,
                    child: Text(
                      'Filter',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: kGreyColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  _filterItem(LocationFlagListFilter.all, 'All'),
                  _filterItem(LocationFlagListFilter.missing, 'Missing'),
                  _filterItem(LocationFlagListFilter.inOffice, 'In office'),
                  _filterItem(LocationFlagListFilter.outside, 'Outside'),
                  _filterItem(LocationFlagListFilter.upcoming, 'Upcoming'),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    enabled: false,
                    child: Text(
                      'Sort',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: kGreyColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  _sortItem(LocationFlagListSort.latest, 'Latest'),
                  _sortItem(LocationFlagListSort.oldest, 'Oldest'),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: kGreyColor6,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort, size: 16, color: kBlack),
                      const SizedBox(width: 4),
                      Text(
                        _filterLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kBlack,
                        ),
                      ),
                      const Icon(Icons.expand_more, size: 16, color: kBlack),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          AppText.p2(
            _sort == LocationFlagListSort.latest
                ? 'Sorted by latest'
                : 'Sorted by oldest',
            color: kGreyColor,
            align: TextAlign.left,
          ),
          const SizedBox(height: 16),
          if (blocks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppText.p2(
                'No flags for this filter.',
                color: kGreyColor,
                align: TextAlign.left,
              ),
            )
          else
            for (var b = 0; b < blocks.length; b++) ...[
              _hourHeader(blocks[b]),
              const SizedBox(height: 12),
              for (var i = 0; i < blocks[b].entries.length; i++)
                _flagRow(
                  blocks[b].entries[i],
                  showLine: i < blocks[b].entries.length - 1,
                ),
              const Divider(height: 24),
              Builder(
                builder: (context) {
                  final status = _statusForHour(blocks[b].entries);
                  return Row(
                    children: [
                      AppText.p2('Flag status :', color: kGreyColor),
                      const Spacer(),
                      AppText.p2(
                        status.label,
                        color: status.color,
                        weight: FontWeight.w600,
                      ),
                    ],
                  );
                },
              ),
              if (b < blocks.length - 1) const SizedBox(height: 20),
            ],
        ],
      ),
    );
  }

  Widget _hourHeader(_HourBlock block) {
    return Row(
      children: [
        AppText.p2(
          '${LocationFlagEvaluator.formatClock(block.hourStart)} – ${LocationFlagEvaluator.formatClock(block.hourEnd)}',
          color: kGreyColor,
          weight: FontWeight.w600,
          align: TextAlign.left,
        ),
        const Spacer(),
        Builder(
          builder: (context) {
            final status = _statusForHour(block.entries);
            return AppText.p2(
              status.label,
              color: status.color,
              weight: FontWeight.w600,
              align: TextAlign.right,
            );
          },
        ),
      ],
    );
  }

  void _onMenuSelected(_MenuAction action) {
    setState(() {
      if (action.filter != null) _filter = action.filter!;
      if (action.sort != null) _sort = action.sort!;
    });
  }

  PopupMenuItem<_MenuAction> _filterItem(
    LocationFlagListFilter value,
    String label,
  ) {
    return PopupMenuItem(
      value: _MenuAction(filter: value),
      child: Row(
        children: [
          Icon(
            _filter == value ? Icons.check : Icons.circle_outlined,
            size: 16,
            color: _filter == value ? kPrimaryColor : kGreyColor,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  PopupMenuItem<_MenuAction> _sortItem(
    LocationFlagListSort value,
    String label,
  ) {
    return PopupMenuItem(
      value: _MenuAction(sort: value),
      child: Row(
        children: [
          Icon(
            _sort == value ? Icons.check : Icons.circle_outlined,
            size: 16,
            color: _sort == value ? kPrimaryColor : kGreyColor,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _flagRow(LocationFlagCheckEntry entry, {required bool showLine}) {
    final pending = entry.pending;
    final flag = entry.flag;
    final color = pending
        ? kGreyColor50
        : flag == true
        ? kPrimaryColor
        : flag == false
        ? kredColor
        : kOrangeColor;
    final label = pending
        ? 'Upcoming'
        : flag == true
        ? 'Inside office premises'
        : flag == false
        ? 'Outside office premises'
        : 'Missing';
    final labelColor = pending
        ? kGreyColor
        : flag == true
        ? kPrimaryColor
        : flag == false
        ? kredColor
        : kOrangeColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              if (showLine)
                Container(
                  width: 2,
                  height: 28,
                  margin: const EdgeInsets.only(top: 2),
                  color: kGreyColor6,
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.p1(
                  LocationFlagEvaluator.formatClock(entry.at),
                  weight: FontWeight.w600,
                  align: TextAlign.left,
                ),
                AppText.p2(
                  'Flag time check · ${pending ? '—' : flag == true ? 'TRUE' : flag == false ? 'FALSE' : 'MISSING'}',
                  color: kGreyColor,
                  align: TextAlign.left,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: pending
                  ? kGreyColor6
                  : flag == true
                  ? const Color(0x1A0ED574)
                  : flag == false
                  ? kRed50
                  : const Color(0x1AFF7F0E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: AppText.h7(label, color: labelColor),
          ),
        ],
      ),
    );
  }
}

class _MenuAction {
  const _MenuAction({this.filter, this.sort});

  final LocationFlagListFilter? filter;
  final LocationFlagListSort? sort;
}

class _HourBlock {
  const _HourBlock({
    required this.hourStart,
    required this.hourEnd,
    required this.entries,
  });

  final DateTime hourStart;
  final DateTime hourEnd;
  final List<LocationFlagCheckEntry> entries;
}
