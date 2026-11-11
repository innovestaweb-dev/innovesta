import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

import 'app_language.dart';

// -----------------------------------------------------------------------------
// hCaptcha bridge (implemented in web/hcaptcha_bridge.js)
// -----------------------------------------------------------------------------

@JS('innovistaCaptcha.render')
external void renderInnovistaCaptcha(web.HTMLDivElement element);

@JS('innovistaCaptcha.getToken')
external String getInnovistaCaptchaToken();

@JS('innovistaCaptcha.reset')
external void resetInnovistaCaptcha();

const Color bgColor = Color(0xFF171717);
const Color cardColor = Color(0xFF202020);
const Color ivory = Color(0xFFF4EFE6);
const Color bronze = Color(0xFFB6A080);
const Color muted = Color(0xFFAAA69F);

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  static const String _whatsAppNumber = '201203450806';

  final _formKey = GlobalKey<FormState>();
  final _captchaKey = GlobalKey();

  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _provinceController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _referencesController = TextEditingController();
  final _budgetController = TextEditingController();
  final _notesController = TextEditingController();

  String? _projectType;
  String? _projectStage;
  String? _area;
  String? _timeline;
  String? _mood;
  String _preferredContact = 'WhatsApp';
  String? _selectedCountry;
  String? _selectedCurrency;

  bool _isSubmitting = false;
  bool _showCaptcha = false;

  /// Changing this value rebuilds every form field from scratch
  /// (used to fully reset the form after a successful submission).
  int _formVersion = 0;

  final Set<String> _services = {};
  final Set<String> _styles = {};

  static const List<String> _serviceOptions = [
    'Interior Still Renders',
    'Exterior Still Renders',
    'Architectural Animation',
    'Interactive Walkthrough',
    'VR Experience',
  ];

  static const List<String> _styleOptions = [
    'Modern',
    'Minimalist',
    'Luxury',
    'Classic',
    'Neoclassical',
    'Contemporary',
    'Industrial',
    'Not sure yet',
  ];

  static const Map<String, String> _ar = {
    'INNOVISTA': 'INNOVISTA',
    'BACK': 'رجوع',
    'PROJECT INQUIRY / 2026': 'طلب مشروع / 2026',
    'LET’S CREATE SOMETHING EXCEPTIONAL': 'لنصنع شيئًا استثنائيًا',
    'Tell Us About Your Project.': 'أخبرنا عن مشروعك.',
    'Every great space starts with an idea. Share your vision with INNOVISTA, and let’s explore how we can bring it to life.': 'كل مساحة مميزة تبدأ بفكرة. شارك رؤيتك مع INNOVISTA، ودعنا نستكشف كيف يمكننا تحويلها إلى واقع.',
    'QUICK INQUIRY VIA WHATSAPP': 'تواصل معنا مباشرة عبر واتساب',
    'Prefer a more detailed approach?': 'تفضل توضيح تفاصيل مشروعك؟',
    'Share your project details through our inquiry form to help us better understand your vision, requirements, and expectations — so we can prepare a more tailored response for you.': 'شاركنا متطلباتك ورؤيتك من خلال نموذج الطلب، لنتمكن من فهم احتياجاتك بشكل أفضل وتقديم رد وحلول أكثر ملاءمة لمشروعك.',
    'Your Information': 'بيانات التواصل',
    'Tell us how to reach you about your project.':
        'أخبرنا كيف يمكننا التواصل معك بخصوص مشروعك.',
    'Full Name *': 'الاسم بالكامل *',
    'Enter your full name': 'اكتب اسمك بالكامل',
    'Company / Studio Name': 'اسم الشركة أو الاستوديو',
    'Company or studio name (optional)': 'اسم الشركة أو الاستوديو (اختياري)',
    'Country *': 'الدولة *',
    'Governorate / Province *': 'المحافظة / الولاية *',
    'Enter your governorate or province': 'اكتب اسم المحافظة أو الولاية',
    'WhatsApp Number *': 'رقم واتساب *',
    'Email Address *': 'البريد الإلكتروني *',
    'Preferred Contact Method': 'وسيلة التواصل المفضلة',
    'WhatsApp': 'واتساب',
    'Email': 'البريد الإلكتروني',
    'Phone': 'الهاتف',
    'Project Brief': 'تفاصيل المشروع',
    'Help us understand the scope and requirements.':
        'ساعدنا على فهم نطاق المشروع ومتطلباته.',
    'Project Type *': 'نوع المشروع *',
    'Project Stage *': 'مرحلة المشروع *',
    'Approximate Area *': 'المساحة التقريبية *',
    'Expected Timeline *': 'الجدول الزمني المتوقع *',
    'Services Required *': 'الخدمات المطلوبة *',
    'Select the services you need.': 'اختر الخدمات التي تحتاج إليها.',
    'Project Description *': 'وصف المشروع *',
    'Describe your project, goals, and requirements...':
        'صف مشروعك وأهدافه ومتطلباته...',
    'Design Direction': 'التوجه التصميمي',
    'Tell us about the look, feel, and atmosphere you want to achieve.':
        'أخبرنا عن الشكل والطابع والأجواء التي ترغب في تحقيقها.',
    'Preferred Design Style': 'الطراز التصميمي المفضل',
    'Overall Mood': 'الأجواء العامة',
    'Reference Links': 'روابط مرجعية',
    'Add links to Pinterest, images, or inspiration...':
        'أضف روابط Pinterest أو الصور أو المراجع الملهمة...',
    'Tip: You can share reference images or links to help us understand your vision.':
        'نصيحة: يمكنك مشاركة صور أو روابط مرجعية لمساعدتنا على فهم رؤيتك.',
    'Budget & Additional Notes': 'الميزانية وملاحظات إضافية',
    'Optional details that help us plan the right solution for you.':
        'تفاصيل اختيارية تساعدنا على تحديد الحل المناسب لك.',
    'Estimated Visualization Budget':
        'الميزانية التقديرية لخدمات التصور المعماري',
    'Additional Notes': 'ملاحظات إضافية',
    'Anything else we should know?': 'هل هناك أي تفاصيل أخرى تود إخبارنا بها؟',
    'SUBMIT PROJECT BRIEF': 'إرسال تفاصيل المشروع',
    'This field is required': 'هذا الحقل مطلوب',
    'Please select an option': 'يرجى اختيار أحد الخيارات',
    'Please complete the required fields.': 'يرجى استكمال الحقول المطلوبة.',
    'Please select at least one service.': 'يرجى اختيار خدمة واحدة على الأقل.',
    'Please enter a valid email address.': 'يرجى إدخال بريد إلكتروني صحيح.',
    'Please enter a valid phone number.': 'يرجى إدخال رقم هاتف صحيح.',
    'Verify that you are human': 'تحقق من أنك لست روبوتًا',
    'Please complete the CAPTCHA below, then press submit again.':
        'أكمل التحقق بالأسفل ثم اضغط إرسال مرة أخرى.',
    'Please complete the CAPTCHA verification.':
        'يرجى إكمال التحقق من أنك لست روبوتًا.',
    'Sending your request...': 'جارٍ إرسال طلبك...',
    'Your project request has been sent successfully.':
        'تم إرسال طلب مشروعك بنجاح.',
    'We could not send your request. Please try again.':
        'تعذر إرسال طلبك. حاول مرة أخرى.',
    'Could not open WhatsApp.': 'تعذر فتح واتساب.',
    'By submitting this form you agree that INNOVISTA may use your details to respond to your request.': 'بإرسال هذا النموذج فأنت توافق على استخدام INNOVISTA لبياناتك للرد على طلبك.',
    'Villa / Residential': 'فيلا / سكني',
    'Apartment': 'شقة',
    'Commercial / Retail': 'تجاري / متجر',
    'Office': 'مكتب',
    'Hospitality': 'ضيافة / فندقي',
    'Landscape': 'تنسيق موقع خارجي',
    'Other': 'أخرى',
    'Concept Design': 'التصميم المبدئي',
    'Design Development': 'تطوير التصميم',
    'Ready for Visualization': 'جاهز للتصور ثلاثي الأبعاد',
    'Under Construction': 'قيد التنفيذ',
    'Existing Space Renovation': 'تجديد مساحة قائمة',
    'Under 100 m²': 'أقل من 100 م²',
    '100–250 m²': '100–250 م²',
    '250–500 m²': '250–500 م²',
    '500–1,000 m²': '500–1,000 م²',
    'Over 1,000 m²': 'أكثر من 1,000 م²',
    'Not determined': 'لم تُحدد بعد',
    'As soon as possible': 'في أقرب وقت ممكن',
    'Within 2 weeks': 'خلال أسبوعين',
    'Within a month': 'خلال شهر',
    'Flexible': 'مرن',
    'Interior Still Renders': 'صور ريندر داخلي',
    'Exterior Still Renders': 'صور ريندر خارجي',
    'Architectural Animation': 'أنيميشن معماري',
    'Interactive Walkthrough': 'جولة معمارية تفاعلية',
    'VR Experience': 'تجربة واقع افتراضي VR',
    'Modern': 'مودرن',
    'Minimalist': 'بسيط',
    'Luxury': 'فاخر',
    'Classic': 'كلاسيكي',
    'Neoclassical': 'نيو كلاسيك',
    'Contemporary': 'معاصر',
    'Industrial': 'صناعي',
    'Not sure yet': 'لم أحدد بعد',
    'Warm & Inviting': 'دافئة ومرحّبة',
    'Luxury & Sophisticated': 'فاخرة وراقية',
    'Minimal & Calm': 'هادئة وبسيطة',
    'Bright & Natural': 'مشرقة وطبيعية',
    'Dark & Dramatic': 'داكنة ودرامية',
    'Bold & Contemporary': 'جريئة ومعاصرة',
    'e.g.  \$5,000 –  \$10,000': 'مثال: 5,000 – 10,000 دولار',
    'INNOVISTA | Architectural Visualization': 'INNOVISTA | التصور المعماري',
    'We turn architectural ideas into visual experiences.':
        'نحوّل الأفكار المعمارية إلى تجارب بصرية.',
  };

  static const Map<String, String> _countryCurrencies = {
    // Arab countries
    'Egypt': 'EGP',
    'Saudi Arabia': 'SAR',
    'United Arab Emirates': 'AED',
    'Qatar': 'QAR',
    'Kuwait': 'KWD',
    'Bahrain': 'BHD',
    'Oman': 'OMR',
    'Jordan': 'JOD',
    'Iraq': 'IQD',
    'Lebanon': 'LBP',
    'Syria': 'SYP',
    'Yemen': 'YER',
    'Palestine': 'ILS',
    'Sudan': 'SDG',
    'Libya': 'LYD',
    'Tunisia': 'TND',
    'Algeria': 'DZD',
    'Morocco': 'MAD',
    'Mauritania': 'MRU',
    'Somalia': 'SOS',
    'Djibouti': 'DJF',
    'Comoros': 'KMF',

    // USA & UK
    'United States': 'USD',
    'United Kingdom': 'GBP',

    // Eurozone
    'Germany': 'EUR',
    'France': 'EUR',
    'Italy': 'EUR',
    'Spain': 'EUR',
    'Portugal': 'EUR',
    'Netherlands': 'EUR',
    'Belgium': 'EUR',
    'Austria': 'EUR',
    'Ireland': 'EUR',
    'Greece': 'EUR',
    'Finland': 'EUR',
    'Luxembourg': 'EUR',
    'Slovakia': 'EUR',
    'Slovenia': 'EUR',
    'Croatia': 'EUR',
    'Estonia': 'EUR',
    'Latvia': 'EUR',
    'Lithuania': 'EUR',
    'Cyprus': 'EUR',
    'Malta': 'EUR',
    'Bulgaria': 'EUR',

    // Other European countries
    'Switzerland': 'CHF',
    'Norway': 'NOK',
    'Sweden': 'SEK',
    'Denmark': 'DKK',
    'Poland': 'PLN',
    'Czechia': 'CZK',
    'Hungary': 'HUF',
    'Romania': 'RON',
    'Iceland': 'ISK',
    'Serbia': 'RSD',
    'Albania': 'ALL',
    'Ukraine': 'UAH',
    'Turkey': 'TRY',
    'Russia': 'RUB',
  };

  static const Map<String, String> _countryNamesAr = {
    'Egypt': 'مصر',
    'Saudi Arabia': 'المملكة العربية السعودية',
    'United Arab Emirates': 'الإمارات العربية المتحدة',
    'Qatar': 'قطر',
    'Kuwait': 'الكويت',
    'Bahrain': 'البحرين',
    'Oman': 'عُمان',
    'Jordan': 'الأردن',
    'Iraq': 'العراق',
    'Lebanon': 'لبنان',
    'Syria': 'سوريا',
    'Yemen': 'اليمن',
    'Palestine': 'فلسطين',
    'Sudan': 'السودان',
    'Libya': 'ليبيا',
    'Tunisia': 'تونس',
    'Algeria': 'الجزائر',
    'Morocco': 'المغرب',
    'Mauritania': 'موريتانيا',
    'Somalia': 'الصومال',
    'Djibouti': 'جيبوتي',
    'Comoros': 'جزر القمر',
    'United States': 'الولايات المتحدة',
    'United Kingdom': 'المملكة المتحدة',
    'Germany': 'ألمانيا',
    'France': 'فرنسا',
    'Italy': 'إيطاليا',
    'Spain': 'إسبانيا',
    'Portugal': 'البرتغال',
    'Netherlands': 'هولندا',
    'Belgium': 'بلجيكا',
    'Austria': 'النمسا',
    'Ireland': 'أيرلندا',
    'Greece': 'اليونان',
    'Finland': 'فنلندا',
    'Luxembourg': 'لوكسمبورغ',
    'Slovakia': 'سلوفاكيا',
    'Slovenia': 'سلوفينيا',
    'Croatia': 'كرواتيا',
    'Estonia': 'إستونيا',
    'Latvia': 'لاتفيا',
    'Lithuania': 'ليتوانيا',
    'Cyprus': 'قبرص',
    'Malta': 'مالطا',
    'Switzerland': 'سويسرا',
    'Norway': 'النرويج',
    'Sweden': 'السويد',
    'Denmark': 'الدنمارك',
    'Poland': 'بولندا',
    'Czechia': 'التشيك',
    'Hungary': 'المجر',
    'Romania': 'رومانيا',
    'Bulgaria': 'بلغاريا',
    'Iceland': 'آيسلندا',
    'Serbia': 'صربيا',
    'Albania': 'ألبانيا',
    'Ukraine': 'أوكرانيا',
    'Turkey': 'تركيا',
    'Russia': 'روسيا',
  };

  /// Translates a UI string using the app-wide language (AppLanguage).
  String t(String value) =>
      AppLanguage.isArabic ? (_ar[value] ?? value) : value;

  /// Letter spacing is great for Latin uppercase text, but it breaks the
  /// joined letters of Arabic script, so it is switched off in Arabic.
  double _ls(double value) => AppLanguage.isArabic ? 0.0 : value;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  static bool _captchaViewRegistered = false;

  @override
  void initState() {
    super.initState();
    // No language listener needed: AppLanguage.toggle() refreshes every screen.
    _registerCaptchaView();
  }

  void _registerCaptchaView() {
    if (_captchaViewRegistered) return;

    ui.platformViewRegistry.registerViewFactory('innovista-hcaptcha', (
      int viewId,
    ) {
      final element = web.HTMLDivElement()
        ..id = 'innovista-hcaptcha-$viewId'
        ..style.width = '100%'
        ..style.minHeight = '80px';

      _renderCaptchaWhenAttached(element);

      return element;
    });

    _captchaViewRegistered = true;
  }

  /// The element is created before Flutter attaches it to the page, and
  /// hCaptcha needs an element that is already in the DOM. So we wait (up to
  /// ~3 seconds) until it is connected, then render the widget.
  void _renderCaptchaWhenAttached(web.HTMLDivElement element) {
    var attempts = 0;

    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      attempts++;

      if (element.isConnected) {
        timer.cancel();

        try {
          renderInnovistaCaptcha(element);
        } catch (e) {
          debugPrint('hCaptcha render error: $e');
        }
      } else if (attempts > 60) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _provinceController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    _referencesController.dispose();
    _budgetController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return t('This field is required');
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final required = _requiredValidator(value);
    if (required != null) return required;

    final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!pattern.hasMatch(value!.trim())) {
      return t('Please enter a valid email address.');
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    final required = _requiredValidator(value);
    if (required != null) return required;

    final text = value!.trim();
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');

    final allowedChars = RegExp(r'^\+?[0-9\s\-()]+$');

    if (!allowedChars.hasMatch(text) ||
        digits.length < 7 ||
        digits.length > 15) {
      return t('Please enter a valid phone number.');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Small UI helpers
  // ---------------------------------------------------------------------------

  void _snack(String message, {Duration? duration}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t(message)),
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }

  InputDecoration _decoration(String label, {String? hint, String? suffix}) {
    return InputDecoration(
      labelText: t(label),
      hintText: hint == null ? null : t(hint),
      suffixText: suffix,
      suffixStyle: const TextStyle(color: bronze),
      labelStyle: const TextStyle(color: muted),
      hintStyle: const TextStyle(color: muted, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF191919),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF3A3733)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: bronze, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool required = false,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Iterable<String>? autofillHints,
    String? suffix,
    bool noSpaces = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textInputAction: maxLines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      autofillHints: autofillHints,
      inputFormatters: [
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
        if (noSpaces) FilteringTextInputFormatter.deny(RegExp(r'\s')),
      ],
      style: const TextStyle(color: ivory, height: 1.5),
      decoration: _decoration(label, hint: hint, suffix: suffix),
      validator: validator ?? (required ? _requiredValidator : null),
    );
  }

  Widget _dropdown(
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged, {
    Map<String, String>? itemLabels,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: cardColor,
      style: const TextStyle(color: ivory, fontSize: 14),
      decoration: _decoration(label),
      iconEnabledColor: bronze,
      items: options.map((option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(
            itemLabels?[option] ?? t(option),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (selected) {
        if (selected == null || selected.isEmpty) {
          return t('Please select an option');
        }
        return null;
      },
    );
  }

  Widget _section(String title, String subtitle, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37332E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            headingLevel: 2,
            child: Text(
              t(title),
              style: const TextStyle(
                color: ivory,
                fontSize: 21,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(t(subtitle), style: const TextStyle(color: muted, height: 1.6)),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _chips(
    List<String> options,
    Set<String> selected,
    ValueChanged<String> onToggle,
  ) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: options.map((option) {
        final isSelected = selected.contains(option);

        return FilterChip(
          label: Text(t(option)),
          selected: isSelected,
          onSelected: (_) => onToggle(option),
          showCheckmark: false,
          labelStyle: TextStyle(
            color: isSelected ? bgColor : ivory,
            fontSize: 13,
          ),
          backgroundColor: const Color(0xFF191919),
          selectedColor: bronze,
          side: BorderSide(
            color: isSelected ? bronze : const Color(0xFF49443D),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        );
      }).toList(),
    );
  }

  Widget _twoColumns(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 650;

        if (!isWide) {
          return Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: 18),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: children[0]),
            const SizedBox(width: 18),
            Expanded(child: children[1]),
          ],
        );
      },
    );
  }

  Widget _label(String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        t(value),
        style: const TextStyle(
          color: ivory,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  List<String> _sortedCountries() {
    final isArabic = AppLanguage.isArabic;

    String name(String key) => isArabic ? (_countryNamesAr[key] ?? key) : key;

    final countries = _countryCurrencies.keys.toList();
    countries.sort((a, b) => name(a).compareTo(name(b)));

    return countries;
  }

  // ---------------------------------------------------------------------------
  // WhatsApp
  // ---------------------------------------------------------------------------

  Future<void> _openWhatsApp() async {
    final message = AppLanguage.isArabic
        ? 'مرحبًا INNOVISTA، أنا مهتم بخدمات التصور المعماري وأرغب في '
              'مناقشة مشروع.'
        : "Hello INNOVISTA, I'm interested in your architectural "
              'visualization services. I\'d like to discuss a project.';

    final url = Uri.parse(
      'https://wa.me/$_whatsAppNumber?text=${Uri.encodeComponent(message)}',
    );

    // IMPORTANT: open WhatsApp FIRST, directly inside the click. If we await
    // a network call before opening, browsers treat it as a pop-up and block it.
    final opened = launchUrl(url, mode: LaunchMode.externalApplication);

    // Record the inquiry in the background; it never delays WhatsApp.
    unawaited(_recordWhatsAppLead());

    final success = await opened;

    if (!success) _snack('Could not open WhatsApp.');
  }

  Future<void> _recordWhatsAppLead() async {
    try {
      final name = _nameController.text.trim();

      final response = await Supabase.instance.client.functions.invoke(
        'submit-client-request',
        body: {
          'source': 'whatsapp',
          'name': name.isEmpty ? null : name,
          'page_url': Uri.base.toString(),
        },
      );

      debugPrint('WhatsApp Lead Status: ${response.status}');
    } catch (e) {
      debugPrint('WhatsApp Lead Error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Captcha helpers
  // ---------------------------------------------------------------------------

  String _readCaptchaToken() {
    try {
      return getInnovistaCaptchaToken().trim();
    } catch (e) {
      debugPrint('hCaptcha token error: $e');
      return '';
    }
  }

  void _resetCaptcha() {
    try {
      resetInnovistaCaptcha();
    } catch (e) {
      debugPrint('hCaptcha reset error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submitForm() async {
    if (_isSubmitting) return;

    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      _snack('Please complete the required fields.');
      return;
    }

    if (_services.isEmpty) {
      _snack('Please select at least one service.');
      return;
    }

    // First press: show the captcha and bring it into view.
    if (!_showCaptcha) {
      setState(() => _showCaptcha = true);

      _snack('Please complete the CAPTCHA below, then press submit again.');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final captchaContext = _captchaKey.currentContext;

        if (captchaContext != null) {
          Scrollable.ensureVisible(
            captchaContext,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            alignment: 0.3,
          );
        }
      });

      return;
    }

    final captchaToken = _readCaptchaToken();

    if (captchaToken.isEmpty) {
      _snack('Please complete the CAPTCHA verification.');
      return;
    }

    setState(() => _isSubmitting = true);

    var sent = false;

    try {
      // NOTE: the keys below are the contract with the Edge Function
      // "innovesta_co". Do not rename them unless the function changes too.
      final payload = <String, dynamic>{
        'country': _selectedCountry ?? '',
        'budget_currency': _selectedCurrency ?? '',
        'estimated_budget': _budgetController.text.trim(),

        // Token sent to the server, which MUST verify it with hCaptcha.
        'h-captcha-response': captchaToken,

        'subject': 'New INNOVISTA Project Request',
        'from_name': _nameController.text.trim(),
        'name': _nameController.text.trim(),
        'company': _companyController.text.trim(),
        'location': _provinceController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'email': _emailController.text.trim(),
        'preferred_contact': _preferredContact,
        'project_type': _projectType ?? '',
        'project_stage': _projectStage ?? '',
        'project_area': _area ?? '',
        'timeline': _timeline ?? '',
        'services': _services.join(', '),
        'project_description': _descriptionController.text.trim(),
        'design_styles': _styles.join(', '),
        'overall_mood': _mood ?? '',
        'reference_links': _referencesController.text.trim(),
        'additional_notes': _notesController.text.trim(),
        'source': 'form',
      };

      final response = await Supabase.instance.client.functions.invoke(
        'innovesta_co',
        body: payload,
      );

      debugPrint('Supabase Status: ${response.status}');

      final data = response.data;

      sent = response.status == 200 && data is Map && data['success'] == true;
    } catch (e) {
      debugPrint('Submission Error Type: ${e.runtimeType}');
      debugPrint('Submission Error: $e');
    } finally {
      // An hCaptcha token can be used only once, so always get a fresh one.
      // Without this, a retry after a failed attempt is rejected.
      _resetCaptcha();

      if (mounted) setState(() => _isSubmitting = false);
    }

    if (!mounted) return;

    _snack(
      sent
          ? 'Your project request has been sent successfully.'
          : 'We could not send your request. Please try again.',
    );

    if (sent) _resetForm();
  }

  void _resetForm() {
    _nameController.clear();
    _companyController.clear();
    _provinceController.clear();
    _whatsappController.clear();
    _emailController.clear();
    _descriptionController.clear();
    _referencesController.clear();
    _budgetController.clear();
    _notesController.clear();

    setState(() {
      _selectedCountry = null;
      _selectedCurrency = null;
      _projectType = null;
      _projectStage = null;
      _area = null;
      _timeline = null;
      _mood = null;
      _preferredContact = 'WhatsApp';
      _services.clear();
      _styles.clear();
      _showCaptcha = false;

      // Rebuilds all fields from scratch (dropdowns included).
      _formVersion++;
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLanguage.isArabic;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text(
          'INNOVISTA',
          style: TextStyle(
            color: ivory,
            letterSpacing: 3,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: AppLanguage.toggle,
            child: Text(
              isArabic ? 'EN' : 'عربي',
              style: const TextStyle(
                color: bronze,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.maybePop(context),
            child: Text(t('BACK'), style: const TextStyle(color: bronze)),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: AutofillGroup(
                  child: KeyedSubtree(
                    key: ValueKey(_formVersion),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('PROJECT INQUIRY / 2026'),
                          style: TextStyle(
                            color: bronze,
                            letterSpacing: _ls(2.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          t('LET’S CREATE SOMETHING EXCEPTIONAL'),
                          style: TextStyle(
                            color: bronze,
                            fontSize: 12,
                            letterSpacing: _ls(1.6),
                            height: 1.8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Semantics(
                          header: true,
                          headingLevel: 1,
                          child: Text(
                            t('Tell Us About Your Project.'),
                            style: TextStyle(
                              color: ivory,
                              fontSize: isArabic ? 34 : 42,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          t(
                            'Every great space starts with an idea. Share your vision with INNOVISTA, and let’s explore how we can bring it to life.',
                          ),
                          style: const TextStyle(
                            color: muted,
                            fontSize: 15,
                            height: 1.9,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Quick inquiry via WhatsApp.
                        // No fixed height: the button grows with its text, so
                        // nothing is clipped on narrow phones or in Arabic.
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _openWhatsApp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: bronze,
                              foregroundColor: bgColor,
                              elevation: 0,
                              minimumSize: const Size(double.infinity, 58),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.chat_bubble_outline),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    t('QUICK INQUIRY VIA WHATSAPP'),
                                    textAlign: TextAlign.center,
                                    softWrap: true,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: _ls(0.8),
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Center(
                          child: Column(
                            children: [
                              Text(
                                t('Prefer a more detailed approach?'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: bronze,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t(
                                  'Share your project details through our inquiry form to help us better understand your vision, requirements, and expectations — so we can prepare a more tailored response for you.',
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 13,
                                  height: 1.8,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // 1. Contact information
                        _section(
                          'Your Information',
                          'Tell us how to reach you about your project.',
                          [
                            _field(
                              _nameController,
                              'Full Name *',
                              hint: 'Enter your full name',
                              required: true,
                              maxLength: 100,
                              autofillHints: const [AutofillHints.name],
                            ),
                            const SizedBox(height: 18),
                            _field(
                              _companyController,
                              'Company / Studio Name',
                              hint: 'Company or studio name (optional)',
                              maxLength: 120,
                              autofillHints: const [
                                AutofillHints.organizationName,
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Country
                            _dropdown(
                              'Country *',
                              _selectedCountry,
                              _sortedCountries(),
                              (value) {
                                if (value == null) return;

                                setState(() {
                                  _selectedCountry = value;
                                  _selectedCurrency = _countryCurrencies[value];
                                });
                              },
                              itemLabels: isArabic ? _countryNamesAr : null,
                            ),
                            const SizedBox(height: 18),

                            // Province / Governorate
                            _field(
                              _provinceController,
                              'Governorate / Province *',
                              hint: 'Enter your governorate or province',
                              required: true,
                              maxLength: 80,
                              autofillHints: const [AutofillHints.addressState],
                            ),
                            const SizedBox(height: 18),

                            // WhatsApp and Email
                            _twoColumns([
                              _field(
                                _whatsappController,
                                'WhatsApp Number *',
                                hint: '+20...',
                                validator: _phoneValidator,
                                maxLength: 25,
                                keyboardType: TextInputType.phone,
                                autofillHints: const [
                                  AutofillHints.telephoneNumber,
                                ],
                              ),
                              _field(
                                _emailController,
                                'Email Address *',
                                hint: 'you@example.com',
                                validator: _emailValidator,
                                maxLength: 254,
                                noSpaces: true,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                              ),
                            ]),
                            const SizedBox(height: 22),

                            // Preferred contact method
                            _label('Preferred Contact Method'),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: ['WhatsApp', 'Email', 'Phone'].map((
                                item,
                              ) {
                                final selected = _preferredContact == item;

                                return ChoiceChip(
                                  label: Text(t(item)),
                                  selected: selected,
                                  onSelected: (_) {
                                    setState(() => _preferredContact = item);
                                  },
                                  selectedColor: bronze,
                                  backgroundColor: const Color(0xFF191919),
                                  labelStyle: TextStyle(
                                    color: selected ? bgColor : ivory,
                                  ),
                                  side: const BorderSide(color: bronze),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),

                        // 2. Project brief
                        _section(
                          'Project Brief',
                          'Help us understand the scope and requirements.',
                          [
                            _twoColumns([
                              _dropdown('Project Type *', _projectType, [
                                'Villa / Residential',
                                'Apartment',
                                'Commercial / Retail',
                                'Office',
                                'Hospitality',
                                'Landscape',
                                'Other',
                              ], (v) => setState(() => _projectType = v)),
                              _dropdown('Project Stage *', _projectStage, [
                                'Concept Design',
                                'Design Development',
                                'Ready for Visualization',
                                'Under Construction',
                                'Existing Space Renovation',
                              ], (v) => setState(() => _projectStage = v)),
                            ]),
                            const SizedBox(height: 18),
                            _twoColumns([
                              _dropdown('Approximate Area *', _area, [
                                'Under 100 m²',
                                '100–250 m²',
                                '250–500 m²',
                                '500–1,000 m²',
                                'Over 1,000 m²',
                                'Not determined',
                              ], (v) => setState(() => _area = v)),
                              _dropdown('Expected Timeline *', _timeline, [
                                'As soon as possible',
                                'Within 2 weeks',
                                'Within a month',
                                'Flexible',
                              ], (v) => setState(() => _timeline = v)),
                            ]),
                            const SizedBox(height: 24),
                            _label('Services Required *'),
                            Text(
                              t('Select the services you need.'),
                              style: const TextStyle(
                                color: muted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _chips(_serviceOptions, _services, (option) {
                              setState(() {
                                if (!_services.remove(option)) {
                                  _services.add(option);
                                }
                              });
                            }),
                            const SizedBox(height: 24),
                            _field(
                              _descriptionController,
                              'Project Description *',
                              hint: 'Describe your project, goals, and requirements...',
                              required: true,
                              maxLines: 5,
                              maxLength: 3000,
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),

                        // 3. Design direction
                        _section(
                          'Design Direction',
                          'Tell us about the look, feel, and atmosphere you want to achieve.',
                          [
                            _label('Preferred Design Style'),
                            _chips(_styleOptions, _styles, (option) {
                              setState(() {
                                if (!_styles.remove(option)) {
                                  _styles.add(option);
                                }
                              });
                            }),
                            const SizedBox(height: 24),
                            _dropdown('Overall Mood', _mood, [
                              'Warm & Inviting',
                              'Luxury & Sophisticated',
                              'Minimal & Calm',
                              'Bright & Natural',
                              'Dark & Dramatic',
                              'Bold & Contemporary',
                              'Not sure yet',
                            ], (v) => setState(() => _mood = v)),
                            const SizedBox(height: 18),
                            _field(
                              _referencesController,
                              'Reference Links',
                              hint: 'Add links to Pinterest, images, or inspiration...',
                              maxLines: 2,
                              maxLength: 1000,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              t(
                                'Tip: You can share reference images or links to help us understand your vision.',
                              ),
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                                height: 1.7,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),

                        // 4. Budget and notes
                        _section(
                          'Budget & Additional Notes',
                          'Optional details that help us plan the right solution for you.',
                          [
                            _field(
                              _budgetController,
                              'Estimated Visualization Budget',
                              hint: 'e.g.  \$5,000 –  \$10,000',
                              maxLength: 60,
                              suffix: _selectedCurrency,
                            ),
                            const SizedBox(height: 18),
                            _field(
                              _notesController,
                              'Additional Notes',
                              hint: 'Anything else we should know?',
                              maxLines: 4,
                              maxLength: 2000,
                            ),
                          ],
                        ),

                        if (_showCaptcha)
                          Column(
                            key: _captchaKey,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              Text(
                                t('Verify that you are human'),
                                style: const TextStyle(color: ivory),
                              ),
                              const SizedBox(height: 12),
                              const SizedBox(
                                height: 100,
                                child: HtmlElementView(
                                  viewType: 'innovista-hcaptcha',
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),

                        const SizedBox(height: 10),

                        // Submit button (also grows with its text).
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: bronze,
                              foregroundColor: bgColor,
                              elevation: 0,
                              minimumSize: const Size(double.infinity, 58),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isSubmitting
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                bgColor,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: Text(
                                          t('Sending your request...'),
                                          textAlign: TextAlign.center,
                                          softWrap: true,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    t('SUBMIT PROJECT BRIEF'),
                                    textAlign: TextAlign.center,
                                    softWrap: true,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: _ls(1.2),
                                      height: 1.3,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        Text(
                          t(
                            'By submitting this form you agree that INNOVISTA may use your details to respond to your request.',
                          ),
                          style: const TextStyle(
                            color: muted,
                            fontSize: 12,
                            height: 1.7,
                          ),
                        ),

                        const SizedBox(height: 35),
                        const Divider(color: Color(0xFF39352F)),
                        const SizedBox(height: 18),

                        Text(
                          t('INNOVISTA | Architectural Visualization'),
                          style: TextStyle(
                            color: bronze,
                            fontSize: 13,
                            letterSpacing: _ls(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          t(
                            'We turn architectural ideas into visual experiences.',
                          ),
                          style: const TextStyle(
                            color: muted,
                            fontSize: 12,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
