import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/features/join/data/models/join_invite_models.dart';
import 'package:obecno/widgets/my_button.dart';

class JoinEmployeeAlertCard extends StatelessWidget {
  const JoinEmployeeAlertCard({
    super.key,
    required this.invite,
    this.busy = false,
    this.onApprove,
    this.onReject,
  });

  final JoinInviteRecord invite;
  final bool busy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  String get _title {
    if (invite.source == JoinInviteSource.manual) {
      return 'Employee joined';
    }
    return 'New employee needs approval';
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final min = local.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    final stamp = invite.joinedAt ?? invite.createdAt;
    final location = (invite.locationName ?? '').trim().isEmpty
        ? 'No Location'
        : invite.locationName!;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                invite.source == JoinInviteSource.manual
                    ? Icons.person_outline
                    : Icons.person_add_alt_1_outlined,
                size: 20,
                color: kPrimaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.h6(
                      _title,
                      align: TextAlign.left,
                      weight: FontWeight.w600,
                    ),
                    const SizedBox(height: 4),
                    AppText.p2(
                      invite.displayContact.isEmpty
                          ? 'Pending employee'
                          : invite.displayContact,
                      align: TextAlign.left,
                      weight: FontWeight.w600,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppText.p2(
                            location,
                            align: TextAlign.left,
                            color: kGreyColor,
                          ),
                        ),
                        AppText.p2(_formatTime(stamp), color: kGreyColor),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (busy)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (invite.status == JoinInviteStatus.pendingApproval)
                      Row(
                        children: [
                          Expanded(
                            child: MyButton(
                              size: MyButtonSize.normal,
                              compact: false,
                              radius: 30,
                              height: 36,
                              buttonText: 'Approve',
                              backgroundColor: kPrimaryColor,
                              fontColor: kWhite,
                              onTap: () async => onApprove?.call(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: MyButton(
                              size: MyButtonSize.normal,
                              compact: false,
                              radius: 30,
                              height: 36,
                              buttonText: 'Reject',
                              backgroundColor: kredColor,
                              fontColor: kWhite,
                              onTap: () async => onReject?.call(),
                            ),
                          ),
                        ],
                      )
                    else
                      _StatusRow(status: invite.status),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.status});

  final JoinInviteStatus status;

  @override
  Widget build(BuildContext context) {
    final isRejected = status == JoinInviteStatus.rejected;
    final isAuto = status == JoinInviteStatus.autoApproved;
    final color = isRejected ? kredColor : kPrimaryColor;
    final label = isRejected
        ? 'Rejected'
        : isAuto
            ? 'Auto Approved'
            : 'Approved';

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        AppText.p2(label, color: color, weight: FontWeight.w500),
      ],
    );
  }
}
