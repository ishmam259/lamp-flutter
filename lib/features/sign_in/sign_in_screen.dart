import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/accounts.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/constants/palette.dart';
import '../../core/constants/typography.dart';
import '../../core/design/luma_press.dart';
import '../../core/state/lamp_state.dart';
import '../../widgets/lamp_mark.dart';
import '../../widgets/ui/lamp_ledger_ui.dart';
import '../../widgets/ui/lamp_ui.dart';

/// Sign in: choose your account, then your PIN.
///
/// Replaces the seat picker, which let anyone open any seat. The first time
/// an account signs in on a phone it sets its PIN here; after that the PIN is
/// what opens it. The session is kept, so this is seen once, not every launch.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  Account? _account;
  String _pin = '';

  /// While creating a PIN: the first entry, waiting to be confirmed.
  String? _firstEntry;
  String? _error;
  Timer? _lockTicker;

  @override
  void dispose() {
    _lockTicker?.cancel();
    super.dispose();
  }

  void _choose(Account a) {
    LumaHaptics.select();
    setState(() {
      _account = a;
      _pin = '';
      _firstEntry = null;
      _error = null;
    });
  }

  void _back() => setState(() {
        _account = null;
        _pin = '';
        _firstEntry = null;
        _error = null;
      });

  Future<void> _digit(String d) async {
    final auth = context.read<AuthController>();
    if (auth.lockedFor != null || _pin.length >= AuthController.pinLength) return;
    LumaHaptics.select();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == AuthController.pinLength) await _submit(auth);
  }

  void _delete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit(AuthController auth) async {
    final account = _account!;
    final pin = _pin;

    if (!auth.hasPin(account)) {
      if (_firstEntry == null) {
        setState(() {
          _firstEntry = pin;
          _pin = '';
        });
        return;
      }
      if (_firstEntry != pin) {
        LumaHaptics.reject();
        setState(() {
          _firstEntry = null;
          _pin = '';
          _error = "Those PINs didn't match. Choose one again.";
        });
        return;
      }
      await auth.createPin(account, pin);
      return;
    }

    final ok = await auth.signIn(account, pin);
    if (ok || !mounted) return;
    LumaHaptics.reject();
    final locked = auth.lockedFor;
    setState(() {
      _pin = '';
      _error = locked == null
          ? 'Wrong PIN. Try again.'
          : 'Too many tries. Wait ${locked.inSeconds} seconds.';
    });
    if (locked != null) {
      _lockTicker?.cancel();
      _lockTicker = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        final left = auth.lockedFor;
        setState(() {
          _error = left == null ? null : 'Too many tries. Wait ${left.inSeconds} seconds.';
        });
        if (left == null) t.cancel();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    return PopScope(
      // Back from the PIN step returns to the list; from the list it leaves.
      canPop: _account == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _account == null
                ? _accountList(context)
                : _pinEntry(context, _account!),
          ),
        ),
      ),
    );
  }

  Widget _accountList(BuildContext context) {
    final c = context.lamp;
    final field = Accounts.all.where((a) => a.isField).toList();
    final desk = Accounts.all.where((a) => !a.isField).toList();

    return ListView(
      key: const ValueKey('accounts'),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xxl, Gap.lg, Gap.xl),
      children: [
        const Center(child: LampMark(size: 72)),
        const SizedBox(height: Gap.lg),
        Text(
          'Sign in to LaMP',
          textAlign: TextAlign.center,
          style: LaMPType.title.copyWith(color: c.ink),
        ),
        const SizedBox(height: Gap.xs),
        Text(
          'Choose your account',
          textAlign: TextAlign.center,
          style: LaMPType.body.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: Gap.xl),
        const LampEyebrow('In the field'),
        const SizedBox(height: Gap.md),
        for (final a in field) ...[
          _accountRow(context, a),
          const SizedBox(height: Gap.sm),
        ],
        const SizedBox(height: Gap.lg),
        const LampEyebrow('At the desk'),
        const SizedBox(height: Gap.md),
        for (final a in desk) ...[
          _accountRow(context, a),
          const SizedBox(height: Gap.sm),
        ],
      ],
    );
  }

  Widget _accountRow(BuildContext context, Account a) {
    final c = context.lamp;
    final icon = switch (a.seat) {
      PersonaId.mpo => Icons.local_shipping_outlined,
      PersonaId.pharmacy => Icons.local_pharmacy_outlined,
      PersonaId.manufacturer => Icons.factory_outlined,
      PersonaId.bank => Icons.account_balance_outlined,
      PersonaId.regulator => Icons.verified_user_outlined,
    };
    return LampCard(
      onTap: () => _choose(a),
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(LaMPRadius.control),
            ),
            child: Icon(icon, size: IconSize.md, color: c.inkMuted),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LaMPType.sub.copyWith(color: c.ink),
                ),
                Text(
                  '${a.org} · ${a.role}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: LaMPType.caption.copyWith(color: c.inkFaint),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: c.inkFaint),
        ],
      ),
    );
  }

  Widget _pinEntry(BuildContext context, Account a) {
    final c = context.lamp;
    final auth = context.watch<AuthController>();
    final creating = !auth.hasPin(a);
    final prompt = !creating
        ? 'Enter your PIN'
        : _firstEntry == null
            ? 'Choose a ${AuthController.pinLength}-digit PIN'
            : 'Enter it again to confirm';

    return Column(
      key: ValueKey('pin-${a.id}'),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Back',
            icon: Icon(Icons.arrow_back, color: c.ink),
            onPressed: _back,
          ),
        ),
        const Spacer(),
        Text(a.name, style: LaMPType.title.copyWith(color: c.ink)),
        const SizedBox(height: Gap.xs),
        Text(
          a.org,
          textAlign: TextAlign.center,
          style: LaMPType.body.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: Gap.xl),
        Text(prompt, style: LaMPType.sub.copyWith(color: c.ink)),
        if (creating && _firstEntry == null) ...[
          const SizedBox(height: Gap.xs),
          Text(
            "You'll use it to sign in on this phone.",
            style: LaMPType.caption.copyWith(color: c.inkFaint),
          ),
        ],
        const SizedBox(height: Gap.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < AuthController.pinLength; i++)
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: Gap.sm),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? c.ink : Colors.transparent,
                  border: Border.all(color: i < _pin.length ? c.ink : c.lineStrong, width: 1.5),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 40,
          child: Center(
            child: _error == null
                ? null
                : Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: LaMPType.meta.copyWith(color: c.dispute),
                  ),
          ),
        ),
        const Spacer(),
        _keypad(context),
        const SizedBox(height: Gap.xl),
      ],
    );
  }

  Widget _keypad(BuildContext context) {
    final c = context.lamp;
    Widget key(String label, {VoidCallback? onTap, Widget? child}) => SizedBox(
          width: 88,
          height: 64,
          child: TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: c.ink,
              shape: const StadiumBorder(),
            ),
            child: child ?? Text(label, style: LaMPType.figure.copyWith(color: c.ink)),
          ),
        );

    Widget row(List<String> digits) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [for (final d in digits) key(d, onTap: () => _digit(d))],
        );

    return Column(
      children: [
        row(['1', '2', '3']),
        row(['4', '5', '6']),
        row(['7', '8', '9']),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 88, height: 64),
            key('0', onTap: () => _digit('0')),
            key(
              '',
              onTap: _delete,
              child: Icon(Icons.backspace_outlined, color: c.inkMuted, semanticLabel: 'Delete'),
            ),
          ],
        ),
      ],
    );
  }
}
