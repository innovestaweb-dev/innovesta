import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../app_language.dart';
import 'seo_stub.dart' if (dart.library.js_interop) 'seo_web.dart' as platform;

// -----------------------------------------------------------------------------
// SEO for a Flutter web app
//
// What this does, per page / URL:
//   - <title>, meta description, canonical URL, robots (index / noindex)
//   - Open Graph + Twitter Card tags
//   - <html lang>
//   - JSON-LD structured data (Organization, WebSite, WebPage + page extras)
//
// It is driven by the route name, so it also updates correctly on back /
// forward navigation and when the user switches the app language.
// -----------------------------------------------------------------------------

class SeoConfig {
  const SeoConfig._();

  /// IMPORTANT: set your real domain at build time:
  ///   flutter build web --release --dart-define=SITE_URL=https://your-domain.com
  /// (no trailing slash). The default below is only a placeholder.
  static const String baseUrl = String.fromEnvironment(
    'SITE_URL',
    defaultValue: 'https://www.example.com',
  );

  static const String siteName = 'INNOVISTA';

  static const String defaultTitle =
      'INNOVISTA | Architectural Visualization Studio';

  /// Image used when a page is shared (Open Graph / Twitter). Replace with a
  /// 1200x630 image (e.g. /og-image.jpg) placed in the `web/` folder.
  static const String ogImagePath = '/icons/Icon-512.png';

  static const String logoPath = '/icons/Icon-512.png';

  static String url(String path) {
    if (path == '/') return '$baseUrl/';
    return '$baseUrl$path';
  }

  static String get organizationId => '$baseUrl/#organization';
  static String get websiteId => '$baseUrl/#website';
}

/// Metadata of one page (English + Arabic).
class SeoPage {
  const SeoPage({
    required this.path,
    required this.titleEn,
    required this.titleAr,
    required this.descriptionEn,
    required this.descriptionAr,
    this.jsonLd,
    this.noIndex = false,
  });

  final String path;
  final String titleEn;
  final String titleAr;
  final String descriptionEn;
  final String descriptionAr;

  /// Extra structured-data nodes for this page (breadcrumbs, services, FAQ...).
  final List<Map<String, Object?>> Function()? jsonLd;

  /// true for private / technical pages (admin, 404).
  final bool noIndex;

  String get title => AppLanguage.isArabic ? titleAr : titleEn;
  String get description =>
      AppLanguage.isArabic ? descriptionAr : descriptionEn;
}

class SeoManager {
  SeoManager._();

  static final Map<String, SeoPage> _pages = {};
  static String? _currentPath;
  static bool _initialized = false;

  /// Title of the page currently shown. Used by MaterialApp.onGenerateTitle so
  /// Flutter does not overwrite the page title when the app rebuilds.
  static String get currentTitle =>
      _pages[_currentPath]?.title ?? SeoConfig.defaultTitle;

  static void init(Iterable<SeoPage> pages) {
    for (final page in pages) {
      _pages[page.path] = page;
    }

    if (_initialized) return;
    _initialized = true;

    // Re-apply the metadata in the new language when the user switches it.
    AppLanguage.locale.addListener(() => applyForPath(_currentPath));
  }

  static String _normalize(String routeName) {
    var path = Uri.tryParse(routeName)?.path ?? routeName;

    if (path.isEmpty) return '/';
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    return path;
  }

  static void applyForPath(String? routeName) {
    if (routeName == null) return;

    final path = _normalize(routeName);
    final page = _pages[path];

    if (page == null) return;

    _currentPath = path;

    try {
      final pageUrl = SeoConfig.url(path);
      final language = AppLanguage.isArabic ? 'ar' : 'en';

      final graph = <Map<String, Object?>>[
        SeoSchema.organization(),
        SeoSchema.website(),
        SeoSchema.webPage(
          url: pageUrl,
          name: page.title,
          description: page.description,
          language: language,
        ),
        ...?page.jsonLd?.call(),
      ];

      platform.applyHead(
        title: page.title,
        description: page.description,
        canonicalUrl: pageUrl,
        imageUrl: SeoConfig.url(SeoConfig.ogImagePath),
        language: language,
        siteName: SeoConfig.siteName,
        noIndex: page.noIndex,
        jsonLd: jsonEncode({'@context': 'https://schema.org', '@graph': graph}),
      );
    } catch (e) {
      debugPrint('SEO update failed: $e');
    }
  }
}

/// Add to MaterialApp.navigatorObservers.
class SeoRouteObserver extends NavigatorObserver {
  void _apply(Route<dynamic>? route) {
    // Ignore dialogs, popups, bottom sheets...
    if (route is! PageRoute) return;

    SeoManager.applyForPath(route.settings.name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _apply(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _apply(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _apply(newRoute);
  }
}

// -----------------------------------------------------------------------------
// JSON-LD (schema.org) helpers
// -----------------------------------------------------------------------------

class SeoSchema {
  const SeoSchema._();

  static Map<String, Object?> organization() => {
    '@type': 'Organization',
    '@id': SeoConfig.organizationId,
    'name': SeoConfig.siteName,
    'url': SeoConfig.url('/'),
    'logo': SeoConfig.url(SeoConfig.logoPath),
  };

  static Map<String, Object?> website() => {
    '@type': 'WebSite',
    '@id': SeoConfig.websiteId,
    'url': SeoConfig.url('/'),
    'name': SeoConfig.siteName,
    'publisher': {'@id': SeoConfig.organizationId},
    'inLanguage': ['en', 'ar'],
  };

  static Map<String, Object?> webPage({
    required String url,
    required String name,
    required String description,
    required String language,
  }) => {
    '@type': 'WebPage',
    '@id': '$url#webpage',
    'url': url,
    'name': name,
    'description': description,
    'inLanguage': language,
    'isPartOf': {'@id': SeoConfig.websiteId},
    'about': {'@id': SeoConfig.organizationId},
  };

  static Map<String, Object?> breadcrumb(
    List<({String name, String path})> items,
  ) => {
    '@type': 'BreadcrumbList',
    'itemListElement': <Map<String, Object?>>[
      for (int i = 0; i < items.length; i++)
        {
          '@type': 'ListItem',
          'position': i + 1,
          'name': items[i].name,
          'item': SeoConfig.url(items[i].path),
        },
    ],
  };

  static Map<String, Object?> service({
    required String name,
    required String description,
    required String pageUrl,
  }) => {
    '@type': 'Service',
    'name': name,
    'description': description,
    'url': pageUrl,
    'provider': {'@id': SeoConfig.organizationId},
  };

  static Map<String, Object?> faq(
    List<({String question, String answer})> qa,
  ) => {
    '@type': 'FAQPage',
    'mainEntity': <Map<String, Object?>>[
      for (final item in qa)
        {
          '@type': 'Question',
          'name': item.question,
          'acceptedAnswer': {'@type': 'Answer', 'text': item.answer},
        },
    ],
  };
}
