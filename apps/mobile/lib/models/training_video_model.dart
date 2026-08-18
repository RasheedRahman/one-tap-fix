/// A training/safety video for technicians (plan §5). Videos are
/// external links (e.g. YouTube); admin-managed via the web panel.
class TrainingVideoModel {
  const TrainingVideoModel({
    required this.id,
    required this.title,
    required this.url,
    required this.durationMinutes,
    required this.sortOrder,
    required this.isActive,
    this.description = '',
  });

  final String id;
  final String title;
  final String url;
  final String description;
  final int durationMinutes;
  final int sortOrder;
  final bool isActive;

  factory TrainingVideoModel.fromJson(String id, Map<String, dynamic> json) {
    return TrainingVideoModel(
      id: id,
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      description: json['description'] as String? ?? '',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
