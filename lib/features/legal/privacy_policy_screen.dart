import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textMuted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Privacy Policy',
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
            '1. Information We Collect',
            'We collect information you provide directly to us, including your name, email address, '
                'and financial information such as expense details and transaction history. '
                'We also collect usage data to improve our service.',
          ),
          _section(
            context,
            '2. How We Use Your Information',
            'We use the information we collect to provide, maintain, and improve our expense-splitting service, '
                'track expenses and settlements, and communicate with you about your account.',
          ),
          _section(
            context,
            '3. Data Sharing',
            'We do not sell your personal information. We may share your data with service providers who help '
                'us operate the app and as required by law.',
          ),
          _section(
            context,
            '4. Data Security',
            'We implement industry-standard security measures to protect your data, including encryption in transit '
                'and at rest. However, no method of transmission over the internet is 100%% secure.',
          ),
          _section(
            context,
            '5. Your Rights',
            'You can access, update, or delete your account information at any time through the app settings. '
                'You may also contact us to request data deletion or export.',
          ),
          _section(
            context,
            '6. Third-Party Services',
            'Split Circle uses Supabase for database and authentication services. '
                'Their privacy policy applies to data processed through their infrastructure.',
          ),
          _section(
            context,
            '7. Changes to This Policy',
            'We may update this privacy policy from time to time. We will notify you of any changes by posting '
                'the new policy in the app and updating the "Last updated" date.',
          ),
          _section(
            context,
            '8. Contact Us',
            'If you have any questions about this privacy policy, please contact us at support@splitcircle.app.',
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
