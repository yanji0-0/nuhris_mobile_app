import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/api_client_provider.dart';
import '../services/api_client.dart' show userMessageFor;

/// Step-up authentication before a sensitive operation (submitting records
/// to HR). The password is verified by Supabase Auth and never stored.
/// Returns true only when the server confirmed the password.
Future<bool> confirmIdentity(
  BuildContext context,
  WidgetRef ref, {
  required String action,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ConfirmIdentityDialog(action: action, ref: ref),
  );
  return confirmed ?? false;
}

class _ConfirmIdentityDialog extends StatefulWidget {
  const _ConfirmIdentityDialog({required this.action, required this.ref});

  final String action;
  final WidgetRef ref;

  @override
  State<_ConfirmIdentityDialog> createState() => _ConfirmIdentityDialogState();
}

class _ConfirmIdentityDialogState extends State<_ConfirmIdentityDialog> {
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final password = _passwordCtrl.text;
    if (password.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok =
          await widget.ref.read(apiClientProvider).reauthenticate(password);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = 'Incorrect password. Please try again.');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = userMessageFor(error));
    } finally {
      _passwordCtrl.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm it\'s you'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enter your NUHRIS password to ${widget.action}.'),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            enableSuggestions: false,
            autocorrect: false,
            autofocus: true,
            enabled: !_busy,
            onSubmitted: (_) => _verify(),
            decoration: InputDecoration(
              labelText: 'Password',
              errorText: _error,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirm'),
        ),
      ],
    );
  }
}
