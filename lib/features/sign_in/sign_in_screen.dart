import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/phone_number.dart';
import '../../core/constants/palette.dart';
import '../../core/constants/typography.dart';
import '../../core/design/luma_press.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/lamp_state.dart';
import '../../core/world/seed.dart';
import '../../widgets/lamp_mark.dart';
import '../../widgets/ui/lamp_ledger_ui.dart';

/// Sign in or register.
///
/// Two ways in, Google or a mobile number and a code, and both lead to the
/// same place: a person who already has a seat goes straight to it, and a
/// person who does not chooses one. The session is kept, so this is seen once,
/// not every launch.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

enum _Step { welcome, phone, code }

class _SignInScreenState extends State<SignInScreen> {
  static const int _codeLength = 6;
  static const Duration _resendAfter = Duration(seconds: 30);

  _Step _step = _Step.welcome;
  final _phone = TextEditingController();
  final _code = TextEditingController();
  PhoneChallenge? _challenge;

  bool _busy = false;
  String? _error;

  DateTime? _canResendAt;
  Timer? _ticker;

  // Registration.
  final _name = TextEditingController();
  bool _nameSeeded = false;
  PersonaId? _seat;
  String? _pharmacyDid;
  String? _mpoId;
  Msp? _bank;

  @override
  void dispose() {
    _ticker?.cancel();
    _phone.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  void _go(_Step step) => setState(() {
        _step = step;
        _error = null;
        _code.clear();
      });

  /// Run one sign-in action: show progress, and show a plain-language message
  /// if it fails. A dismissed Google sheet is not a failure.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthFailure catch (f) {
      if (!mounted) return;
      if (f.kind != AuthFailureKind.cancelled) {
        LumaHaptics.reject();
        setState(() => _error = f.message);
      }
    } catch (_) {
      if (!mounted) return;
      LumaHaptics.reject();
      setState(() => _error = AuthFailure.of(AuthFailureKind.other).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() =>
      _run(() => context.read<AuthController>().signInWithGoogle());

  Future<void> _sendCode() async {
    final phone = normalizePhone(_phone.text);
    if (phone == null) {
      setState(() => _error = AuthFailure.of(AuthFailureKind.invalidPhone).message);
      return;
    }
    await _run(() async {
      final challenge = await context.read<AuthController>().sendPhoneCode(phone);
      if (!mounted) return;
      _challenge = challenge;
      _startCooldown();
      _go(_Step.code);
    });
  }

  Future<void> _confirmCode() async {
    final challenge = _challenge;
    if (challenge == null || _code.text.length != _codeLength) return;
    await _run(() async {
      await context.read<AuthController>().confirmPhoneCode(challenge, _code.text);
    });
    if (mounted && _error != null) _code.clear();
  }

  void _startCooldown() {
    _canResendAt = DateTime.now().add(_resendAfter);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {});
      if (_resendRemaining == null) t.cancel();
    });
  }

  Duration? get _resendRemaining {
    final at = _canResendAt;
    if (at == null) return null;
    final left = at.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  bool get _canRegister {
    if (_seat == null) return false;
    return switch (_seat!) {
      PersonaId.pharmacy => _pharmacyDid != null,
      PersonaId.mpo => _mpoId != null,
      PersonaId.bank => _bank != null,
      _ => true,
    };
  }

  Future<void> _register() => _run(() => context.read<AuthController>().register(
        name: _name.text,
        seat: _seat!,
        pharmacyDid: _seat == PersonaId.pharmacy ? _pharmacyDid : null,
        mpoId: _seat == PersonaId.mpo ? _mpoId : null,
        bank: _seat == PersonaId.bank ? _bank : null,
      ));

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    final auth = context.watch<AuthController>();

    // While we are finding out whether this person already has a seat, show
    // only a waiting state. Anything else (above all the registration page)
    // would be a guess, and a wrong one for someone who is already registered.
    final holding = auth.resolvingProfile || auth.needsRegistration || auth.profileUnavailable;

    final Widget body;
    if (auth.resolvingProfile) {
      body = _resolving(context);
    } else if (auth.profileUnavailable) {
      body = _profileUnavailable(context, auth);
    } else if (auth.needsRegistration) {
      if (!_nameSeeded) {
        _nameSeeded = true;
        _name.text = auth.user?.suggestedName ?? '';
      }
      body = _registration(context, auth);
    } else {
      body = switch (_step) {
        _Step.welcome => _welcome(context),
        _Step.phone => _phoneStep(context),
        _Step.code => _codeStep(context),
      };
    }

    return PopScope(
      // Back steps toward the welcome page; from there it leaves the app.
      canPop: _step == _Step.welcome && !holding,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (holding) return;
        _go(_step == _Step.code ? _Step.phone : _Step.welcome);
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: body,
          ),
        ),
      ),
    );
  }

  /* ---------------------------------------------------------------------- */
  /* Welcome                                                                 */
  /* ---------------------------------------------------------------------- */

  Widget _welcome(BuildContext context) {
    final c = context.lamp;
    return ListView(
      key: const ValueKey('welcome'),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xxl, Gap.lg, Gap.xl),
      children: [
        const Center(child: LampMark(size: 72)),
        const SizedBox(height: Gap.lg),
        Text(
          'Welcome to LaMP',
          textAlign: TextAlign.center,
          style: LaMPType.title.copyWith(color: c.ink),
        ),
        const SizedBox(height: Gap.xs),
        Text(
          'Sign in, or register if you are new.',
          textAlign: TextAlign.center,
          style: LaMPType.body.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: Gap.xxl),
        ElevatedButton.icon(
          key: const ValueKey('google'),
          onPressed: _busy ? null : _google,
          icon: const Icon(Icons.account_circle_outlined, size: IconSize.md),
          label: const Text('Continue with Google'),
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        const SizedBox(height: Gap.md),
        OutlinedButton.icon(
          key: const ValueKey('use-phone'),
          onPressed: _busy ? null : () => _go(_Step.phone),
          icon: const Icon(Icons.smartphone_outlined, size: IconSize.md),
          label: const Text('Use my phone number'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        _errorText(context),
      ],
    );
  }

  /* ---------------------------------------------------------------------- */
  /* Phone                                                                   */
  /* ---------------------------------------------------------------------- */

  Widget _phoneStep(BuildContext context) {
    final c = context.lamp;
    return ListView(
      key: const ValueKey('phone'),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xl),
      children: [
        _backButton(context, () => _go(_Step.welcome)),
        const SizedBox(height: Gap.lg),
        Text('Your mobile number', style: LaMPType.title.copyWith(color: c.ink)),
        const SizedBox(height: Gap.xs),
        Text(
          "We'll send you a code to confirm it's you.",
          style: LaMPType.body.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: Gap.xl),
        _labelled(
          context,
          'Mobile number',
          TextField(
            key: const ValueKey('phone-field'),
            controller: _phone,
            autofocus: true,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            style: LaMPType.monoBody.copyWith(color: c.ink),
            decoration: const InputDecoration(
              hintText: '01711 204488',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            onSubmitted: (_) => _busy ? null : _sendCode(),
          ),
        ),
        _errorText(context),
        const SizedBox(height: Gap.xl),
        ElevatedButton(
          key: const ValueKey('send-code'),
          onPressed: _busy ? null : _sendCode,
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(_busy ? 'Sending…' : 'Send code'),
        ),
      ],
    );
  }

  Widget _codeStep(BuildContext context) {
    final c = context.lamp;
    final phone = _challenge?.phone ?? '';
    final left = _resendRemaining;
    return ListView(
      key: const ValueKey('code'),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xl),
      children: [
        _backButton(context, () => _go(_Step.phone)),
        const SizedBox(height: Gap.lg),
        Text('Enter the code', style: LaMPType.title.copyWith(color: c.ink)),
        const SizedBox(height: Gap.xs),
        Text(
          'We sent a $_codeLength-digit code to ${formatPhone(phone)}.',
          style: LaMPType.body.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: Gap.xl),
        TextField(
          key: const ValueKey('code-field'),
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: _codeLength,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: LaMPType.displayFigure.copyWith(color: c.ink),
          decoration: const InputDecoration(counterText: '', hintText: '••••••'),
          onChanged: (v) {
            setState(() => _error = null);
            if (v.length == _codeLength && !_busy) _confirmCode();
          },
        ),
        _errorText(context),
        const SizedBox(height: Gap.xl),
        ElevatedButton(
          key: const ValueKey('confirm-code'),
          onPressed: _busy || _code.text.length != _codeLength ? null : _confirmCode,
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(_busy ? 'Checking…' : 'Continue'),
        ),
        const SizedBox(height: Gap.md),
        TextButton(
          key: const ValueKey('resend'),
          onPressed: _busy || left != null ? null : _sendCode,
          child: Text(
            left == null ? 'Send the code again' : 'Send again in ${left.inSeconds + 1}s',
          ),
        ),
      ],
    );
  }

  /* ---------------------------------------------------------------------- */
  /* Registration                                                            */
  /* ---------------------------------------------------------------------- */

  Widget _registration(BuildContext context, AuthController auth) {
    final c = context.lamp;
    return ListView(
      key: const ValueKey('register'),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, Gap.xl),
      children: [
        Text('Finish registering', style: LaMPType.title.copyWith(color: c.ink)),
        const SizedBox(height: Gap.xs),
        Text(
          'Tell us who you are and we will open the right screen.',
          style: LaMPType.body.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: Gap.xxl),
        _labelled(
          context,
          'Your name',
          TextField(
            key: const ValueKey('name-field'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            style: LaMPType.body.copyWith(color: c.ink),
            decoration: const InputDecoration(hintText: 'Full name'),
          ),
        ),
        const SizedBox(height: Gap.xl),
        const LampEyebrow('I am a…'),
        const SizedBox(height: Gap.md),
        for (final s in PersonaId.values) ...[
          _roleTile(context, s),
          const SizedBox(height: Gap.sm),
        ],
        Text(
          'Manufacturer, bank and regulator accounts are set up by your LaMP '
          'administrator. Sign in once, then ask them to add you.',
          style: LaMPType.caption.copyWith(color: c.inkFaint),
        ),
        if (_seat == PersonaId.pharmacy) ...[
          const SizedBox(height: Gap.lg),
          _labelled(
            context,
            'Which pharmacy?',
            DropdownButtonFormField<String>(
              key: const ValueKey('pharmacy-field'),
              initialValue: _pharmacyDid,
              isExpanded: true,
              hint: const Text('Choose one'),
              items: [
                for (final p in SeedData.pharmacies)
                  DropdownMenuItem(
                    value: p.did,
                    child: Text('${p.name} · ${p.territory}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _pharmacyDid = v),
            ),
          ),
        ],
        if (_seat == PersonaId.mpo) ...[
          const SizedBox(height: Gap.lg),
          _labelled(
            context,
            'Which delivery round?',
            DropdownButtonFormField<String>(
              key: const ValueKey('mpo-field'),
              initialValue: _mpoId,
              isExpanded: true,
              hint: const Text('Choose one'),
              items: [
                for (final m in SeedData.mpos)
                  DropdownMenuItem(
                    value: m.id,
                    child: Text('${m.name} · ${m.territory}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _mpoId = v),
            ),
          ),
        ],
        if (_seat == PersonaId.bank) ...[
          const SizedBox(height: Gap.lg),
          _labelled(
            context,
            'Which bank?',
            DropdownButtonFormField<Msp>(
              key: const ValueKey('bank-field'),
              initialValue: _bank,
              isExpanded: true,
              hint: const Text('Choose one'),
              items: [
                for (final b in Msp.values.where((m) => m.kind == 'bank'))
                  DropdownMenuItem(value: b, child: Text(b.fullName)),
              ],
              onChanged: (v) => setState(() => _bank = v),
            ),
          ),
        ],
        _errorText(context),
        const SizedBox(height: Gap.xl),
        ElevatedButton(
          key: const ValueKey('register'),
          onPressed: _busy || !_canRegister ? null : _register,
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(_busy ? 'Registering…' : 'Register'),
        ),
        const SizedBox(height: Gap.sm),
        TextButton(
          key: const ValueKey('different-account'),
          onPressed: _busy ? null : () => auth.signOut(),
          child: const Text('Use a different account'),
        ),
      ],
    );
  }

  /// Seats anyone may take for themselves. Each is one pharmacy or one
  /// delivery round, claimed once (`firestore.rules`). The desk seats —
  /// manufacturer, bank, regulator — move money or oversee it, so picking one
  /// here would let anyone who signs in act as a bank; an administrator
  /// writes those profiles instead, and the rules refuse them from the app.
  static const _selfService = {PersonaId.pharmacy, PersonaId.mpo};

  Widget _roleTile(BuildContext context, PersonaId seat) {
    final c = context.lamp;
    final open = _selfService.contains(seat);
    final selected = _seat == seat;
    final (label, hint, icon) = switch (seat) {
      PersonaId.mpo => ('Delivery officer', 'Scan and hand over cartons', Icons.local_shipping_outlined),
      PersonaId.pharmacy => ('Pharmacy owner', 'Receive goods and build credit', Icons.local_pharmacy_outlined),
      PersonaId.manufacturer => ('Manufacturer', 'Set up by your administrator', Icons.factory_outlined),
      PersonaId.bank => ('Bank', 'Set up by your administrator', Icons.account_balance_outlined),
      PersonaId.regulator => ('Regulator', 'Set up by your administrator', Icons.verified_user_outlined),
    };
    return Semantics(
      selected: selected,
      button: open,
      enabled: open,
      label: label,
      child: InkWell(
        key: ValueKey('role-${seat.id}'),
        borderRadius: BorderRadius.circular(LaMPRadius.card),
        onTap: !open
            ? null
            : () {
                LumaHaptics.select();
                setState(() {
                  _seat = seat;
                  _error = null;
                });
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(LaMPRadius.card),
            border: Border.all(color: selected ? c.brand : c.line, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: IconSize.md,
                color: selected ? c.brand : (open ? c.inkMuted : c.inkFaint),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: LaMPType.sub.copyWith(color: open ? c.ink : c.inkFaint),
                    ),
                    Text(hint, style: LaMPType.caption.copyWith(color: c.inkFaint)),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, size: IconSize.md, color: c.brand),
            ],
          ),
        ),
      ),
    );
  }

  /// Between "signed in" and "we know your seat". Brief for someone already
  /// registered, so it is plain rather than decorated.
  Widget _resolving(BuildContext context) {
    final c = context.lamp;
    return Center(
      key: const ValueKey('resolving'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: c.inkMuted),
          ),
          const SizedBox(height: Gap.lg),
          Text(
            'Signing you in…',
            style: LaMPType.body.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _profileUnavailable(BuildContext context, AuthController auth) {
    final c = context.lamp;
    return Padding(
      key: const ValueKey('unavailable'),
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Couldn't open your account",
            textAlign: TextAlign.center,
            style: LaMPType.title.copyWith(color: c.ink),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'Check your connection and try again.',
            textAlign: TextAlign.center,
            style: LaMPType.body.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: Gap.xl),
          ElevatedButton(
            key: const ValueKey('retry'),
            onPressed: auth.retryProfile,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Try again'),
          ),
          TextButton(
            onPressed: auth.signOut,
            child: const Text('Use a different account'),
          ),
        ],
      ),
    );
  }

  /* ---------------------------------------------------------------------- */
  /* Shared bits                                                             */
  /* ---------------------------------------------------------------------- */

  /// A field with its label above it. A floating label sits half on the edge of
  /// a filled box and reads as clipped; a label of its own above the field is
  /// what the rest of the app does and stays legible on the dark surface.
  Widget _labelled(BuildContext context, String label, Widget field) {
    final c = context.lamp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: LaMPType.caption.copyWith(color: c.inkMuted)),
        const SizedBox(height: Gap.sm),
        field,
      ],
    );
  }

  Widget _backButton(BuildContext context, VoidCallback onTap) {
    final c = context.lamp;
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        tooltip: 'Back',
        icon: Icon(Icons.arrow_back, color: c.ink),
        onPressed: onTap,
      ),
    );
  }

  Widget _errorText(BuildContext context) {
    final c = context.lamp;
    return SizedBox(
      height: 48,
      child: Center(
        child: _error == null
            ? null
            : Text(
                _error!,
                textAlign: TextAlign.center,
                style: LaMPType.meta.copyWith(color: c.dispute),
              ),
      ),
    );
  }
}
