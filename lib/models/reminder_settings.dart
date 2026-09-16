class ReminderSettings {
  final bool enabled;
  final int hour;
  final int minute;

  const ReminderSettings({
    this.enabled = false,
    this.hour = 20,
    this.minute = 0,
  });

  ReminderSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
  }) => ReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
      };

  factory ReminderSettings.fromJson(Map<String, dynamic> json) => ReminderSettings(
        enabled: json['enabled'] as bool? ?? false,
        hour: json['hour'] as int? ?? 20,
        minute: json['minute'] as int? ?? 0,
      );
}
