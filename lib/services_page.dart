import 'package:flutter/material.dart';

import 'app_language.dart';
import 'app_routes.dart';
import 'seo/seo.dart';

// -----------------------------------------------------------------------------
// INNOVISTA SERVICES PAGE
// Route: /services  (registered in main.dart)
//
// SEO notes
//  - Metadata (title, description, canonical, Open Graph, JSON-LD) is applied
//    per route by SeoManager, see ServicesPage.seoPage().
//  - One H1 (hero), H2 per section, H3 per service / step, via Semantics
//    headingLevel so the semantics tree exposes a real heading structure.
//  - All content text is real text (not baked into images), images have
//    descriptive alt text, and fixed image heights avoid layout shift.
// -----------------------------------------------------------------------------

const Color _background = Color(0xFF171717);
const Color _surface = Color(0xFF20201E);
const Color _ivory = Color(0xFFF4EFE6);
const Color _bronze = Color(0xFFB6A080);
const Color _muted = Color(0xFFAAA69F);
const Color _divider = Color(0xFF3B3935);
const Color _placeholder = Color(0xFF292723);

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  /// Page metadata used by SeoManager (title, description, structured data).
  static SeoPage seoPage() {
    return SeoPage(
      path: AppRoutes.services,
      titleEn: 'Architectural Visualization Services | INNOVISTA',
      titleAr: 'خدمات التصور المعماري | INNOVISTA',
      descriptionEn:
          '3D architectural renders, cinematic animation, real-time interactive '
          'walkthroughs and VR experiences for architects, developers and '
          'interior design studios.',
      descriptionAr:
          'ريندر معماري ثلاثي الأبعاد، أنيميشن سينمائي، جولات تفاعلية في '
          'الوقت الفعلي وتجارب واقع افتراضي للمعماريين والمطورين '
          'واستوديوهات التصميم الداخلي.',
      jsonLd: () {
        final pageUrl = SeoConfig.url(AppRoutes.services);

        return [
          SeoSchema.breadcrumb([
            (name: AppLanguage.text('Home', 'الرئيسية'), path: AppRoutes.home),
            (
              name: AppLanguage.text('Services', 'الخدمات'),
              path: AppRoutes.services,
            ),
          ]),
          for (final service in _serviceData())
            SeoSchema.service(
              name: service.title,
              description: service.description,
              pageUrl: pageUrl,
            ),
          SeoSchema.faq([
            for (final item in _faqData())
              (question: item.question, answer: item.answer),
          ]),
        ];
      },
    );
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION HELPERS
  // ---------------------------------------------------------------------------

  void _go(BuildContext context, String route) {
    if (route == AppRoutes.services) return; // already here

    if (route == AppRoutes.home) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
      return;
    }

    Navigator.pushNamed(context, route);
  }

  List<({String label, String route})> _links() {
    return [
      (label: AppLanguage.text('Home', 'الرئيسية'), route: AppRoutes.home),
      (
        label: AppLanguage.text('Selected Work', 'أعمالنا'),
        route: AppRoutes.portfolio,
      ),
      (
        label: AppLanguage.text('Interactive', 'التجارب التفاعلية'),
        route: AppRoutes.interactive,
      ),
      (
        label: AppLanguage.text('Services', 'الخدمات'),
        route: AppRoutes.services,
      ),
      (
        label: AppLanguage.text('Free Tools', 'أدوات مجانية'),
        route: AppRoutes.freeTools,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 760;

        return Scaffold(
          backgroundColor: _background,
          body: SelectionArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildNavigation(context, isMobile)),
                SliverToBoxAdapter(child: _buildHero(context, isMobile)),
                SliverToBoxAdapter(child: _buildServices(isMobile)),
                SliverToBoxAdapter(
                  child: _buildInteractiveExperience(context, isMobile),
                ),
                SliverToBoxAdapter(child: _buildProcess(isMobile)),
                SliverToBoxAdapter(child: _buildComparison(isMobile)),
                SliverToBoxAdapter(child: _buildAudience(isMobile)),
                SliverToBoxAdapter(child: _buildFaq(context, isMobile)),
                SliverToBoxAdapter(child: _buildFinalCta(context, isMobile)),
                SliverToBoxAdapter(child: _buildFooter(context, isMobile)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

  Widget _buildNavigation(BuildContext context, bool isMobile) {
    final links = _links();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 22 : 72,
        vertical: 22,
      ),
      decoration: const BoxDecoration(
        color: _background,
        border: Border(bottom: BorderSide(color: _divider, width: 0.7)),
      ),
      child: Row(
        children: [
          Semantics(
            link: true,
            label: AppLanguage.text('INNOVISTA home', 'INNOVISTA الرئيسية'),
            excludeSemantics: true,
            child: InkWell(
              onTap: () => _go(context, AppRoutes.home),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INNOVISTA',
                    style: TextStyle(
                      color: _ivory,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLanguage.text(
                      'ARCHITECTURAL EXPERIENCES',
                      'تجارب معمارية',
                    ),
                    style: const TextStyle(
                      color: _bronze,
                      fontSize: 9,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Pushes the navigation to the far end of the bar.
          const Spacer(),
          if (!isMobile) ...[
            for (final link in links)
              _navigationLink(
                link.label,
                () => _go(context, link.route),
                active: link.route == AppRoutes.services,
              ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => _go(context, AppRoutes.contact),
              style: OutlinedButton.styleFrom(
                foregroundColor: _ivory,
                side: const BorderSide(color: _bronze),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 17,
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
                style: const TextStyle(color: _bronze),
              ),
            ),
          ] else
            PopupMenuButton<String>(
              tooltip: AppLanguage.text('Menu', 'القائمة'),
              color: const Color(0xFF292723),
              icon: const Icon(Icons.menu, color: _ivory, size: 28),
              onSelected: (value) {
                if (value == 'language') {
                  AppLanguage.toggle();
                  return;
                }

                _go(context, value);
              },
              itemBuilder: (context) => [
                for (final link in links)
                  PopupMenuItem<String>(
                    value: link.route,
                    child: Text(
                      link.label,
                      style: TextStyle(
                        color: link.route == AppRoutes.services
                            ? _bronze
                            : _ivory,
                      ),
                    ),
                  ),
                PopupMenuItem<String>(
                  value: AppRoutes.contact,
                  child: Text(
                    AppLanguage.text('Contact', 'تواصل معنا'),
                    style: const TextStyle(color: _ivory),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'language',
                  child: Text(
                    AppLanguage.isArabic ? 'English' : 'عربي',
                    style: const TextStyle(color: _bronze),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _navigationLink(
    String label,
    VoidCallback onTap, {
    bool active = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Semantics(
        selected: active,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: active ? _bronze : _muted,
          ),
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HERO  (the only H1 of the page)
  // ---------------------------------------------------------------------------

  Widget _buildHero(BuildContext context, bool isMobile) {
    // Height follows the content (min height only), so text can never
    // overflow on small screens or with larger font settings.
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: isMobile ? 510 : 590),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: _placeholder,
              child: Image.network(
                'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c'
                '?auto=format&fit=crop&w=1800&q=80',
                fit: BoxFit.cover,
                // Decorative background: no alt text needed.
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [
                    _background.withValues(alpha: 0.96),
                    _background.withValues(alpha: 0.72),
                    _background.withValues(alpha: 0.15),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 24 : 90,
              vertical: isMobile ? 65 : 100,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _eyebrow(AppLanguage.text('OUR SERVICES', 'خدماتنا')),
                const SizedBox(height: 30),
                _heading(
                  AppLanguage.text(
                    'Architectural Visualization,\nBeyond Expectations.',
                    'التصور المعماري،\nبما يتجاوز التوقعات.',
                  ),
                  isMobile ? 39 : 68,
                  level: 1,
                ),
                const SizedBox(height: 25),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 570),
                  child: Text(
                    AppLanguage.text(
                      'From photorealistic architectural images to '
                          'real-time interactive environments, we create '
                          'visual experiences that help you communicate '
                          'design with clarity and confidence.',
                      'من الصور المعمارية الواقعية إلى البيئات '
                          'التفاعلية في الوقت الفعلي، نصنع تجارب بصرية '
                          'تساعدك على تقديم التصميم بوضوح وثقة.',
                    ),
                    style: const TextStyle(
                      color: Color(0xFFD0CCC5),
                      fontSize: 15,
                      height: 1.9,
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _primaryButton(
                      AppLanguage.text('START A PROJECT', 'ابدأ مشروعك'),
                      () => _go(context, AppRoutes.contact),
                    ),
                    _outlineButton(
                      AppLanguage.text('EXPLORE OUR WORK', 'استكشف أعمالنا'),
                      () => _go(context, AppRoutes.portfolio),
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                Text(
                  AppLanguage.text(
                    'DESIGN  /  VISUALIZE  /  EXPERIENCE',
                    'صمّم  /  تصوّر  /  عِش التجربة',
                  ),
                  style: const TextStyle(
                    color: _bronze,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SERVICES OVERVIEW  (H2 + one H3 per service)
  // ---------------------------------------------------------------------------

  Widget _buildServices(bool isMobile) {
    final services = _serviceData();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 22 : 72,
        isMobile ? 70 : 100,
        isMobile ? 22 : 72,
        isMobile ? 50 : 75,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow(AppLanguage.text('WHAT WE OFFER', 'ماذا نقدم')),
          const SizedBox(height: 18),
          _heading(
            AppLanguage.text(
              'Visual Solutions for Every Stage of Design.',
              'حلول بصرية لكل مرحلة من مراحل التصميم.',
            ),
            isMobile ? 30 : 45,
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Text(
              AppLanguage.text(
                'Choose the right way to present, communicate, '
                    'and explore your architectural project.',
                'اختر الطريقة المناسبة لعرض مشروعك المعماري '
                    'وتقديمه واستكشافه.',
              ),
              style: const TextStyle(color: _muted, fontSize: 14, height: 1.9),
            ),
          ),
          const SizedBox(height: 45),
          for (int i = 0; i < services.length; i++)
            _buildServiceItem(
              services[i],
              isMobile: isMobile,
              imageFirst: i.isEven,
              isLast: i == services.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildServiceItem(
    _ServiceData service, {
    required bool isMobile,
    required bool imageFirst,
    required bool isLast,
  }) {
    final image = _photo(
      service.image,
      height: isMobile ? 245 : 365,
      alt: service.alt,
    );

    final details = _serviceDetails(service, isMobile: isMobile);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : (isMobile ? 42 : 65)),
      child: Column(
        children: [
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [image, const SizedBox(height: 24), details],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: imageFirst
                  ? [
                      Expanded(flex: 11, child: image),
                      Expanded(flex: 10, child: details),
                    ]
                  : [
                      Expanded(flex: 10, child: details),
                      Expanded(flex: 11, child: image),
                    ],
            ),
          const SizedBox(height: 35),
          const Divider(color: _divider, height: 1),
        ],
      ),
    );
  }

  Widget _serviceDetails(_ServiceData service, {required bool isMobile}) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: isMobile ? 0 : 45,
        end: isMobile ? 0 : 25,
        top: isMobile ? 0 : 10,
        bottom: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${service.number}  /  ${service.category}',
            style: const TextStyle(
              color: _bronze,
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          _heading(service.title, isMobile ? 25 : 32, level: 3),
          const SizedBox(height: 17),
          Text(
            service.description,
            style: const TextStyle(color: _muted, fontSize: 13, height: 1.9),
          ),
          const SizedBox(height: 22),
          for (final feature in service.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: _bronze,
                      // Decorative bullet.
                      semanticLabel: null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(
                        color: Color(0xFFD5D0C7),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INTERACTIVE EXPERIENCE
  // ---------------------------------------------------------------------------

  Widget _buildInteractiveExperience(BuildContext context, bool isMobile) {
    final imageHeight = isMobile ? 260.0 : 480.0;

    return Container(
      width: double.infinity,
      color: _surface,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 22 : 72,
        vertical: isMobile ? 70 : 100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow(AppLanguage.text('A DIFFERENT EXPERIENCE', 'تجربة مختلفة')),
          const SizedBox(height: 20),
          _heading(
            AppLanguage.text(
              'Don’t Just Look at the Design.\nExperience It.',
              'لا تكتفِ بمشاهدة التصميم.\nعِش التجربة.',
            ),
            isMobile ? 32 : 53,
          ),
          const SizedBox(height: 30),
          Stack(
            children: [
              _photo(
                'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c'
                '?auto=format&fit=crop&w=1600&q=80',
                height: imageHeight,
                alt: AppLanguage.text(
                  'Modern architectural interior visualization',
                  'تصور معماري لمساحة داخلية حديثة',
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                start: 22,
                end: 22,
                bottom: 22,
                child: Text(
                  AppLanguage.text(
                    'Explore architecture in real time.',
                    'استكشف العمارة في الوقت الفعلي.',
                  ),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 18 : 25,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Text(
              AppLanguage.text(
                'An interactive experience gives clients more than '
                    'a visual presentation. It gives them the freedom '
                    'to explore spaces and understand design choices '
                    'before execution.',
                'التجربة التفاعلية تمنح العميل أكثر من مجرد عرض بصري؛ '
                    'إنها تمنحه حرية استكشاف المساحات وفهم اختيارات '
                    'التصميم قبل التنفيذ.',
              ),
              style: const TextStyle(color: _muted, fontSize: 14, height: 1.9),
            ),
          ),
          const SizedBox(height: 30),
          Wrap(
            spacing: 28,
            runSpacing: 20,
            children: [
              _featureItem(
                Icons.explore_outlined,
                AppLanguage.text('Explore Spaces', 'استكشف المساحات'),
                isMobile,
              ),
              _featureItem(
                Icons.texture_outlined,
                AppLanguage.text('Change Materials', 'غيّر الخامات'),
                isMobile,
              ),
              _featureItem(
                Icons.light_mode_outlined,
                AppLanguage.text('Control Lighting', 'تحكم في الإضاءة'),
                isMobile,
              ),
              _featureItem(
                Icons.chair_outlined,
                AppLanguage.text('Customize Furniture', 'غيّر الأثاث'),
                isMobile,
              ),
              _featureItem(
                Icons.layers_outlined,
                AppLanguage.text('Navigate Floors', 'تنقل بين الطوابق'),
                isMobile,
              ),
            ],
          ),
          const SizedBox(height: 35),
          _outlineButton(
            AppLanguage.text(
              'EXPLORE INTERACTIVE PROJECTS',
              'استكشف المشاريع التفاعلية',
            ),
            () => _go(context, AppRoutes.interactive),
            icon: Icons.arrow_outward,
          ),
        ],
      ),
    );
  }

  Widget _featureItem(IconData icon, String title, bool isMobile) {
    return SizedBox(
      width: isMobile ? 150 : 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _bronze, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: _ivory, fontSize: 12, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PROCESS
  // ---------------------------------------------------------------------------

  Widget _buildProcess(bool isMobile) {
    final steps = [
      (
        '01',
        AppLanguage.text('Project Brief', 'تفاصيل المشروع'),
        AppLanguage.text(
          'We understand your project, requirements, and goals.',
          'نفهم مشروعك واحتياجاتك والأهداف المطلوبة.',
        ),
      ),
      (
        '02',
        AppLanguage.text('Preparation', 'التجهيز'),
        AppLanguage.text(
          'We prepare the 3D model, materials, and visual direction.',
          'نجهز النموذج ثلاثي الأبعاد والخامات والاتجاه البصري.',
        ),
      ),
      (
        '03',
        AppLanguage.text('Production', 'التنفيذ'),
        AppLanguage.text(
          'We produce the agreed visual or interactive experience.',
          'ننفّذ الصور أو الفيديو أو التجربة التفاعلية المتفق عليها.',
        ),
      ),
      (
        '04',
        AppLanguage.text('Review', 'المراجعة'),
        AppLanguage.text(
          'We review the result and apply the agreed refinements.',
          'نراجع النتائج وننفذ التعديلات المتفق عليها.',
        ),
      ),
      (
        '05',
        AppLanguage.text('Delivery', 'التسليم'),
        AppLanguage.text(
          'Your final project is delivered in the agreed format.',
          'نسلمك المشروع النهائي بالصيغ المتفق عليها.',
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
          _eyebrow(AppLanguage.text('HOW WE WORK', 'كيف نعمل')),
          const SizedBox(height: 20),
          _heading(
            AppLanguage.text(
              'From Concept to Experience.',
              'من الفكرة إلى التجربة.',
            ),
            isMobile ? 31 : 45,
          ),
          const SizedBox(height: 40),
          for (final step in steps)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 23),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _divider)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: isMobile ? 42 : 65,
                    child: Text(
                      step.$1,
                      style: const TextStyle(color: _bronze, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _heading(step.$2, isMobile ? 17 : 21, level: 3),
                        const SizedBox(height: 8),
                        Text(
                          step.$3,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 13,
                            height: 1.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Divider(color: _divider),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SERVICE COMPARISON
  // ---------------------------------------------------------------------------

  Widget _buildComparison(bool isMobile) {
    final rows = [
      (
        AppLanguage.text('Present the design', 'عرض التصميم'),
        AppLanguage.text('3D Renders', 'ريندر ثلاثي الأبعاد'),
      ),
      (
        AppLanguage.text('Create a cinematic video', 'إنشاء فيديو سينمائي'),
        AppLanguage.text('Animation', 'أنيميشن'),
      ),
      (
        AppLanguage.text('Explore and customize', 'الاستكشاف والتخصيص'),
        AppLanguage.text('Interactive', 'تجربة تفاعلية'),
      ),
      (
        AppLanguage.text('Immersive virtual tour', 'جولة افتراضية غامرة'),
        AppLanguage.text('VR', 'واقع افتراضي'),
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 22 : 72,
        vertical: isMobile ? 65 : 90,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow(AppLanguage.text('FIND YOUR SOLUTION', 'اختر الحل المناسب')),
          const SizedBox(height: 20),
          _heading(
            AppLanguage.text(
              'What Does Your Project Need?',
              'ما الذي يحتاجه مشروعك؟',
            ),
            isMobile ? 29 : 43,
          ),
          const SizedBox(height: 30),
          for (final row in rows)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 19),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.$1,
                      style: const TextStyle(color: _muted, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    row.$2,
                    style: const TextStyle(
                      color: _bronze,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(color: _divider),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AUDIENCE
  // ---------------------------------------------------------------------------

  Widget _buildAudience(bool isMobile) {
    final audiences = [
      (
        Icons.architecture_outlined,
        AppLanguage.text('Architects & Designers', 'المهندسون والمصممون'),
      ),
      (
        Icons.apartment_outlined,
        AppLanguage.text('Real Estate Developers', 'المطورون العقاريون'),
      ),
      (
        Icons.design_services_outlined,
        AppLanguage.text(
          'Interior Design Studios',
          'استوديوهات التصميم الداخلي',
        ),
      ),
      (
        Icons.home_work_outlined,
        AppLanguage.text('Property Owners', 'أصحاب العقارات والمشروعات'),
      ),
    ];

    return Container(
      width: double.infinity,
      color: _surface,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 22 : 72,
        vertical: isMobile ? 65 : 85,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow(AppLanguage.text('WHO WE WORK WITH', 'من نخدم')),
          const SizedBox(height: 20),
          _heading(
            AppLanguage.text(
              'Built for Those Who Shape Spaces.',
              'لمن يصنعون المساحات.',
            ),
            isMobile ? 29 : 42,
          ),
          const SizedBox(height: 35),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 600 ? 1 : 2;
              final itemWidth =
                  (constraints.maxWidth - (columns - 1) * 22) / columns;

              return Wrap(
                spacing: 22,
                runSpacing: 22,
                children: [
                  for (final audience in audiences)
                    SizedBox(
                      width: itemWidth,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 22,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: _divider),
                        ),
                        child: Row(
                          children: [
                            Icon(audience.$1, color: _bronze, size: 21),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                audience.$2,
                                style: const TextStyle(
                                  color: _ivory,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FAQ
  // ---------------------------------------------------------------------------

  Widget _buildFaq(BuildContext context, bool isMobile) {
    final questions = _faqData();

    // Built once instead of once per question.
    final tileTheme = Theme.of(context).copyWith(
      dividerColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 22 : 72,
        vertical: isMobile ? 65 : 90,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow(AppLanguage.text('COMMON QUESTIONS', 'أسئلة شائعة')),
          const SizedBox(height: 20),
          _heading(
            AppLanguage.text('Frequently Asked Questions.', 'الأسئلة الشائعة.'),
            isMobile ? 29 : 43,
          ),
          const SizedBox(height: 28),
          for (final question in questions)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _divider)),
              ),
              child: Theme(
                data: tileTheme,
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  iconColor: _bronze,
                  collapsedIconColor: _bronze,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  // Keep the answers in the widget tree while collapsed.
                  maintainState: true,
                  expandedAlignment: AlignmentDirectional.centerStart,
                  childrenPadding: const EdgeInsetsDirectional.only(
                    start: 8,
                    end: 8,
                    bottom: 20,
                  ),
                  title: _heading(
                    question.question,
                    15,
                    level: 3,
                    weight: FontWeight.w400,
                  ),
                  children: [
                    Text(
                      question.answer,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        height: 1.9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(color: _divider, height: 1),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FINAL CTA
  // ---------------------------------------------------------------------------

  Widget _buildFinalCta(BuildContext context, bool isMobile) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF292723),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 22 : 72,
        vertical: isMobile ? 65 : 95,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow(
            AppLanguage.text('HAVE A PROJECT IN MIND?', 'هل لديك مشروع؟'),
          ),
          const SizedBox(height: 22),
          _heading(
            AppLanguage.text(
              'Let’s Bring Your\nVision to Life.',
              'لنجعل رؤيتك\nواقعًا.',
            ),
            isMobile ? 39 : 65,
          ),
          const SizedBox(height: 22),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 530),
            child: Text(
              AppLanguage.text(
                'Tell us about your project and let’s find the '
                    'right visualization experience for your goals.',
                'أخبرنا عن مشروعك، ودعنا نحدد تجربة التصور المعماري '
                    'الأنسب لأهدافك.',
              ),
              style: const TextStyle(color: _muted, fontSize: 14, height: 1.9),
            ),
          ),
          const SizedBox(height: 30),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _primaryButton(
                AppLanguage.text('START A PROJECT', 'ابدأ مشروعك'),
                () => _go(context, AppRoutes.contact),
              ),
              _outlineButton(
                AppLanguage.text('VIEW OUR WORK', 'شاهد أعمالنا'),
                () => _go(context, AppRoutes.portfolio),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FOOTER  (internal links help both users and crawlers)
  // ---------------------------------------------------------------------------

  Widget _buildFooter(BuildContext context, bool isMobile) {
    final links = [
      ..._links(),
      (
        label: AppLanguage.text('Contact', 'تواصل معنا'),
        route: AppRoutes.contact,
      ),
    ];

    final brand = const Text(
      'INNOVISTA',
      style: TextStyle(
        color: _ivory,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
    );

    final tagline = Text(
      AppLanguage.text(
        'Design it. See it. Experience it.',
        'صمّمه. شاهده. عِش التجربة.',
      ),
      style: const TextStyle(color: _muted, fontSize: 12),
    );

    return Container(
      color: _background,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 22 : 72,
        vertical: 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: _divider, height: 1),
          const SizedBox(height: 28),
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [brand, const SizedBox(height: 12), tagline],
            )
          else
            Row(children: [brand, const Spacer(), tagline]),
          const SizedBox(height: 22),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final link in links)
                TextButton(
                  onPressed: () => _go(context, link.route),
                  style: TextButton.styleFrom(
                    foregroundColor: _muted,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  child: Text(link.label, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '© ${DateTime.now().year} INNOVISTA',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED UI
  // ---------------------------------------------------------------------------

  Widget _eyebrow(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _bronze,
        fontSize: 11,
        letterSpacing: 2.2,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// Heading with a real heading level (H1-H3) in the semantics tree.
  Widget _heading(
    String text,
    double size, {
    int level = 2,
    FontWeight weight = FontWeight.w300,
  }) {
    return Semantics(
      header: true,
      headingLevel: level,
      child: Text(
        text,
        style: TextStyle(
          color: _ivory,
          fontSize: size,
          height: 1.16,
          fontWeight: weight,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  /// Photo with fixed size (no layout shift), placeholder color, a soft
  /// fade-in, alt text for accessibility / SEO and a fallback on error.
  Widget _photo(String url, {required double height, required String alt}) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ColoredBox(
        color: _placeholder,
        child: Image.network(
          url,
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
          semanticLabel: alt,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;

            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOut,
              child: child,
            );
          },
          errorBuilder: (_, _, _) => const Center(
            child: Icon(Icons.image_outlined, color: _bronze, size: 35),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _bronze,
        foregroundColor: _background,
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 21),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      child: Text(label),
    );
  }

  Widget _outlineButton(
    String label,
    VoidCallback onPressed, {
    IconData? icon,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _ivory,
        side: const BorderSide(color: _bronze),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (icon != null) ...[
            const SizedBox(width: 10),
            Icon(icon, size: 16),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// CONTENT
// One source of truth, used by BOTH the visible page and the JSON-LD
// structured data, so what search engines read always matches what users see.
// -----------------------------------------------------------------------------

List<_ServiceData> _serviceData() {
  return [
    _ServiceData(
      number: '01',
      category: AppLanguage.text('STILL IMAGERY', 'الصور الثابتة'),
      title: AppLanguage.text(
        '3D Architectural Visualization',
        'التصور المعماري ثلاثي الأبعاد',
      ),
      description: AppLanguage.text(
        'Transform architectural drawings and concepts into '
            'realistic interior and exterior images. Every material, '
            'surface, and lighting detail is carefully presented '
            'to help communicate the design.',
        'نحوّل المخططات والأفكار المعمارية إلى صور داخلية وخارجية '
            'واقعية. نهتم بتفاصيل الخامات والأسطح والإضاءة لتقديم '
            'التصميم بصورة واضحة ومقنعة.',
      ),
      features: [
        AppLanguage.text('Interior & Exterior Renders', 'ريندر داخلي وخارجي'),
        AppLanguage.text('Realistic Materials', 'خامات واقعية'),
        AppLanguage.text('Lighting & Atmosphere', 'الإضاءة والأجواء'),
        AppLanguage.text('High-resolution Images', 'صور عالية الجودة'),
      ],
      image:
          'https://images.unsplash.com/photo-1600210492486-724fe5c67fb0'
          '?auto=format&fit=crop&w=1200&q=80',
      alt: AppLanguage.text(
        'Photorealistic modern interior architectural visualization',
        'تصور معماري واقعي لتصميم داخلي حديث',
      ),
    ),
    _ServiceData(
      number: '02',
      category: AppLanguage.text(
        'REAL-TIME EXPERIENCE',
        'تجربة تفاعلية مباشرة',
      ),
      title: AppLanguage.text(
        'Interactive Architectural Visualization',
        'التصور المعماري التفاعلي',
      ),
      description: AppLanguage.text(
        'Go beyond traditional renders. Explore your project in '
            'real time, move through spaces, compare materials, '
            'adjust lighting, and experience different design options '
            'inside an interactive environment.',
        'تجاوز الصور التقليدية واستكشف مشروعك في الوقت الفعلي. '
            'تنقّل بين المساحات، وقارن الخامات، وتحكّم في الإضاءة، '
            'واستكشف اختيارات التصميم داخل بيئة تفاعلية.',
      ),
      features: [
        AppLanguage.text('Real-time Walkthrough', 'جولات تفاعلية مباشرة'),
        AppLanguage.text('Material Customization', 'تغيير الخامات'),
        AppLanguage.text('Lighting Control', 'التحكم في الإضاءة'),
        AppLanguage.text('Multi-floor Navigation', 'التنقل بين الطوابق'),
      ],
      image:
          'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c'
          '?auto=format&fit=crop&w=1200&q=80',
      alt: AppLanguage.text(
        'Modern architectural space for interactive visualization',
        'مساحة معمارية حديثة للتصور التفاعلي',
      ),
    ),
    _ServiceData(
      number: '03',
      category: AppLanguage.text('CINEMATIC MOTION', 'الحركة السينمائية'),
      title: AppLanguage.text('Architectural Animation', 'الأنيميشن المعماري'),
      description: AppLanguage.text(
        'Present your project through cinematic camera movement '
            'and carefully composed scenes. Architectural animation '
            'helps communicate the atmosphere, scale, and character '
            'of a space.',
        'اعرض مشروعك من خلال حركة كاميرا سينمائية ومشاهد مدروسة. '
            'يساعد الأنيميشن المعماري على توضيح أجواء المساحات '
            'وأبعادها وطابعها التصميمي.',
      ),
      features: [
        AppLanguage.text('Interior Walkthroughs', 'جولات داخلية'),
        AppLanguage.text('Exterior Animation', 'أنيميشن خارجي'),
        AppLanguage.text('Cinematic Camera Movement', 'حركة كاميرا سينمائية'),
        AppLanguage.text('Day & Night Scenes', 'مشاهد نهارية وليلية'),
      ],
      image:
          'https://images.unsplash.com/photo-1600607687920-4e2a09cf159d'
          '?auto=format&fit=crop&w=1200&q=80',
      alt: AppLanguage.text(
        'Contemporary interior architecture for cinematic presentation',
        'تصميم داخلي معاصر للعرض المعماري السينمائي',
      ),
    ),
    _ServiceData(
      number: '04',
      category: AppLanguage.text('IMMERSIVE EXPERIENCE', 'تجربة غامرة'),
      title: AppLanguage.text(
        'VR Architectural Experiences',
        'تجارب الواقع الافتراضي المعماري',
      ),
      description: AppLanguage.text(
        'Take architectural visualization into an immersive '
            'environment. Let clients experience spaces at a more '
            'personal scale using supported virtual reality devices.',
        'انقل التصور المعماري إلى بيئة افتراضية غامرة، وامنح '
            'العملاء فرصة استكشاف المساحات بصورة أقرب إلى التجربة '
            'الحقيقية باستخدام أجهزة الواقع الافتراضي المدعومة.',
      ),
      features: [
        AppLanguage.text('Immersive Property Tours', 'جولات عقارية غامرة'),
        AppLanguage.text(
          'VR-ready Environments',
          'بيئات مجهزة للواقع الافتراضي',
        ),
        AppLanguage.text('Spatial Exploration', 'استكشاف المساحات'),
        AppLanguage.text('Supported VR Devices', 'أجهزة VR المدعومة'),
      ],
      image:
          'https://images.unsplash.com/photo-1593508512255-86ab42a8e620'
          '?auto=format&fit=crop&w=1200&q=80',
      alt: AppLanguage.text(
        'Virtual reality headset for immersive architectural experiences',
        'نظارة واقع افتراضي لتجارب معمارية غامرة',
      ),
    ),
  ];
}

List<_FaqData> _faqData() {
  return [
    _FaqData(
      question: AppLanguage.text(
        'What do you need to start a project?',
        'ما المطلوب لبدء المشروع؟',
      ),
      answer: AppLanguage.text(
        'Architectural drawings, dimensions, reference images, '
            'and a description of your goals are helpful. If some '
            'details are not available, we can discuss the best way '
            'to proceed.',
        'يفضل توفير المخططات المعمارية والأبعاد والصور المرجعية '
            'ووصف أهداف المشروع. وإذا لم تكن كل التفاصيل متاحة، '
            'يمكننا مناقشة أنسب طريقة للبدء.',
      ),
    ),
    _FaqData(
      question: AppLanguage.text(
        'Can I request changes during production?',
        'هل يمكن طلب تعديلات أثناء التنفيذ؟',
      ),
      answer: AppLanguage.text(
        'Yes. Review stages and the number of included revisions '
            'are agreed upon before production begins.',
        'نعم. يتم الاتفاق مسبقًا على مراحل المراجعة وعدد التعديلات '
            'المشمولة قبل بدء التنفيذ.',
      ),
    ),
    _FaqData(
      question: AppLanguage.text(
        'Can interactive projects run on a PC?',
        'هل يمكن تشغيل المشاريع التفاعلية على الكمبيوتر؟',
      ),
      answer: AppLanguage.text(
        'Interactive projects can be prepared for supported PC '
            'hardware. Requirements depend on the project and the '
            'final delivery format.',
        'يمكن تجهيز المشاريع التفاعلية للعمل على أجهزة الكمبيوتر '
            'المتوافقة. وتعتمد المتطلبات على المشروع وصيغة التسليم.',
      ),
    ),
    _FaqData(
      question: AppLanguage.text(
        'Do you provide VR experiences?',
        'هل تقدمون تجارب واقع افتراضي؟',
      ),
      answer: AppLanguage.text(
        'VR delivery can be discussed based on the target headset, '
            'project requirements, and technical compatibility.',
        'يمكن الاتفاق على تسليم تجربة واقع افتراضي وفقًا لنوع النظارة '
            'ومتطلبات المشروع والتوافق التقني.',
      ),
    ),
    _FaqData(
      question: AppLanguage.text(
        'Do you work with clients outside Egypt?',
        'هل تعملون مع عملاء خارج مصر؟',
      ),
      answer: AppLanguage.text(
        'Yes. Project details and files can be shared remotely, '
            'allowing us to work with clients in different locations.',
        'نعم. يمكن مشاركة تفاصيل المشروع وملفاته عن بُعد، '
            'مما يتيح العمل مع العملاء في أماكن مختلفة.',
      ),
    ),
  ];
}

class _ServiceData {
  final String number;
  final String category;
  final String title;
  final String description;
  final List<String> features;
  final String image;
  final String alt;

  const _ServiceData({
    required this.number,
    required this.category,
    required this.title,
    required this.description,
    required this.features,
    required this.image,
    required this.alt,
  });
}

class _FaqData {
  final String question;
  final String answer;

  const _FaqData({required this.question, required this.answer});
}
