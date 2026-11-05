import '../models/book_detail.dart';
import '../models/media_item.dart';
import 'api_client.dart';

typedef BookDirectoryLoader = Future<List<Chapter>> Function(String bookId);
typedef BookChapterCountLoader = Future<int> Function(String bookId);

Future<List<Chapter>> loadBookDirectory(String bookId) async =>
    (await ApiClient.instance.directoryChapters(
      bookId,
    )).expand((volume) => volume).toList(growable: false);

Future<int> loadBookChapterCount(String bookId) async {
  // 墨卓：书架上的书旗书（shuqi:<id>）查书旗目录的章节数，别拿它去问番茄接口
  if (bookId.startsWith('shuqi:')) {
    final data = (await ApiClient.instance.shuqiToc(bookId.substring(6)))['data'];
    final total = data is Map ? data['total'] : null;
    return total is num ? total.toInt() : 0;
  }
  return BookDetail.fromPayload(await ApiClient.instance.detail(bookId)).serialCount;
}
