import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

import 'app_routes.dart';

/// Records anonymous page views through the `track-visit` Edge Function.
///
/// - No cookies and no personal data: only a random id kept in the browser
///   storage (to count unique visitors), the page path and the referrer host.
/// - Nothing is recorded while the admin is signed in, so your own visits do
///   not inflate the numbers.
/// - Failures are silent: tracking must never break the site.
class VisitTracker {
  VisitTracker._();

  static const String _storageKey = 'innovista_vid';
  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]{16,64}$');

  static String? _visitorId;
  static String? _lastPath;
  static bool _referrerSent = false;

  static Future<String> _getVisitorId() async {
    final cached = _visitorId;
    if (cached != null) return cached;

    String id;

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);

      if (saved != null && _idPattern.hasMatch(saved)) {
        id = saved;
      } else {
        id = _newId();
        await prefs.setString(_storageKey, id);
      }
    } catch (_) {
      id = _newId();
    }

    _visitorId = id;
    return id;
  }

  static String _newId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();

    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  static String? _normalize(String? rawPath) {
    var path = Uri.tryParse(rawPath ?? '/')?.path ?? '/';

    if (!path.startsWith('/')) path = '/$path';
    if (path.length > 1) path = path.replaceAll(RegExp(r'/+$'), '');
    if (path.isEmpty) path = '/';

    if (path.startsWith(AppRoutes.admin) || path == AppRoutes.notFound) {
      return null;
    }

    if (path.length > 200) return null;

    return path;
  }

  static Future<void> trackPath(String? rawPath) async {
    try {
      final path = _normalize(rawPath);
      if (path == null || path == _lastPath) return;

      final client = Supabase.instance.client;

      // The signed-in admin is not a visitor.
      if (client.auth.currentSession != null) return;

      _lastPath = path;

      final id = await _getVisitorId();

      // The browser referrer belongs to the first page of the visit only.
      final referrer = _referrerSent ? '' : web.document.referrer;
      _referrerSent = true;

      await client.functions.invoke(
        'track-visit',
        body: {'visitor_id': id, 'path': path, 'referrer': referrer},
      );
    } catch (e) {
      debugPrint('Visit tracking skipped: $e');
    }
  }
}

/// Add to MaterialApp.navigatorObservers.
class VisitRouteObserver extends NavigatorObserver {
  void _track(Route<dynamic>? route) {
    // Ignore dialogs, popups, bottom sheets...
    if (route is! PageRoute) return;

    VisitTracker.trackPath(route.settings.name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _track(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _track(newRoute);
  }
}
