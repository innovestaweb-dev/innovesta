import 'dart:async';
import 'dart:convert';

import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_dashboard_page.dart';
import 'admin_login_page.dart';

const Color _background = Color(0xFF171717);
const Color _surface = Color(0xFF222222);
const Color _ivory = Color(0xFFF4EFE6);
const Color _bronze = Color(0xFFB6A080);
const Color _muted = Color(0xFFAAA69F);
const Color _border = Color(0xFF3B3935);
const Color _errorColor = Color(0xFFE58C83);

enum _GateState { loading, login, notAdmin, enroll, verify, ready, error }

/// Decides what the /admin route shows:
///   not signed in            -> login
///   signed in, wrong account -> access denied
///   admin, no authenticator  -> one-time authenticator setup
///   admin, password only     -> 6-digit code
///   admin + code verified    -> dashboard
///
/// This is the user-facing layer. The real protection is in the database:
/// Row Level Security only lets the admin account (and, after
/// 02_enforce_mfa_for_admin.sql, only a code-verified session) read or write.
class AdminGatePage extends StatefulWidget {
  const AdminGatePage({super.key});

  @override
  State<AdminGatePage> createState() => _AdminGatePageState();
}

class _AdminGatePageState extends State<AdminGatePage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  StreamSubscription<AuthState>? _subscription;

  _GateState _state = _GateState.loading;
  String? _factorId;

  bool _evaluating = false;
  bool _runAgain = false;

  @override
  void initState() {
    super.initState();
    _subscription = _supabase.auth.onAuthStateChange.listen((authState) {
      final event = authState.event;

      debugPrint('Admin auth event: $event');

      if (event == AuthChangeEvent.signedOut ||
          event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.mfaChallengeVerified) {
        _evaluate();
      }
    });
    _evaluate();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _evaluate() async {
    if (_evaluating) {
      _runAgain = true;
      return;
    }

    _evaluating = true;

    try {
      do {
        _runAgain = false;

        final next = await _computeState();

        if (!mounted) return;

        if (next != _state) setState(() => _state = next);
      } while (_runAgain);
    } finally {
      _evaluating = false;
    }
  }

  bool _isVerified(Object? status) {
    final text = status.toString();
    return text == 'verified' || text.endsWith('.verified');
  }

  /// Reads the `aal` claim ("aal1" = password only, "aal2" = code verified).
  String _jwtAal(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return '';

      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final map = jsonDecode(payload) as Map<String, dynamic>;

      return map['aal']?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<_GateState> _computeState() async {
    if (_supabase.auth.currentSession == null) {
      return _GateState.login;
    }

    try {
      final isAdmin = await _supabase.rpc('is_admin_account');

      if (isAdmin != true) {
        return _GateState.notAdmin;
      }

      final factors = await _supabase.auth.mfa.listFactors();

      final verified = factors.totp
          .where((f) => _isVerified(f.status))
          .toList();

      if (verified.isEmpty) {
        _factorId = null;
        return _GateState.enroll;
      }

      _factorId = verified.first.id;

      // Read the latest session AFTER all asynchronous operations.
      final latestSession = _supabase.auth.currentSession;

      if (latestSession == null) {
        return _GateState.login;
      }

      final aal = _jwtAal(latestSession.accessToken);

      debugPrint('Admin current AAL: $aal');

      if (aal == 'aal2') {
        return _GateState.ready;
      }

      return _GateState.verify;
    } catch (e, stack) {
      debugPrint('Admin gate error: $e');
      debugPrintStack(stackTrace: stack);

      return _GateState.error;
    }
  }

  Future<void> _signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _GateState.loading:
        return const Scaffold(
          backgroundColor: _background,
          body: Center(child: CircularProgressIndicator(color: _bronze)),
        );

      case _GateState.login:
        return const AdminLoginPage();

      case _GateState.notAdmin:
        return _MessageScreen(
          icon: Icons.block,
          title: 'Access denied',
          message: 'This account is not authorized to open the admin panel.',
          primaryLabel: 'Sign out',
          onPrimary: _signOut,
        );

      case _GateState.error:
        return _MessageScreen(
          icon: Icons.error_outline,
          title: 'Could not verify your access',
          message:
              'Check your connection and try again. If it keeps happening, '
              'make sure 01_visits_and_admin_gate.sql was run.',
          primaryLabel: 'Try again',
          onPrimary: _evaluate,
          secondaryLabel: 'Sign out',
          onSecondary: _signOut,
        );

      case _GateState.enroll:
        return _MfaEnrollView(onDone: _evaluate, onSignOut: _signOut);

      case _GateState.verify:
        return _MfaVerifyView(
          factorId: _factorId ?? '',
          onDone: _evaluate,
          onSignOut: _signOut,
        );

      case _GateState.ready:
        return const AdminDashboardPage();
    }
  }
}

// -----------------------------------------------------------------------------
// Shared UI
// -----------------------------------------------------------------------------

class _CardScaffold extends StatelessWidget {
  final List<Widget> children;

  const _CardScaffold({required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _surface,
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageScreen extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _MessageScreen({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return _CardScaffold(
      children: [
        Icon(icon, color: _bronze, size: 40),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _ivory, fontSize: 20),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onPrimary,
          style: ElevatedButton.styleFrom(
            backgroundColor: _bronze,
            foregroundColor: _background,
            minimumSize: const Size.fromHeight(48),
          ),
          child: Text(primaryLabel),
        ),
        if (secondaryLabel != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onSecondary,
            child: Text(secondaryLabel!, style: const TextStyle(color: _muted)),
          ),
        ],
      ],
    );
  }
}

class _CodeField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const _CodeField({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onSubmitted: (_) => onSubmit(),
      style: const TextStyle(color: _ivory, fontSize: 26, letterSpacing: 10),
      decoration: InputDecoration(
        counterText: '',
        hintText: '000000',
        hintStyle: const TextStyle(color: Color(0xFF55524D), letterSpacing: 10),
        filled: true,
        fillColor: _background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _bronze),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Code verification (every sign-in)
// -----------------------------------------------------------------------------

class _MfaVerifyView extends StatefulWidget {
  final String factorId;
  final Future<void> Function() onDone;
  final Future<void> Function() onSignOut;

  const _MfaVerifyView({
    required this.factorId,
    required this.onDone,
    required this.onSignOut,
  });

  @override
  State<_MfaVerifyView> createState() => _MfaVerifyViewState();
}

class _MfaVerifyViewState extends State<_MfaVerifyView> {
  final TextEditingController _codeController = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();

    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.mfa.challengeAndVerify(
        factorId: widget.factorId,
        code: code,
      );

      await widget.onDone();
    } on AuthException catch (e) {
      if (!mounted) return;
      _codeController.clear();
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Verification failed. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CardScaffold(
      children: [
        const Icon(Icons.verified_user_outlined, color: _bronze, size: 40),
        const SizedBox(height: 18),
        const Text(
          'Two-step verification',
          textAlign: TextAlign.center,
          style: TextStyle(color: _ivory, fontSize: 20),
        ),
        const SizedBox(height: 10),
        const Text(
          'Open your authenticator app and enter the 6-digit code for INNOVISTA.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 22),
        _CodeField(controller: _codeController, onSubmit: _verify),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _errorColor, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _busy ? null : _verify,
          style: ElevatedButton.styleFrom(
            backgroundColor: _bronze,
            foregroundColor: _background,
            minimumSize: const Size.fromHeight(48),
          ),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _background,
                  ),
                )
              : const Text('Verify'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : widget.onSignOut,
          child: const Text('Sign out', style: TextStyle(color: _muted)),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// One-time authenticator setup
// -----------------------------------------------------------------------------

class _MfaEnrollView extends StatefulWidget {
  final Future<void> Function() onDone;
  final Future<void> Function() onSignOut;

  const _MfaEnrollView({required this.onDone, required this.onSignOut});

  @override
  State<_MfaEnrollView> createState() => _MfaEnrollViewState();
}

class _MfaEnrollViewState extends State<_MfaEnrollView> {
  final TextEditingController _codeController = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String? _factorId;
  String? _secret;
  String? _error;
  String? _qrUri;
  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  bool _isVerified(Object? status) {
    final text = status.toString();
    return text == 'verified' || text.endsWith('.verified');
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final mfa = Supabase.instance.client.auth.mfa;

      // Remove half-finished setups from a previous attempt.
      final factors = await mfa.listFactors();
      for (final factor in factors.all) {
        if (!_isVerified(factor.status)) {
          await mfa.unenroll(factor.id);
        }
      }

      final response = await mfa.enroll(
        factorType: FactorType.totp,
        issuer: 'INNOVISTA',
        friendlyName: 'Admin',
      );

      if (!mounted) return;

      setState(() {
        _factorId = response.id;
        _secret = response.totp?.secret;
        _qrUri = response.totp?.uri;
      });
    } catch (e) {
      debugPrint('MFA enroll error: $e');

      if (!mounted) return;

      setState(() => _error = 'Could not start the setup. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    final factorId = _factorId;
    final code = _codeController.text.trim();

    if (factorId == null) return;

    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.mfa.challengeAndVerify(
        factorId: factorId,
        code: code,
      );

      await widget.onDone();
    } on AuthException catch (e) {
      if (!mounted) return;
      _codeController.clear();
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Verification failed. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _background,
        body: Center(child: CircularProgressIndicator(color: _bronze)),
      );
    }

    final secret = _secret;

    return _CardScaffold(
      children: [
        const Icon(Icons.security, color: _bronze, size: 40),
        const SizedBox(height: 18),
        const Text(
          'Set up two-step verification',
          textAlign: TextAlign.center,
          style: TextStyle(color: _ivory, fontSize: 20),
        ),
        const SizedBox(height: 10),
        const Text(
          '1. Install Google Authenticator, Microsoft Authenticator or Authy.\n'
          '2. Add an account and choose "Enter a setup key".\n'
          '3. Name it INNOVISTA and paste the key below.\n'
          '4. Type the 6-digit code the app shows.',
          style: TextStyle(color: _muted, fontSize: 13, height: 1.7),
        ),
        const SizedBox(height: 18),
        if (secret != null) ...[
          if (_qrUri != null && _qrUri!.isNotEmpty) ...[
            const Text(
              'Scan QR Code',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ivory,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: QrImageView(
                  data: _qrUri!,
                  version: QrVersions.auto,
                  size: 210,
                  backgroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Open Google Authenticator and scan this QR code.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12),
            ),

            const SizedBox(height: 20),
          ],

          const Text(
            'Or enter the setup key manually',
            textAlign: TextAlign.center,
            style: TextStyle(color: _ivory, fontSize: 13),
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _background,
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    secret,
                    style: const TextStyle(
                      color: _ivory,
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy key',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: secret));

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Setup key copied.')),
                    );
                  },
                  icon: const Icon(Icons.copy, color: _bronze, size: 18),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _CodeField(controller: _codeController, onSubmit: _confirm),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _errorColor, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
        if (secret != null)
          ElevatedButton(
            onPressed: _busy ? null : _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: _bronze,
              foregroundColor: _background,
              minimumSize: const Size.fromHeight(48),
            ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _background,
                    ),
                  )
                : const Text('Activate'),
          )
        else
          ElevatedButton(
            onPressed: _start,
            style: ElevatedButton.styleFrom(
              backgroundColor: _bronze,
              foregroundColor: _background,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Try again'),
          ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : widget.onSignOut,
          child: const Text('Sign out', style: TextStyle(color: _muted)),
        ),
      ],
    );
  }
}
