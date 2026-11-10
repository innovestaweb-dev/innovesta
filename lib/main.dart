import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'visit_tracker.dart';
import 'admin/admin_gate_page.dart';
import 'app_language.dart';
import 'app_routes.dart';
import 'contact_request.dart';
import 'interactive_page.dart';
import 'material_board_page.dart';
import 'portfolio_page.dart';
import 'seo/seo.dart';
import 'services_page.dart';

Future<void> main() async {
  // Real URLs (/services) instead of hash URLs (/#/services). Required for
  // search engines to index each page separately.
  usePathUrlStrategy();

  WidgetsFlutterBinding.ensureInitialized();

  // Builds the semantics (accessibility) tree from the start. On Flutter web
  // this is what exposes text, headings and links as real DOM elements that
  // crawlers can read, without waiting for the user to enable accessibility.
  SemanticsBinding.instance.ensureSemantics();

  SeoManager.init(_seoPages);

  await Supabase.initialize(
    url: 'https://grwmuajtinrytjqzmlxb.supabase.co',
    publishableKey: 'sb_publishable_1pqb_57ykYAH2LLPZawd4A_G8rAaSIq',
  );

  runApp(const FormRealApp());
}

const Color backgroundColor = Color(0xFF171717);
const Color surfaceColor = Color(0xFF222222);
const Color ivoryColor = Color(0xFFF4EFE6);
const Color bronzeColor = Color(0xFFB6A080);
const Color mutedColor = Color(0xFFAAA69F);

// -----------------------------------------------------------------------------
// SEO metadata per page (title <= ~60 chars, description <= ~160 chars).
// Review / refine the wording: it is what appears in Google results.
// -----------------------------------------------------------------------------

final List<SeoPage> _seoPages = [
  const SeoPage(
    path: AppRoutes.home,
    titleEn: 'INNOVISTA | Architectural Visualization Studio',
    titleAr: 'INNOVISTA | استوديو التصور المعماري',
    descriptionEn:
        'INNOVISTA creates realistic 3D architectural renders, cinematic '
        'animation, interactive walkthroughs and VR experiences.',
    descriptionAr:
        'استوديو INNOVISTA للتصور المعماري: ريندر ثلاثي الأبعاد واقعي، '
        'أنيميشن سينمائي، جولات تفاعلية وتجارب واقع افتراضي.',
  ),
  ServicesPage.seoPage(),
  const SeoPage(
    path: AppRoutes.portfolio,
    titleEn: 'Selected Work | INNOVISTA',
    titleAr: 'أعمالنا | INNOVISTA',
    descriptionEn:
        'Explore selected architectural visualization work by INNOVISTA: '
        'interior and exterior renders, animation and interactive experiences.',
    descriptionAr:
        'استكشف مختارات من أعمال INNOVISTA في التصور المعماري: ريندر داخلي '
        'وخارجي، أنيميشن وتجارب تفاعلية.',
  ),
  const SeoPage(
    path: AppRoutes.interactive,
    titleEn: 'Interactive Architectural Experiences | INNOVISTA',
    titleAr: 'تجارب معمارية تفاعلية | INNOVISTA',
    descriptionEn:
        'Explore architecture in real time: interactive walkthroughs with '
        'material, lighting and furniture options.',
    descriptionAr:
        'استكشف العمارة في الوقت الفعلي: جولات تفاعلية مع خيارات للخامات '
        'والإضاءة والأثاث.',
  ),
  const SeoPage(
    path: AppRoutes.contact,
    titleEn: 'Contact INNOVISTA | Start Your Project',
    titleAr: 'تواصل مع INNOVISTA | ابدأ مشروعك',
    descriptionEn:
        'Tell us about your project and request a quote for architectural '
        'visualization, animation, interactive or VR experiences.',
    descriptionAr:
        'أخبرنا عن مشروعك واطلب عرض سعر للتصور المعماري أو الأنيميشن أو '
        'التجارب التفاعلية وتجارب الواقع الافتراضي.',
  ),
  const SeoPage(
    path: AppRoutes.freeTools,
    titleEn: 'Free Material Board Tool | INNOVISTA',
    titleAr: 'أداة لوحة الخامات المجانية | INNOVISTA',
    descriptionEn:
        'Free design tool: upload a reference image, extract its colors, get '
        'material recommendations and export a material specification board.',
    descriptionAr:
        'أداة تصميم مجانية: ارفع صورة مرجعية، استخرج ألوانها، واحصل على '
        'اقتراحات للخامات وصدّر لوحة مواصفات الخامات.',
  ),
  // Private / technical pages: never indexed.
  const SeoPage(
    path: AppRoutes.admin,
    titleEn: 'Admin | INNOVISTA',
    titleAr: 'لوحة التحكم | INNOVISTA',
    descriptionEn: 'Administration area.',
    descriptionAr: 'منطقة الإدارة.',
    noIndex: true,
  ),
  const SeoPage(
    path: AppRoutes.notFound,
    titleEn: 'Page not found | INNOVISTA',
    titleAr: 'الصفحة غير موجودة | INNOVISTA',
    descriptionEn: 'The page you are looking for does not exist.',
    descriptionAr: 'الصفحة التي تبحث عنها غير موجودة.',
    noIndex: true,
  ),
];

class FormRealApp extends StatelessWidget {
  const FormRealApp({super.key});

  // Created once instead of on every rebuild (e.g. every language switch).
  static final ThemeData _theme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: const ColorScheme.dark(
      primary: bronzeColor,
      surface: backgroundColor,
    ),
    fontFamily: 'Arial',
  );

  // '/' is provided by `home`. Every public page has its own URL.
  static final Map<String, WidgetBuilder> _routes = {
    AppRoutes.services: (context) => const ServicesPage(),
    AppRoutes.portfolio: (context) => const PortfolioPage(),
    AppRoutes.interactive: (context) => const InteractivePage(),
    AppRoutes.contact: (context) => const ContactPage(),
    AppRoutes.freeTools: (context) => const MaterialBoardPage(),
    AppRoutes.admin: (context) => const AdminGatePage(),
  };

  static final List<NavigatorObserver> _observers = [
    SeoRouteObserver(),
    VisitRouteObserver(),
  ];
  @override
  Widget build(BuildContext context) {
    // Single source of truth for the language: AppLanguage.locale.
    // AppLanguage.toggle() also refreshes every open screen, so no page
    // needs its own language listener.
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLanguage.locale,
      builder: (context, locale, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: SeoConfig.defaultTitle,

          // Keeps the browser tab title equal to the current page's SEO
          // title when MaterialApp rebuilds (e.g. language switch).
          onGenerateTitle: (context) => SeoManager.currentTitle,

          locale: locale,

          supportedLocales: const [Locale('en'), Locale('ar')],

          localizationsDelegates: GlobalMaterialLocalizations.delegates,

          builder: (context, child) {
            return Directionality(
              textDirection: locale.languageCode == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: child!,
            );
          },

          theme: _theme,
          routes: _routes,
          navigatorObservers: _observers,

          onUnknownRoute: (settings) => MaterialPageRoute<void>(
            settings: const RouteSettings(name: AppRoutes.notFound),
            builder: (context) => const NotFoundPage(),
          ),

          home: const HomePage(),
        );
      },
    );
  }
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                headingLevel: 1,
                child: Text(
                  AppLanguage.text('Page not found', 'الصفحة غير موجودة'),
                  style: const TextStyle(
                    color: ivoryColor,
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.home,
                  (route) => false,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: bronzeColor,
                  foregroundColor: backgroundColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: Text(
                  AppLanguage.text('Back to home', 'العودة للرئيسية'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _servicesKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;

    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
      alignment: 0.05,
    );
  }

  void _open(String route) {
    Navigator.pushNamed(context, route);
  }

  /// Navigation entries shared by the desktop bar and the mobile menu.
  List<({String id, String label, VoidCallback onTap})> _navEntries({
    required bool includeContact,
  }) {
    return [
      (
        id: 'home',
        label: AppLanguage.text('Home', 'الرئيسية'),
        onTap: () => _scrollTo(_homeKey),
      ),
      (
        id: 'work',
        label: AppLanguage.text('Selected Work', 'أعمالنا'),
        onTap: () => _open(AppRoutes.portfolio),
      ),
      (
        id: 'interactive',
        label: AppLanguage.text('Interactive', 'التجارب التفاعلية'),
        onTap: () => _open(AppRoutes.interactive),
      ),
      (
        id: 'services',
        label: AppLanguage.text('Services', 'الخدمات'),
        onTap: () => _open(AppRoutes.services),
      ),
      if (includeContact)
        (
          id: 'contact',
          label: AppLanguage.text('Contact', 'تواصل معنا'),
          onTap: () => _scrollTo(_contactKey),
        ),
      (
        id: 'tools',
        label: AppLanguage.text('Free Tools', 'أدوات مجانية'),
        onTap: () => _open(AppRoutes.freeTools),
      ),
    ];
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 760;

        return Scaffold(
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  key: _homeKey,
                  child: Column(
                    children: [
                      _buildNavigation(isMobile),
                      _buildHero(isMobile),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Container(
                  key: _servicesKey,
                  child: _buildServices(isMobile),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  key: _contactKey,
                  child: _buildContact(isMobile),
                ),
              ),
              SliverToBoxAdapter(child: _buildFooter(isMobile)),
            ],
          ),
        );
      },
    );
  }

  // NAVIGATION
  Widget _buildNavigation(bool isMobile) {
    final entries = _navEntries(includeContact: isMobile);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 64,
        vertical: 24,
      ),
      decoration: const BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(color: Color(0xFF343434), width: 0.7),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'INNOVISTA',
                style: TextStyle(
                  color: ivoryColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLanguage.text('ARCHITECTURAL EXPERIENCES', 'تجارب معمارية'),
                style: const TextStyle(
                  color: bronzeColor,
                  fontSize: 9,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (!isMobile) ...[
            for (final entry in entries) _navItem(entry.label, entry.onTap),
            const SizedBox(width: 18),
            OutlinedButton(
              onPressed: () => _open(AppRoutes.contact),
              style: OutlinedButton.styleFrom(
                foregroundColor: ivoryColor,
                side: const BorderSide(color: bronzeColor),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              child: Text(AppLanguage.text('LET’S TALK', 'تواصل معنا')),
            ),
            TextButton(
              onPressed: AppLanguage.toggle,
              child: Text(
                AppLanguage.isArabic ? 'EN' : 'عربي',
                style: const TextStyle(color: bronzeColor, letterSpacing: 1),
              ),
            ),
          ] else
            PopupMenuButton<String>(
              tooltip: AppLanguage.text('Menu', 'القائمة'),
              color: surfaceColor,
              icon: const Icon(Icons.menu, color: ivoryColor, size: 28),
              onSelected: (value) {
                if (value == 'language') {
                  AppLanguage.toggle();
                  return;
                }

                for (final entry in entries) {
                  if (entry.id == value) {
                    entry.onTap();
                    break;
                  }
                }
              },
              itemBuilder: (context) => [
                for (final entry in entries)
                  PopupMenuItem<String>(
                    value: entry.id,
                    child: Text(
                      entry.label,
                      style: const TextStyle(color: ivoryColor),
                    ),
                  ),
                const PopupMenuDivider(),
                // The mobile menu previously had no way to switch language.
                PopupMenuItem<String>(
                  value: 'language',
                  child: Text(
                    AppLanguage.isArabic ? 'English' : 'عربي',
                    style: const TextStyle(color: bronzeColor),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _navItem(String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: mutedColor),
        child: Text(title, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  // HERO SECTION
  Widget _buildHero(bool isMobile) {
    // Soft shadow behind the hero texts so they stay readable even where the
    // photo is bright (cream walls, marble, lights).
    const List<Shadow> textShadows = [
      Shadow(color: Color(0xB3000000), blurRadius: 18),
      Shadow(color: Color(0x80000000), blurRadius: 6),
    ];

    return SizedBox(
      height: isMobile ? 680 : 700,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/home_cover.webp',
            fit: BoxFit.cover,
            // Keeps the TV wall / sofa area in view when the image is cropped.
            alignment: isMobile ? const Alignment(0.2, 0) : Alignment.center,
            // Decorative background: no alt text needed.
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) =>
                Container(color: const Color(0xFF33302C)),
          ),

          // Layer 1: horizontal dark gradient behind the text column.
          // The photo is bright, so it stays strong for longer and only
          // fades out on the far side, letting the room still show through.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: isMobile
                    ? [
                        backgroundColor.withValues(alpha: 0.82),
                        backgroundColor.withValues(alpha: 0.72),
                      ]
                    : [
                        backgroundColor.withValues(alpha: 0.95),
                        backgroundColor.withValues(alpha: 0.84),
                        backgroundColor.withValues(alpha: 0.42),
                        backgroundColor.withValues(alpha: 0.12),
                      ],
                stops: isMobile ? null : const [0.0, 0.40, 0.72, 1.0],
              ),
            ),
          ),

          // Layer 2: vertical gradient. Blends the hero into the nav bar on
          // top and the services section at the bottom, and darkens the area
          // behind the small footer label.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  backgroundColor.withValues(alpha: 0.45),
                  Colors.transparent,
                  Colors.transparent,
                  backgroundColor.withValues(alpha: 0.70),
                ],
                stops: const [0.0, 0.22, 0.70, 1.0],
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 24 : 90,
              vertical: isMobile ? 65 : 100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 38,
                      child: Divider(color: bronzeColor, thickness: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      AppLanguage.text(
                        'DESIGN  /  VISUALIZE  /  EXPERIENCE',
                        'صمّم / تصوّر / عايش التجربة',
                      ),
                      style: const TextStyle(
                        color: Color(0xFFD2B994),
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                        shadows: textShadows,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                // The page's single H1.
                Semantics(
                  header: true,
                  headingLevel: 1,
                  child: Text(
                    AppLanguage.text(
                      'Architecture,\nBeyond the Image.',
                      'العمارة،\nأبعد من مجرد صورة.',
                    ),
                    style: TextStyle(
                      color: ivoryColor,
                      fontSize: isMobile ? 44 : 76,
                      height: 1.08,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -1.5,
                      shadows: textShadows,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Text(
                    AppLanguage.text(
                      'We transform architectural ideas into '
                          'realistic visualizations and interactive '
                          'experiences that help you see the space '
                          'before it becomes reality.',
                      'نحوّل الأفكار المعمارية إلى تصورات واقعية '
                          'وتجارب تفاعلية تساعدك على رؤية المساحة '
                          'قبل أن تتحول إلى واقع.',
                    ),
                    style: const TextStyle(
                      color: Color(0xFFE6E2DA),
                      fontSize: 15,
                      height: 1.9,
                      shadows: textShadows,
                    ),
                  ),
                ),
                const SizedBox(height: 38),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    ElevatedButton(
                      onPressed: () => _open(AppRoutes.portfolio),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: bronzeColor,
                        foregroundColor: backgroundColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 21,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      child: Text(
                        AppLanguage.text('EXPLORE OUR WORK', 'استكشف أعمالنا'),
                      ),
                    ),

                    OutlinedButton(
                      onPressed: () => _open(AppRoutes.interactive),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ivoryColor,
                        backgroundColor: backgroundColor.withValues(
                          alpha: 0.35,
                        ),
                        side: const BorderSide(color: Color(0xFFD6CFC2)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 21,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      child: Text(
                        AppLanguage.text(
                          'DISCOVER INTERACTIVE',
                          'اكتشف التجارب التفاعلية',
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  AppLanguage.text(
                    'ARCHITECTURAL VISUALIZATION STUDIO',
                    'استوديو التصور المعماري',
                  ),
                  style: const TextStyle(
                    color: Color(0xFFD0C8BC),
                    fontSize: 10,
                    letterSpacing: 2.2,
                    shadows: textShadows,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // SERVICES
  Widget _buildServices(bool isMobile) {
    final services = [
      (
        '01',
        AppLanguage.text('Still Renders', 'صور ريندر ثابتة'),
        AppLanguage.text(
          'High-quality interior and exterior images '
              'for presentations and marketing.',
          'صور داخلية وخارجية عالية الجودة للعروض '
              'التقديمية والتسويق.',
        ),
      ),
      (
        '02',
        AppLanguage.text('Architectural Animation', 'الأنيميشن المعماري'),
        AppLanguage.text(
          'Cinematic walkthrough videos that communicate '
              'space, atmosphere, and design.',
          'فيديوهات تجوّل سينمائية توضّح المساحات '
              'والأجواء والتصميم.',
        ),
      ),
      (
        '03',
        AppLanguage.text('Interactive Walkthroughs', 'جولات معمارية تفاعلية'),
        AppLanguage.text(
          'Real-time experiences with navigation and '
              'selected interactive features.',
          'تجارب تفاعلية تتيح التنقل داخل المشروع '
              'واستخدام خصائص تفاعلية.',
        ),
      ),
      (
        '04',
        AppLanguage.text('VR Experiences', 'تجارب الواقع الافتراضي'),
        AppLanguage.text(
          'Immersive architectural presentations designed '
              'for supported virtual reality hardware.',
          'عروض معمارية غامرة مصممة للعمل مع أجهزة '
              'الواقع الافتراضي المدعومة.',
        ),
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 22 : 72,
        vertical: isMobile ? 70 : 100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(AppLanguage.text('WHAT WE DO', 'ماذا نقدم')),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            headingLevel: 2,
            child: Text(
              AppLanguage.text(
                'Visualization With Purpose.',
                'تصوّر معماري برؤية واضحة.',
              ),
              style: TextStyle(
                color: ivoryColor,
                fontSize: isMobile ? 31 : 45,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          const SizedBox(height: 40),
          ...services.map(
            (service) => Container(
              padding: const EdgeInsets.symmetric(vertical: 25),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF3B3935))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 45,
                    child: Text(
                      service.$1,
                      style: const TextStyle(color: bronzeColor, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          headingLevel: 3,
                          child: Text(
                            service.$2,
                            style: TextStyle(
                              color: ivoryColor,
                              fontSize: isMobile ? 19 : 25,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Text(
                            service.$3,
                            style: const TextStyle(
                              color: mutedColor,
                              fontSize: 13,
                              height: 1.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_outward, color: bronzeColor, size: 19),
                ],
              ),
            ),
          ),
          const Divider(color: Color(0xFF3B3935)),
          const SizedBox(height: 28),
          // Internal link to the full services page.
          OutlinedButton(
            onPressed: () => _open(AppRoutes.services),
            style: OutlinedButton.styleFrom(
              foregroundColor: ivoryColor,
              side: const BorderSide(color: bronzeColor),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: Text(
              AppLanguage.text('EXPLORE ALL SERVICES', 'استكشف كل الخدمات'),
            ),
          ),
        ],
      ),
    );
  }

  // CONTACT
  Widget _buildContact(bool isMobile) {
    return Container(
      color: const Color(0xFF242320),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 22 : 72,
        vertical: isMobile ? 65 : 90,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(AppLanguage.text('START A PROJECT', 'ابدأ مشروعك')),
          const SizedBox(height: 22),
          Semantics(
            header: true,
            headingLevel: 2,
            child: Text(
              AppLanguage.text(
                'Let’s Bring Your\nVision to Life.',
                'لنجعل رؤيتك\nواقعًا.',
              ),
              style: TextStyle(
                color: ivoryColor,
                fontSize: isMobile ? 42 : 65,
                height: 1.12,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            AppLanguage.text(
              'Tell us about your project and the experience '
                  'you want to create.',
              'أخبرنا عن مشروعك والتجربة التي ترغب في تقديمها.',
            ),
            style: const TextStyle(
              color: mutedColor,
              fontSize: 14,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => _open(AppRoutes.contact),
            icon: const Icon(Icons.mail_outline, size: 18),
            label: Text(AppLanguage.text('REQUEST A QUOTE', 'اطلب عرض سعر')),
            style: ElevatedButton.styleFrom(
              backgroundColor: bronzeColor,
              foregroundColor: backgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 21),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // FOOTER
  Widget _buildFooter(bool isMobile) {
    final footerTagline = Text(
      AppLanguage.text(
        'Design it. See it. Experience it.',
        'صمّمه. شاهده. عِش التجربة.',
      ),
      textAlign: isMobile ? TextAlign.start : TextAlign.center,
      style: const TextStyle(color: mutedColor, fontSize: 12),
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 22 : 72,
        vertical: 28,
      ),
      color: backgroundColor,
      child: Flex(
        direction: isMobile ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: isMobile
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          const Text(
            'INNOVISTA',
            style: TextStyle(
              color: ivoryColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          if (isMobile) const SizedBox(height: 14),
          // Expanded is only valid in the horizontal (desktop) layout; in a
          // vertical Flex inside a scroll view it would throw (unbounded height).
          if (isMobile) footerTagline else Expanded(child: footerTagline),
          if (isMobile) const SizedBox(height: 10),
          Text(
            '© ${DateTime.now().year} INNOVISTA',
            style: const TextStyle(color: mutedColor, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: bronzeColor,
        fontSize: 11,
        letterSpacing: 2.2,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
