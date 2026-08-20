import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/state/change_notifier_provider.dart';
import 'package:Obecno/features/employee_module/more/repositories/terms_provider.dart';
import 'package:Obecno/widgets/back_button.dart';
import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TermsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final termsProvider = context.read<TermsProvider>();

    return Scaffold(
      body: ListenableBuilder(
        listenable: termsProvider,
        builder: (context, _) {
          final terms = termsProvider.terms;
          final isInitialLoad = termsProvider.isLoading && terms == null;
          final showFallback =
              !isInitialLoad && terms == null && termsProvider.hasError;

          return RefreshIndicator(
            onRefresh: () => termsProvider.load(),
            child: ListView(
              padding: AppSizes.DEFAULT,
              children: [
                const SizedBox(height: 20),
                BackButtonBg(),
                const SizedBox(height: 20),
                AppText.h1("Terms of Use", align: TextAlign.left),
                const SizedBox(height: 6),
                AppText.p2(
                  terms?.updatedAt != null
                      ? "Last updated: ${terms!.updatedAt}"
                      : "Last updated: [Insert date]",
                  color: kGreyColor,
                  align: TextAlign.left,
                ),
                const SizedBox(height: 20),
                if (isInitialLoad)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
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
                else
                  _termsContent(terms?.content ?? ''),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _termsContent(String content) {
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
