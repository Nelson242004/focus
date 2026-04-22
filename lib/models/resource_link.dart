class ResourceLink {
  final int? id;
  final String title;
  final String url;
  final String category;
  final int? subjectId;
  final bool isDefault;

  const ResourceLink({
    this.id,
    required this.title,
    required this.url,
    required this.category,
    this.subjectId,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'category': category,
      'subjectId': subjectId,
    };
  }

  factory ResourceLink.fromMap(Map<String, dynamic> map) {
    return ResourceLink(
      id: int.tryParse('${map['id'] ?? ''}'),
      title: '${map['title'] ?? 'Recurso'}',
      url: '${map['url'] ?? 'https://policode.netlify.app/'}',
      category: '${map['category'] ?? 'tool'}',
      subjectId: int.tryParse('${map['subjectId'] ?? ''}'),
    );
  }
}
