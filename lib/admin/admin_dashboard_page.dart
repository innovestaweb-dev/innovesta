import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/admin_client_requests_page.dart';
import 'pages/admin_materials_page.dart';
import 'admin_login_page.dart';
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
      title: 'Services',
      subtitle: 'الخدمات',
      icon: Icons.design_services_outlined,
    ),
    _AdminMenuItem(
      title: 'Website Content',
      subtitle: 'محتوى الموقع',
      icon: Icons.web_outlined,
    ),
    _AdminMenuItem(
      title: 'Client Requests',
      subtitle: 'طلبات العملاء',
      icon: Icons.mark_email_unread_outlined,
    ),
    _AdminMenuItem(
      title: 'Settings',
      subtitle: 'الإعدادات',
      icon: Icons.settings_outlined,
    ),
  ];

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminLoginPage()),
      (route) => false,
    );
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
                      setState(() {
                        _selectedIndex = index;
                      });

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
                            child: Text(
                              item.title,
                              style: TextStyle(
                                color: selected ? _ivory : _muted,
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
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
      case 1:
        return const AdminProjectsPage();

      case 2:
        return const AdminMaterialsPage();

      case 5:
        return const AdminClientRequestsPage();

      default:
        if (_selectedIndex == 0) {
          return _buildOverview();
        }

        return _buildComingSoon();
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
                children: const [
                  _OverviewCard(
                    title: 'Projects',
                    subtitle: 'Total projects',
                    icon: Icons.apartment_outlined,
                  ),
                  _OverviewCard(
                    title: 'Materials',
                    subtitle: 'Library materials',
                    icon: Icons.texture_outlined,
                  ),
                  _OverviewCard(
                    title: 'Services',
                    subtitle: 'Active services',
                    icon: Icons.design_services_outlined,
                  ),
                  _OverviewCard(
                    title: 'Requests',
                    subtitle: 'Client inquiries',
                    icon: Icons.mark_email_unread_outlined,
                  ),
                ],
              );
            },
          ),
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

  Widget _buildComingSoon() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_menuItems[_selectedIndex].icon, color: _bronze, size: 42),
          const SizedBox(height: 20),
          Text(
            _menuItems[_selectedIndex].title,
            style: const TextStyle(color: _ivory, fontSize: 23),
          ),
          const SizedBox(height: 10),
          const Text(
            'This section will be built next.',
            style: TextStyle(color: _muted, fontSize: 12),
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

  const _OverviewCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
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
          const Text('—', style: TextStyle(color: _bronze, fontSize: 24)),
        ],
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
