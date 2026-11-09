import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/admin_client_requests_page.dart';
import 'pages/admin_materials_page.dart';
import 'pages/admin_projects_page.dart';

const Color _background = Color(0xFF171717);
const Color _surface = Color(0xFF222222);
const Color _ivory = Color(0xFFF4EFE6);
const Color _bronze = Color(0xFFB6A080);
const Color _muted = Color(0xFFAAA69F);
const Color _border = Color(0xFF393733);

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;

  // Only sections that are actually built. Add Services / Website Content /
  // Settings back here when they exist.
  static const int _overviewIndex = 0;
  static const int _projectsIndex = 1;
  static const int _materialsIndex = 2;
  static const int _requestsIndex = 3;

  final List<_AdminMenuItem> _menuItems = const [
    _AdminMenuItem(
      title: 'Overview',
      subtitle: 'نظرة عامة',
      icon: Icons.dashboard_outlined,
    ),
    _AdminMenuItem(
      title: 'Projects',
      subtitle: 'المشاريع',
      icon: Icons.apartment_outlined,
    ),
    _AdminMenuItem(
      title: 'Material Library',
      subtitle: 'مكتبة الخامات',
      icon: Icons.texture_outlined,
    ),
    _AdminMenuItem(
      title: 'Client Requests',
      subtitle: 'طلبات العملاء',
      icon: Icons.mark_email_unread_outlined,
    ),
  ];

  // Overview numbers (null = not loaded yet or failed).
  int? _projectsCount;
  int? _materialsCount;
  int? _requestsCount;
  int? _newRequestsCount;
  Map<String, dynamic>? _visits;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<int?> _countRows(String table, {String? statusEquals}) async {
    try {
      final client = Supabase.instance.client;

      final rows = statusEquals == null
          ? await client.from(table).select('id')
          : await client.from(table).select('id').eq('status', statusEquals);

      return rows.length;
    } catch (e) {
      debugPrint('Stats error ($table): $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _loadVisits() async {
    try {
      final response = await Supabase.instance.client.rpc('admin_visit_stats');

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('Visit stats error: $e');
      return null;
    }
  }

  Future<void> _loadStats() async {
    final results = await Future.wait<Object?>([
      _countRows('projects'),
      _countRows('materials'),
      _countRows('client_requests'),
      _countRows('client_requests', statusEquals: 'new'),
      _loadVisits(),
    ]);

    if (!mounted) return;

    setState(() {
      _projectsCount = results[0] as int?;
      _materialsCount = results[1] as int?;
      _requestsCount = results[2] as int?;
      _newRequestsCount = results[3] as int?;
      _visits = results[4] as Map<String, dynamic>?;
    });
  }

  int _num(Object? value) => value is num ? value.toInt() : 0;

  Map<String, dynamic> _block(String key) {
    final value = _visits?[key];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  List<Map<String, dynamic>> _rows(String key) {
    final value = _visits?[key];
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Visitors
  // ---------------------------------------------------------------------------

  Widget _buildVisitsSection() {
    if (_visits == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _border),
        ),
        child: const Text(
          'Visitor statistics are not available yet. Run '
          '01_visits_and_admin_gate.sql in Supabase, deploy the track-visit '
          'function, then refresh.',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.7),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _VisitCard(label: 'Today', data: _block('today')),
            _VisitCard(label: 'Last 7 days', data: _block('last7')),
            _VisitCard(label: 'Last 30 days', data: _block('last30')),
            _VisitCard(label: 'All time', data: _block('total')),
          ],
        ),
        const SizedBox(height: 16),
        _buildDailyChart(),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final pages = _buildRankList(
              'TOP PAGES (30 DAYS)',
              _rows('top_pages'),
              'path',
            );
            final referrers = _buildRankList(
              'TOP SOURCES (30 DAYS)',
              _rows('top_referrers'),
              'referrer',
            );

            if (constraints.maxWidth < 700) {
              return Column(
                children: [pages, const SizedBox(height: 16), referrers],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: pages),
                const SizedBox(width: 16),
                Expanded(child: referrers),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildDailyChart() {
    final daily = _rows('daily');
    final maxVisitors = daily.fold<int>(
      1,
      (max, item) =>
          _num(item['visitors']) > max ? _num(item['visitors']) : max,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'UNIQUE VISITORS, LAST 14 DAYS',
            style: TextStyle(color: _bronze, fontSize: 10, letterSpacing: 2),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final item in daily)
                  Expanded(
                    child: Tooltip(
                      message:
                          '${item['day']}\n${_num(item['visitors'])} visitors'
                          ' • ${_num(item['views'])} views',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${_num(item['visitors'])}',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 9,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height:
                                  2 + 98 * _num(item['visitors']) / maxVisitors,
                              color: _bronze,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${item['day']}'.length >= 10
                                  ? '${item['day']}'.substring(8)
                                  : '',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildRankList(
    String title,
    List<Map<String, dynamic>> rows,
    String labelKey,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _bronze,
              fontSize: 10,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            const Text(
              'No data yet.',
              style: TextStyle(color: _muted, fontSize: 12),
            )
          else
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${row[labelKey]}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _ivory, fontSize: 13),
                      ),
                    ),
                    Text(
                      '${_num(row['views'])}',
                      style: const TextStyle(color: _muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  void _selectSection(int index) {
    setState(() => _selectedIndex = index);

    // Numbers may have changed while the admin was in another section.
    if (index == _overviewIndex) _loadStats();
  }

  Future<void> _logout() async {
    // AdminGatePage listens to the auth state and shows the login screen.
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 850;

        return Scaffold(
          backgroundColor: _background,
          drawer: isMobile
              ? Drawer(
                  backgroundColor: _surface,
                  child: SafeArea(child: _buildSidebar()),
                )
              : null,
          body: Row(
            children: [
              if (!isMobile) SizedBox(width: 255, child: _buildSidebar()),

              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(isMobile),

                    Expanded(child: _buildMainContent()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: _surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(25, 30, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INNOVISTA',
                  style: TextStyle(
                    color: _ivory,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'ADMINISTRATION',
                  style: TextStyle(
                    color: _bronze,
                    fontSize: 9,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: _border, height: 1),

          const Padding(
            padding: EdgeInsets.fromLTRB(25, 25, 20, 12),
            child: Text(
              'WORKSPACE',
              style: TextStyle(color: _muted, fontSize: 9, letterSpacing: 2),
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final item = _menuItems[index];
                final selected = _selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: InkWell(
                    onTap: () {
                      _selectSection(index);

                      if (Scaffold.of(context).isDrawerOpen) {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? _bronze.withValues(alpha: 0.12)
                            : Colors.transparent,
                        border: selected
                            ? const Border(
                                left: BorderSide(color: _bronze, width: 3),
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            color: selected ? _bronze : _muted,
                            size: 19,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    color: selected ? _ivory : _muted,
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle,
                                  style: TextStyle(
                                    color: _muted.withValues(alpha: 0.7),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(color: _border, height: 1),

          Padding(
            padding: const EdgeInsets.all(18),
            child: InkWell(
              onTap: _logout,
              child: const Row(
                children: [
                  Icon(Icons.logout, color: Color(0xFFE58C83), size: 19),
                  SizedBox(width: 12),
                  Text(
                    'Sign Out',
                    style: TextStyle(color: Color(0xFFE58C83), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isMobile) {
    return Container(
      height: 76,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
      decoration: const BoxDecoration(
        color: _background,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (context) => IconButton(
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
                icon: const Icon(Icons.menu, color: _ivory),
              ),
            ),

          Expanded(
            child: Text(
              _menuItems[_selectedIndex].title,
              style: const TextStyle(
                color: _ivory,
                fontSize: 18,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),

          const Icon(Icons.account_circle_outlined, color: _bronze, size: 22),

          const SizedBox(width: 10),

          const Text(
            'Administrator',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case _projectsIndex:
        return const AdminProjectsPage();

      case _materialsIndex:
        return const AdminMaterialsPage();

      case _requestsIndex:
        return const AdminClientRequestsPage();

      default:
        return _buildOverview();
    }
  }

  Widget _buildOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to INNOVISTA',
            style: TextStyle(
              color: _ivory,
              fontSize: 28,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Manage your studio, projects and website content.',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 35),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth < 550 ? 1 : 2;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: crossAxisCount == 1 ? 3.2 : 2.2,
                children: [
                  _OverviewCard(
                    title: 'Projects',
                    subtitle: 'Total projects',
                    icon: Icons.apartment_outlined,
                    value: _projectsCount,
                    onTap: () => _selectSection(_projectsIndex),
                  ),
                  _OverviewCard(
                    title: 'Materials',
                    subtitle: 'Library materials',
                    icon: Icons.texture_outlined,
                    value: _materialsCount,
                    onTap: () => _selectSection(_materialsIndex),
                  ),
                  _OverviewCard(
                    title: 'New Requests',
                    subtitle: 'Waiting for your reply',
                    icon: Icons.mark_email_unread_outlined,
                    value: _newRequestsCount,
                    highlight: (_newRequestsCount ?? 0) > 0,
                    onTap: () => _selectSection(_requestsIndex),
                  ),
                  _OverviewCard(
                    title: 'All Requests',
                    subtitle: 'Form and WhatsApp inquiries',
                    icon: Icons.inbox_outlined,
                    value: _requestsCount,
                    onTap: () => _selectSection(_requestsIndex),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 35),
          const Text(
            'VISITORS',
            style: TextStyle(color: _bronze, fontSize: 10, letterSpacing: 2),
          ),
          const SizedBox(height: 14),
          _buildVisitsSection(),
          const SizedBox(height: 35),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: _surface,
              border: Border.all(color: _border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QUICK ACCESS',
                  style: TextStyle(
                    color: _bronze,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 15),
                Text(
                  'Your administration workspace is ready.',
                  style: TextStyle(color: _ivory, fontSize: 17),
                ),
                SizedBox(height: 8),
                Text(
                  'Choose a section from the sidebar to manage your website.',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final int? value;
  final bool highlight;
  final VoidCallback onTap;

  const _OverviewCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: highlight ? _bronze : _border),
          ),
          child: Row(
            children: [
              Icon(icon, color: _bronze, size: 27),
              const SizedBox(width: 17),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: _ivory, fontSize: 17),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                value?.toString() ?? '—',
                style: TextStyle(
                  color: highlight ? _ivory : _bronze,
                  fontSize: 26,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;

  const _AdminMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _VisitCard extends StatelessWidget {
  final String label;
  final Map<String, dynamic> data;

  const _VisitCard({required this.label, required this.data});

  int _num(Object? value) => value is num ? value.toInt() : 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_num(data['visitors'])}',
            style: const TextStyle(
              color: _ivory,
              fontSize: 30,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'visitors • ${_num(data['views'])} views',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
