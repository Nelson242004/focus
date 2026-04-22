import '../models/resource_link.dart';
import '../models/subject.dart';

class ResourceCatalogEntry {
  final String title;
  final String url;
  final String category;
  final String? subjectName;
  final bool visible;
  final bool required;

  const ResourceCatalogEntry({
    required this.title,
    required this.url,
    required this.category,
    this.subjectName,
    this.visible = true,
    this.required = false,
  });
}

class ResourceCatalog {
  const ResourceCatalog._();

  // Edita esta lista libremente:
  // - visible: controla si se muestra en la app
  // - required: si es true, el recurso queda fijo y no se puede borrar
  static const List<ResourceCatalogEntry> defaults = [
    ResourceCatalogEntry(
      title: 'Spotify - Playlists para estudiar - Focus',
      url: 'https://open.spotify.com/playlist/3qfeW1jkJty0kQLwGouhBS?si=6t1Wi9isQIuH0gpzm0b3bw',
      category: 'playlist',
      required: true,
      visible: true,
    ),
    ResourceCatalogEntry(
      title: 'YouTube - LoFi Girl - Focus',
      url: 'https://youtu.be/n2w3VdXRJjw?si=_xgYeoR6cVGo8lIE',
      category: 'playlist',
      required: true,
      visible: true,
    ),
    ResourceCatalogEntry(
      title: 'Brain.fm',
      url: 'https://www.brain.fm/',
      category: 'playlist',
      visible: false,
    ),
    ResourceCatalogEntry(
      title: 'Khan Academy',
      url: 'https://www.khanacademy.org/',
      category: 'course',
      visible: false,
    ),
    ResourceCatalogEntry(
      title: 'Coursera',
      url: 'https://www.coursera.org/',
      category: 'course',
      visible: false,
    ),
    ResourceCatalogEntry(
      title: 'edX',
      url: 'https://www.edx.org/',
      category: 'course',
      visible: false,
    ),
    ResourceCatalogEntry(
      title: 'MIT OpenCourseWare',
      url: 'https://ocw.mit.edu/',
      category: 'course',
      visible: false,
    ),
    ResourceCatalogEntry(
      title: 'TikTok - PoliCode',
      url: 'https://www.tiktok.com/@policode01',
      category: 'social',
      required: false,
      visible: false,
    ),
    ResourceCatalogEntry(
      title: 'Instagram - PoliCode',
      url: 'https://www.instagram.com/nelson_spy?igsh=ZjhyMWJuY2poeGNv',
      category: 'social',
      required: false,
      visible: false,
    ),
    ResourceCatalogEntry(
      title: 'Google Drive',
      url: 'https://drive.google.com/',
      category: 'tool',
      required: true,
      visible: false,
    ),
    ResourceCatalogEntry(
      title: 'Notion',
      url: 'https://www.notion.so/',
      category: 'tool',
      visible: false,
    ),
    ResourceCatalogEntry(
      title: 'Anki',
      url: 'https://apps.ankiweb.net/',
      category: 'tool',
      visible: false,
    ),
  ];

  static List<ResourceLink> buildVisibleResources(List<Subject> subjects) {
    return defaults
        .where((entry) => entry.visible)
        .map((entry) {
          final subjectId = entry.subjectName == null
              ? null
              : subjects
                  .where(
                    (subject) =>
                        subject.name.trim().toLowerCase() ==
                        entry.subjectName!.trim().toLowerCase(),
                  )
                  .map((subject) => subject.id)
                  .cast<int?>()
                  .firstWhere((id) => id != null, orElse: () => null);
          return ResourceLink(
            title: entry.title,
            url: entry.url,
            category: entry.category,
            subjectId: subjectId,
            isDefault: entry.required,
          );
        })
        .toList();
  }
}
