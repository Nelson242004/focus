import 'package:flutter_test/flutter_test.dart';
import 'package:focus_app/models/resource_link.dart';

void main() {
  test('ResourceLink conserva recursos importados', () {
    final resource = ResourceLink.fromMap({
      'id': '12',
      'title': 'Playlist de estudio',
      'url': 'https://policode.netlify.app/',
      'category': 'playlist',
      'subjectId': '4',
    });

    expect(resource.id, 12);
    expect(resource.title, 'Playlist de estudio');
    expect(resource.url, 'https://policode.netlify.app/');
    expect(resource.category, 'playlist');
    expect(resource.subjectId, 4);
  });
}
