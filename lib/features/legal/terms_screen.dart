import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textMuted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Terms & Conditions',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last updated: May 15, 2026',
            style: TextStyle(fontSize: 13, color: textMuted),
          ),
          const SizedBox(height: 20),

          _section(
            context,
            '1. Acceptance of Terms',
            'By downloading or using Split Circle, you agree to be bound by these terms. '
                'If you do not agree, please do not use the app.',
          ),
          _section(
            context,
            '2. Description of Service',
            'Split Circle is an expense-splitting application that helps users track shared expenses, '
                'split bills, and manage settlements between friends.',
          ),
          _section(
            context,
            '3. User Accounts',
            'You are responsible for maintaining the confidentiality of your account credentials. '
                'You must be at least 13 years old to use this service.',
          ),
          _section(
            context,
            '4. User Conduct',
            'You agree not to misuse the app for unlawful purposes, to impersonate others, '
                'or to interfere with the service\'s operation.',
          ),
          _section(
            context,
            '5. Financial Data',
            'Split Circle is a tracking tool only. We do not process payments or hold funds. '
                'All financial transactions between users occur outside the app. '
                'The app is not responsible for any disputes between users.',
          ),
          _section(
            context,
            '6. Limitation of Liability',
            'Split Circle is provided "as is" without warranties of any kind. '
                'We are not liable for any damages arising from your use of the app.',
          ),
          _section(
            context,
            '7. Termination',
            'We reserve the right to suspend or terminate accounts that violate these terms '
                'or engage in abusive behavior.',
          ),
          _section(
            context,
            '8. Governing Law',
            'These terms shall be governed by the laws of the jurisdiction in which the service operates.',
          ),
          _section(
            context,
            '9. Changes to Terms',
            'We may modify these terms at any time. Continued use of the app after changes '
                'constitutes acceptance of the new terms.',
          ),
          _section(
            context,
            '10. Contact',
            'For questions about these terms, contact us at support@splitcircle.app.',
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
