import '../models/book_detail.dart';
import '../models/media_item.dart';
import '../models/shuqi_book.dart';
import 'api_client.dart';

typedef BookDirectoryLoader = Future<List<Chapter>> Function(String bookId);
typedef BookChapterCountLoader = Future<int> Function(String bookId);

Future<List<Chapter>> loadBookDirectory(String bookId) async =>
    (await ApiClient.instance.directoryChapters(
      bookId,
    )).expand((volume) => volume).toList(growable: false);

Future<int> loadBookChapterCount(String bookId) async {
  // 墨卓：书架上的书旗书（shuqi:<id>）别拿去问番茄接口。用书籍详情里的总章数，
  // 不拉整本目录（几千章的 JSON 在墨卓上解析要好几秒，切到书架就“没有响应”）
  if (bookId.startsWith('shuqi:')) {
    final data = (await ApiClient.instance.shuqiBook(bookId.substring(6)))['data'];
    return data is Map ? ShuqiBook.fromJson(Map<String, dynamic>.from(data)).chapterTotalNum : 0;
  }
  return BookDetail.fromPayload(await ApiClient.instance.detail(bookId)).serialCount;
}
