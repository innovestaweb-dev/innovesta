/// Central place for route names.
///
/// Every public page has its own real URL (path URL strategy), which is what
/// lets search engines index and link to each page separately.
abstract final class AppRoutes {
  static const String home = '/';
  static const String services = '/services';
  static const String portfolio = '/portfolio';
  static const String interactive = '/interactive';
  static const String contact = '/contact';
  static const String freeTools = '/free-tools';

  /// Private / technical routes (kept out of search results).
  static const String admin = '/admin';
  static const String notFound = '/404';
}
