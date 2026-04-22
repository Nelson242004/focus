class Subject {
  int? id;
  String name;
  String color;
  String icon;
  String? defaultClassroom; // opcional
  String? professorName;
  String? sectionCode;

  Subject({
    this.id,
    required this.name,
    required this.color,
    this.icon = 'book',
    this.defaultClassroom,
    this.professorName,
    this.sectionCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'icon': icon,
      'defaultClassroom': defaultClassroom,
      'professorName': professorName,
      'sectionCode': sectionCode,
    };
  }

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: int.tryParse('${map['id'] ?? ''}'),
      name: '${map['name'] ?? 'Materia'}',
      color: '${map['color'] ?? '#2563EB'}',
      icon: '${map['icon'] ?? 'book'}',
      defaultClassroom: map['defaultClassroom']?.toString(),
      professorName: map['professorName']?.toString(),
      sectionCode: map['sectionCode']?.toString(),
    );
  }
}
