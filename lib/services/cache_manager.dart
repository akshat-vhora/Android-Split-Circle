class CacheEntry {
  final DateTime fetchedAt;
  final Duration staleAfter;

  CacheEntry(this.fetchedAt, this.staleAfter);

  bool get isFresh => DateTime.now().difference(fetchedAt) < staleAfter;
}

class CacheManager {
  final Map<String, CacheEntry> _entries = {};

  void touch(String key, Duration staleAfter) {
    _entries[key] = CacheEntry(DateTime.now(), staleAfter);
  }

  bool isFresh(String key) {
    final entry = _entries[key];
    if (entry == null) return false;
    return entry.isFresh;
  }

  void clear(String key) {
    _entries.remove(key);
  }

  void clearAll() {
    _entries.clear();
  }
}

final cacheManager = CacheManager();
