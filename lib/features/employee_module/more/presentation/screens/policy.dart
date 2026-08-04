import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/state/change_notifier_provider.dart';
import 'package:Obecno/features/employee_module/more/repositories/privacy_provider.dart';
import 'package:Obecno/widgets/back_button.dart';
import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';

class PolicyScreen extends StatefulWidget {
  const PolicyScreen({super.key});

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrivacyProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final privacyProvider = context.read<PrivacyProvider>();

    return Scaffold(
      body: ListenableBuilder(
        listenable: privacyProvider,
        builder: (context, _) {
          final privacy = privacyProvider.privacy;
          final isInitialLoad = privacyProvider.isLoading && privacy == null;
          final showFallback =
              !isInitialLoad && privacy == null && privacyProvider.hasError;

          return RefreshIndicator(
            onRefresh: () => privacyProvider.load(),
            child: ListView(
              padding: AppSizes.DEFAULT,
              children: [
                const SizedBox(height: 20),

                BackButtonBg(),

                const SizedBox(height: 20),

                /// ✅ Title (same spacing as Terms)
                AppText.h1("Privacy Policy", align: TextAlign.left),

                const SizedBox(height: 6),

                /// ✅ Last Updated (same structure)
                AppText.p2(
                  privacy?.updatedAt != null
                      ? "Last updated: ${privacy!.updatedAt}"
                      : "Last updated: [Insert date]",
                  color: kGreyColor,
                  align: TextAlign.left,
                ),

                const SizedBox(height: 20),

                /// ✅ Loading
                if (isInitialLoad)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                /// ✅ Fallback
                else if (showFallback)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: AppText.h6(
                        "Content not available",
                        align: TextAlign.center,
                        color: kGreyColor,
                      ),
                    ),
                  )
                /// ✅ Content
                else
                  _privacyContent(privacy?.content ?? ''),

                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _privacyContent(String content) {
    final paragraphs = content
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paragraphs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs
          .map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppText.h6(
                p,
                align: TextAlign.left,
                weight: FontWeight.w400,
              ),
            ),
          )
          .toList(),
    );
  }
}
