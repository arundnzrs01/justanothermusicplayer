import 'package:torrent_music/data/models/search_result.dart';

abstract class SourceAdapter {
  String get id;
  String get displayName;
  Future<List<SearchResult>> search(String query);
}
