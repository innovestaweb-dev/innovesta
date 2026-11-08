import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_login_page.dart';
import 'admin_dashboard_page.dart';

class AdminGatePage extends StatelessWidget {
  const AdminGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;

        if (session != null) {
          return const AdminDashboardPage();
        }

        return const AdminLoginPage();
      },
    );
  }
}
