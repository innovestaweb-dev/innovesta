import 'package:web/web.dart' as web;

// Updates the <head> of the page: title, meta tags, canonical link and
// JSON-LD. Elements are created once and updated afterwards (no duplicates).
void applyHead({
  required String title,
  required String description,
  required String canonicalUrl,
  required String imageUrl,
  required String language,
  required String siteName,
  required bool noIndex,
  required String jsonLd,
}) {
  web.document.title = title;
  web.document.documentElement?.setAttribute('lang', language);

  _meta(name: 'description', content: description);
  _meta(
    name: 'robots',
    content: noIndex
        ? 'noindex, nofollow'
        : 'index, follow, max-image-preview:large',
  );

  // Open Graph
  _meta(property: 'og:type', content: 'website');
  _meta(property: 'og:site_name', content: siteName);
  _meta(property: 'og:title', content: title);
  _meta(property: 'og:description', content: description);
  _meta(property: 'og:url', content: canonicalUrl);
  _meta(property: 'og:image', content: imageUrl);
  _meta(property: 'og:locale', content: language == 'ar' ? 'ar_AR' : 'en_US');

  // Twitter / X
  _meta(name: 'twitter:card', content: 'summary_large_image');
  _meta(name: 'twitter:title', content: title);
  _meta(name: 'twitter:description', content: description);
  _meta(name: 'twitter:image', content: imageUrl);

  _canonical(canonicalUrl);
  _jsonLdScript(jsonLd);
}

void _meta({String? name, String? property, required String content}) {
  final head = web.document.head;
  if (head == null) return;

  final selector = name != null
      ? 'meta[name="$name"]'
      : 'meta[property="$property"]';

  var element = head.querySelector(selector);

  if (element == null) {
    element = web.document.createElement('meta');

    if (name != null) {
      element.setAttribute('name', name);
    } else {
      element.setAttribute('property', property!);
    }

    head.appendChild(element);
  }

  element.setAttribute('content', content);
}

void _canonical(String href) {
  final head = web.document.head;
  if (head == null) return;

  var element = head.querySelector('link[rel="canonical"]');

  if (element == null) {
    element = web.document.createElement('link');
    element.setAttribute('rel', 'canonical');
    head.appendChild(element);
  }

  element.setAttribute('href', href);
}

void _jsonLdScript(String json) {
  final head = web.document.head;
  if (head == null) return;

  var script = web.document.getElementById('seo-jsonld');

  if (script == null) {
    script = web.document.createElement('script');
    script.id = 'seo-jsonld';
    script.setAttribute('type', 'application/ld+json');
    head.appendChild(script);
  }

  script.textContent = json;
}
