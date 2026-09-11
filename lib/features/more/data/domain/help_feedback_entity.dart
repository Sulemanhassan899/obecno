class HelpFeedbackPhone {
  HelpFeedbackPhone._();

  static const List<String> dialCodes = [
    '+92',
    '+1',
    '+44',
    '+91',
    '+61',
    '+971',
  ];

  static ({String code, String number}) split(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) return (code: '+92', number: '');

    var value = trimmed.replaceAll(RegExp(r'[\s()-]'), '');
    if (value.startsWith('00')) {
      value = '+${value.substring(2)}';
    }

    final codes = [...dialCodes]..sort((a, b) => b.length.compareTo(a.length));

    for (final code in codes) {
      final digits = code.substring(1);
      if (value.startsWith(code)) {
        return (code: code, number: value.substring(code.length));
      }
      if (value.startsWith(digits)) {
        return (code: code, number: value.substring(digits.length));
      }
    }

    if (value.startsWith('0') && value.length >= 10) {
      return (code: '+92', number: value.substring(1));
    }

    return (code: '+92', number: value.replaceFirst(RegExp(r'^\+'), ''));
  }
}

class HelpFeedbackEntity {
  const HelpFeedbackEntity({
    required this.name,
    required this.email,
    required this.phoneCode,
    required this.phone,
    required this.department,
    required this.issue,
    required this.deviceName,
    required this.deviceMac,
    required this.complaintDate,
    this.employeeId = '',
    this.company = '',
    this.role = '',
    this.designation = '',
    this.employeeCode = '',
    this.os = '',
    this.appVersion = '',
  });

  final String name;
  final String email;
  final String phoneCode;
  final String phone;
  final String department;
  final String issue;
  final String deviceName;
  final String deviceMac;
  final String complaintDate;
  final String employeeId;
  final String company;
  final String role;
  final String designation;
  final String employeeCode;
  final String os;
  final String appVersion;

  String get fullPhone {
    final number = phone.trim();
    if (number.isEmpty) return phoneCode;
    return '$phoneCode $number';
  }

  String buildContentMessage() {
    String line(String label, String value) {
      final trimmed = value.trim();
      return '$label: ${trimmed.isEmpty ? '—' : trimmed}';
    }

    final buffer = StringBuffer()
      ..writeln('New help & feedback request submitted from the app.')
      ..writeln()
      ..writeln('Issue:')
      ..writeln(issue.trim())
      ..writeln()
      ..writeln(line('Name', name))
      ..writeln(line('Email', email))
      ..writeln(line('Phone', fullPhone))
      ..writeln(line('Department', department))
      ..writeln(line('Device name', deviceName))
      ..writeln(line('Device MAC', deviceMac))
      ..writeln(line('Date of complaint', complaintDate))
      ..writeln(line('Employee ID', employeeId))
      ..writeln(line('Employee code', employeeCode))
      ..writeln(line('Company', company))
      ..writeln(line('Role', role))
      ..writeln(line('Designation', designation))
      ..writeln(line('OS', os))
      ..writeln(line('App version', appVersion));

    return buffer.toString().trim();
  }

  @override
  String toString() =>
      'HelpFeedbackEntity(name: $name, email: $email, issue: $issue)';
}
