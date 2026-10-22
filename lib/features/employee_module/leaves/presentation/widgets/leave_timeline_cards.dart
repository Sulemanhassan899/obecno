import 'package:flutter/material.dart';
import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_format.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';

/// Stacked leave timeline cards — one card per event, never overwritten.
class LeaveTimelineCards extends StatelessWidget {
  const LeaveTimelineCards({
    super.key,
    required this.events,
    this.onTapRequested,
    this.onAddReason,
  });

  final List<LeaveTimelineEvent> events;
  final ValueChanged<LeaveTimelineEvent>? onTapRequested;

  /// Manager-only: show "Add Reason" on rejected timeline cards.
  final VoidCallback? onAddReason;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (var i = 0; i < events.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _LeaveTimelineCard(
            event: events[i],
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
    this.onTap,
    this.onAddReason,
  });

  final LeaveTimelineEvent event;
  final VoidCallback? onTap;
  final VoidCallback? onAddReason;

  static const _iconSlot = 16.0;
  static const _iconGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(event.kind);
    final primary = style.subtitle(event);
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
                    if (event.kind == LeaveTimelineKind.rejected) ...[
                      const SizedBox(height: 10),
                      AppText.p2(
                        'Reason:',
                        color: kGreyColor,
                        weight: FontWeight.w400,
                        align: TextAlign.left,
                      ),
                      if (hasReason) ...[
                        const SizedBox(height: 4),
                        AppText.p2(
                          reason,
                          color: kSubText,
                          weight: FontWeight.w400,
                          align: TextAlign.left,
                        ),
                      ],
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
  final String? Function(LeaveTimelineEvent) subtitle;
}

_TimelineStyle _styleFor(LeaveTimelineKind kind) {
  switch (kind) {
    case LeaveTimelineKind.approved:
      return _TimelineStyle(
        title: 'Approved',
        color: kPrimaryColor,
        iconPath: Assets.imagesCheck,
        subtitle: (e) => 'Approved by - ${e.actorName ?? 'Manager'}',
      );
    case LeaveTimelineKind.rejected:
      return _TimelineStyle(
        title: 'Rejected',
        color: kredColor,
        iconPath: Assets.imagesXmark,
        subtitle: (e) => 'Rejected by - ${e.actorName ?? 'Manager'}',
      );
    case LeaveTimelineKind.requested:
      return _TimelineStyle(
        title: 'Leave Requested',
        color: kPurple,
        fallbackIcon: Icons.access_time,
        subtitle: (_) => null,
      );
  }
}
