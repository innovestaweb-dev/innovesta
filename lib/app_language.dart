import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// One language system for the whole app.
///
/// - [locale] drives `MaterialApp.locale` (see main.dart).
/// - [text] / [isArabic] can be used from ANY widget, with or without a
///   BuildContext.
/// - Switching language (via [toggle] or [setLocale]) automatically refreshes
///   every screen that is currently in the navigation stack, so no page needs
///   its own listener or `setState`. Widget State is preserved (uploaded
///   images, scroll positions, selections, text fields are NOT reset).
class AppLanguage {
  static const Locale localeEn = Locale('en');
  static const Locale localeAr = Locale('ar');

  static final ValueNotifier<Locale> locale = ValueNotifier<Locale>(localeEn);

  static bool get isArabic => locale.value.languageCode == 'ar';

  static TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  static void toggle() {
    setLocale(isArabic ? localeEn : localeAr);
  }

  static void setLocale(Locale newLocale) {
    if (locale.value.languageCode == newLocale.languageCode) return;

    locale.value = newLocale;
    _rebuildWholeApp();
  }

  static String text(String english, String arabic) {
    return isArabic ? arabic : english;
  }

  /// Marks every active element dirty so all screens re-read [text].
  ///
  /// Needed because many widgets call the static [text] (which does not
  /// subscribe to anything) and because routes created with `const` pages are
  /// not rebuilt when MaterialApp rebuilds. It runs once per language switch.
  static void _rebuildWholeApp() {
    final binding = WidgetsBinding.instance;

    void rebuild() {
      void visit(Element element) {
        element.markNeedsBuild();
        element.visitChildren(visit);
      }

      binding.rootElement?.visitChildren(visit);
    }

    // If the switch happens while a frame is being built, wait until it ends.
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) => rebuild());
    } else {
      rebuild();
    }
  }
}
