// Used on platforms without a browser DOM (mobile / desktop / tests).
// SEO tags only make sense on the web, so this does nothing.
void applyHead({
  required String title,
  required String description,
  required String canonicalUrl,
  required String imageUrl,
  required String language,
  required String siteName,
  required bool noIndex,
  required String jsonLd,
}) {}
