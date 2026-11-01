import 'package:flutter/material.dart';
import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_format.dart';
import 'package:obecno/main.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';

/// Stacked leave timeline cards — one card per event, never overwritten.
class LeaveTimelineCards extends StatelessWidget {
  const LeaveTimelineCards({
    super.key,
    required this.events,
    this.onTapRequested,
    this.onAddReason,
    this.fallbackActorName,
  });

  final List<LeaveTimelineEvent> events;
  final ValueChanged<LeaveTimelineEvent>? onTapRequested;

  /// Manager-only: show "Add Reason" on rejected timeline cards.
  final VoidCallback? onAddReason;

  /// Used when the leave API omits reviewer name (e.g. profile `reports_to`).
  final String? fallbackActorName;

  static String? profileManagerName() {
    final fromProfile = bindings.profileProvider.profile?.reportsToName?.trim();
    if (fromProfile != null &&
        fromProfile.isNotEmpty &&
        fromProfile.toLowerCase() != 'manager') {
      return fromProfile;
    }
    final fields = bindings.profileProvider.profile?.profileFields ?? const [];
    for (final field in fields) {
      final label = field.label.toLowerCase().replaceAll('_', ' ');
      if (!label.contains('reports') &&
          !label.contains('manager') &&
          !label.contains('approver')) {
        continue;
      }
      final value = field.value.trim();
      if (value.isEmpty ||
          value == '—' ||
          value.toLowerCase() == 'manager' ||
          int.tryParse(value) != null) {
        continue;
      }
      return value;
    }
    return null;
  }

  String? _actorFor(LeaveTimelineEvent event) {
    final current = event.actorName?.trim();
    if (current != null &&
        current.isNotEmpty &&
        current.toLowerCase() != 'manager') {
      return current;
    }
    final fallback = (fallbackActorName ?? profileManagerName())?.trim();
    if (fallback != null &&
        fallback.isNotEmpty &&
        fallback.toLowerCase() != 'manager') {
      return fallback;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (var i = 0; i < events.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _LeaveTimelineCard(
            event: events[i],
            actorName: _actorFor(events[i]),
            onTap:
                events[i].kind == LeaveTimelineKind.requested &&
                    onTapRequested != null
                ? () => onTapRequested!(events[i])
                : null,
            onAddReason:
                events[i].kind == LeaveTimelineKind.rejected ? onAddReason : null,
          ),
        ],
      ],
    );
  }
}

class _LeaveTimelineCard extends StatelessWidget {
  const _LeaveTimelineCard({
    required this.event,
    this.actorName,
    this.onTap,
    this.onAddReason,
  });

  final LeaveTimelineEvent event;
  final String? actorName;
  final VoidCallback? onTap;
  final VoidCallback? onAddReason;

  static const _iconSlot = 16.0;
  static const _iconGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(event.kind, actorName);
    final primary = style.subtitle;
    final reason = event.kind == LeaveTimelineKind.rejected
        ? event.reason?.trim()
        : null;
    final hasReason = reason != null && reason.isNotEmpty;

    final child = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText.p1(
            style.title,
            color: style.color,
            weight: FontWeight.w500,
            align: TextAlign.left,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _iconSlot,
                height: _iconSlot,
                child: Center(
                  child: style.iconPath != null
                      ? CommonImageView(
                          imagePath: style.iconPath!,
                          height: 10,
                        )
                      : Icon(style.fallbackIcon, size: 16, color: kGreyColor),
                ),
              ),
              const SizedBox(width: _iconGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (primary != null && primary.isNotEmpty) ...[
                      AppText.p2(
                        primary,
                        color: kGreyColor,
                        weight: FontWeight.w400,
                        align: TextAlign.left,
                      ),
                      const SizedBox(height: 4),
                    ],
                    AppText.p2(
                      'at ${LeaveFormat.timelineStamp(event.at)}',
                      color: kGreyColor,
                      weight: FontWeight.w400,
                      align: TextAlign.left,
                    ),
                    // Only show Reason when the API actually provided one.
                    if (hasReason) ...[
                      const SizedBox(height: 10),
                      AppText.p2(
                        'Reason:',
                        color: kGreyColor,
                        weight: FontWeight.w400,
                        align: TextAlign.left,
                      ),
                      const SizedBox(height: 4),
                      AppText.p2(
                        reason,
                        color: kSubText,
                        weight: FontWeight.w400,
                        align: TextAlign.left,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (onAddReason != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: MyButton(
                width: 140,
                height: 40,
                size: MyButtonSize.normal,
                buttonText: hasReason ? 'Edit Reason' : 'Add Reason',
                backgroundColor: kWhite,
                fontColor: kBlack,
                outlineColor: kBorderColor,
                hasicon: true,
                leftWidget: CommonImageView(
                  imagePath: Assets.imagesPen,
                  height: 14,
                ),
                onTap: () async => onAddReason!(),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return child;
    return ButtonAnimations.press(onTap: onTap, child: child);
  }
}

class _TimelineStyle {
  const _TimelineStyle({
    required this.title,
    required this.color,
    required this.subtitle,
    this.iconPath,
    this.fallbackIcon = Icons.access_time,
  });

  final String title;
  final Color color;
  final String? iconPath;
  final IconData fallbackIcon;
  final String? subtitle;
}

_TimelineStyle _styleFor(LeaveTimelineKind kind, String? actorName) {
  final by = actorName?.trim();
  final label = (by != null && by.isNotEmpty) ? by : 'Manager';
  switch (kind) {
    case LeaveTimelineKind.approved:
      return _TimelineStyle(
        title: 'Approved',
        color: kPrimaryColor,
        iconPath: Assets.imagesCheck,
        subtitle: 'Approved by - $label',
      );
    case LeaveTimelineKind.rejected:
      return _TimelineStyle(
        title: 'Rejected',
        color: kredColor,
        iconPath: Assets.imagesXmark,
        subtitle: 'Rejected by - $label',
      );
    case LeaveTimelineKind.requested:
      return const _TimelineStyle(
        title: 'Leave Requested',
        color: kPurple,
        fallbackIcon: Icons.access_time,
        subtitle: null,
      );
  }
}
