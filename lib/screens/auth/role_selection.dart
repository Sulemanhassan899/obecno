import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/screens/auth/enable_permission.dart';
import 'package:Obecno/screens/auth/forgot_password.dart';
import 'package:Obecno/screens/bottom_nav_bars/employee_nav.dart';
import 'package:Obecno/screens/bottom_nav_bars/manager_nav.dart';
import 'package:Obecno/widgets/back_button.dart';
import 'package:Obecno/widgets/custom_checkbox_widget.dart';
import 'package:flutter/material.dart';
import '../../core/constants/all_colors.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/my_button.dart';
import '../../widgets/text_widget.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,

      body: Padding(
        padding: AppSizes.DEFAULT,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 10),

            /// BACK BUTTON
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Align(
                alignment: Alignment.centerLeft,
                child: BackButtonBg(
                  title: "Demo Role Selection ",
                  showBack: false,
                ),
              ),
            ),

            const SizedBox(height: 60),

            MyButton(
              buttonText: 'Manager',

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManagerBottomNavBar(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            MyButton(
              buttonText: 'Employee',

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EmployeeBottomNavBar(),
                  ),
                );
              },
            ),
            Spacer(),
          ],
        ),
      ),
    );
  }
}
