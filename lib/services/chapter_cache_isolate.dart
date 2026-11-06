import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:hive_ce/hive.dart';

import 'chapter_cache_store.dart';
import 'secure_key_provider.dart';

typedef _Op = Future<Object?> Function(ChapterCacheStore store);

/// 墨卓：章节缓存放到后台 isolate 里开、读、写。批量缓存后这个加密 box 有几十 MB，
/// Hive 打开时要整库解密解码（Kindle 上十几秒）；Flutter 3.44 在安卓上 Dart 和主线程合并，
/// 放在根 isolate 里一打开就“没有响应”（切到书架查更新时最先碰到它）。
/// 接口和 [ChapterCacheStore] 一样；测试里没有根 isolate 令牌，照旧在本 isolate 跑。
class IsolatedChapterCacheStore extends ChapterCacheStore {
  Future<SendPort>? _worker;

  Future<T> _run<T>(_Op op, Future<T> Function() local) async {
    final token = RootIsolateToken.instance;
    if (token == null) return local();
    final worker = _worker ??= _spawn(token);
    final SendPort port;
    try {
      port = await worker;
    } catch (_) {
      if (identical(_worker, worker)) _worker = null; // 下次再试
      rethrow;
    }
    final reply = ReceivePort();
    port.send((op, reply.sendPort));
    final (ok, value) = await reply.first as (bool, Object?);
    reply.close();
    if (!ok) throw value!;
    return value as T;
  }

  static Future<SendPort> _spawn(RootIsolateToken token) async {
    // 密钥在根 isolate 取（Keystore 走平台通道），拿不到就不开：后台不能自己生成新密钥，否则打不开已有的库
    final key = await SecureKeyProvider.instance.getOrCreateKey();
    if (key == null) throw StateError('加密密钥不可用，拒绝打开章节缓存');
    final home = (Hive as dynamic).homePath as String?;
    final ready = ReceivePort();
    await Isolate.spawn(_main, (token, home, key, ready.sendPort),
        debugName: 'chapter_cache');
    return await ready.first as SendPort;
  }

  static Future<void> _main(
    (RootIsolateToken, String?, Uint8List, SendPort) args,
  ) async {
    final (token, home, key, ready) = args;
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
    Hive.init(home);
    final storage = InMemorySecureKeyStorage();
    await storage.write(SecureKeyProvider.hiveBoxKeyName, base64Encode(key));
    final store = ChapterCacheStore(keys: SecureKeyProvider(storage: storage));
    final requests = ReceivePort();
    ready.send(requests.sendPort);
    requests.listen((message) async {
      final (op, reply) = message as (_Op, SendPort);
      try {
        reply.send((true, await op(store)));
      } catch (error) {
        reply.send((false, error is StateError ? error : StateError('$error')));
      }
    });
  }

  // 发到后台的操作只捕获参数（静态方法里建闭包），不带 this
  static _Op _read(String b, String c) =>
      (s) => s.read(bookId: b, chapterId: c);
  static _Op _write(String b, String c, String t, String x, bool p) =>
      (s) => s.write(bookId: b, chapterId: c, title: t, text: x, pinned: p);
  static _Op _saveBook(CachedBook book) => (s) => s.saveBook(book);
  static _Op _ids(String b) => (s) => s.cachedChapterIds(b);
  static _Op _stats(String? b) => (s) => s.stats(bookId: b);
  static _Op _books() => (s) => s.books();
  static _Op _cachedBook(String b) => (s) => s.cachedBook(b);
  static _Op _catalogue(String b) => (s) => s.savedCatalogue(b);
  static _Op _clear(String? b) => (s) => s.clear(bookId: b);

  @override
  Future<String?> read({required String bookId, required String chapterId}) =>
      _run(_read(bookId, chapterId),
          () => super.read(bookId: bookId, chapterId: chapterId));

  @override
  Future<void> write({
    required String bookId,
    required String chapterId,
    required String title,
    required String text,
    bool pinned = false,
  }) async {
    var remote = true;
    await _run<void>(_write(bookId, chapterId, title, text, pinned), () {
      remote = false;
      return super.write(
          bookId: bookId, chapterId: chapterId, title: title, text: text, pinned: pinned);
    });
    if (remote) changes.value++;
  }

  @override
  Future<void> saveBook(CachedBook book) =>
      _run(_saveBook(book), () => super.saveBook(book));

  @override
  Future<Set<String>> cachedChapterIds(String bookId) =>
      _run(_ids(bookId), () => super.cachedChapterIds(bookId));

  @override
  Future<ChapterCacheStats> stats({String? bookId}) =>
      _run(_stats(bookId), () => super.stats(bookId: bookId));

  @override
  Future<List<CachedBookSummary>> books() => _run(_books(), super.books);

  @override
  Future<CachedBook?> cachedBook(String bookId) =>
      _run(_cachedBook(bookId), () => super.cachedBook(bookId));

  @override
  Future<CachedBook?> savedCatalogue(String bookId) =>
      _run(_catalogue(bookId), () => super.savedCatalogue(bookId));

  @override
  Future<void> clear({String? bookId}) async {
    var remote = true;
    await _run<void>(_clear(bookId), () {
      remote = false;
      return super.clear(bookId: bookId);
    });
    if (remote) changes.value++;
  }
}
