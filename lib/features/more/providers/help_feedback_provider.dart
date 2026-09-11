import 'package:intl/intl.dart';
import 'package:obecno/core/api/base_provider.dart';
import 'package:obecno/features/more/services/device_info_service.dart';

import '../data/models/help_feedback_ticket_model.dart';
import '../data/domain/help_feedback_entity.dart';
import '../services/help_feedback_service.dart';

class HelpFeedbackProvider extends BaseProvider {
  HelpFeedbackProvider(this._service, this._deviceInfoService);

  final HelpFeedbackService _service;
  final DeviceInfoService _deviceInfoService;

  HelpFeedbackTicketResult? _submittedTicket;
  HelpFeedbackTicketResult? get submittedTicket => _submittedTicket;

  Future<bool> submitFeedback({
    required String name,
    required String email,
    required String phoneCode,
    required String phone,
    required String department,
    required String issue,
    String employeeId = '',
    String company = '',
    String role = '',
    String designation = '',
    String employeeCode = '',
  }) async {
    String deviceName = '';
    String deviceMac = '';
    String os = '';
    String appVersion = '';

    try {
      final device = await _deviceInfoService.collect();
      deviceName = device.deviceName;
      deviceMac = device.macAddress;
      os = '${device.os} ${device.osVersion}'.trim();
      appVersion = device.appVersion;
    } catch (_) {
      // Device metadata is extra context; the ticket can still go through.
    }

    final entity = HelpFeedbackEntity(
      name: name,
      email: email,
      phoneCode: phoneCode,
      phone: phone,
      department: department,
      issue: issue,
      deviceName: deviceName,
      deviceMac: deviceMac,
      complaintDate: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
      employeeId: employeeId,
      company: company,
      role: role,
      designation: designation,
      employeeCode: employeeCode,
      os: os,
      appVersion: appVersion,
    );

    return safeCall<HelpFeedbackTicketResult>(
      operationKey: 'help_feedback_submit',
      request: (_) => _service.submitFeedback(entity),
      onSuccess: (data) => _submittedTicket = data,
    );
  }

  void reset() {
    _submittedTicket = null;
    resetViewState();
  }
}
