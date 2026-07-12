
import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class MonthYearContent extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onSelected;

  const MonthYearContent({
    required this.initialDate,
    required this.onSelected,
  });

  @override
  State<MonthYearContent> createState() => MonthYearContentState();
}

class MonthYearContentState extends State<MonthYearContent> {
  static const months = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];

  int selectedMonth = 0;
  int selectedYear = 2000;

  @override
  void initState() {
    selectedMonth = widget.initialDate.month - 1;
    selectedYear = widget.initialDate.year;
    super.initState();
  }

  Widget wheel({
    required int min,
    required int max,
    required int initial,
    required Function(int) onChanged,
    List<String>? labels,
    bool loop = false,
  }) {
    final count = max - min + 1;

    final controller = FixedExtentScrollController(
      initialItem: loop ? (1000 * count + (initial - min)) : (initial - min),
    );

    return SizedBox(
      width: 120,
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          /// 🔥 CENTER HIGHLIGHT (correct position)
          Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),

          /// 🔥 WHEEL (moved OUTSIDE container)
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 44,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (val) {
              final index = loop ? (val % count) : val;
              onChanged(min + index);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: loop ? null : count,
              builder: (context, index) {
                final realIndex = loop ? (index % count) : index;

                final text = labels != null
                    ? labels[realIndex]
                    : (min + realIndex).toString();

                return Center(child: AppText.p1(text, weight: FontWeight.w500));
              },
            ),
          ),
        ],
      ),
    );
  }

  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppText.h5("Select Month & Year", weight: FontWeight.w600),
                ButtonAnimations.press(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 40),

            Row(
              spacing: 50,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                /// Month (looping)
                wheel(
                  min: 0,
                  max: 11,
                  initial: selectedMonth,
                  labels: months,
                  loop: true,
                  onChanged: (v) => selectedMonth = v,
                ),

                /// Year (NOT looping)
                wheel(
                  min: 1800,
                  max: 4000,
                  initial: selectedYear,
                  loop: false,
                  onChanged: (v) => selectedYear = v,
                ),
              ],
            ),

            const SizedBox(height: 40),

            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: MyButton(
                    backgroundColor: kWhite,
                    buttonText: "Reset",
                    fontColor: kBlack,
                    onTap: () async {
                      setState(() {
                        selectedMonth = widget.initialDate.month - 1;
                        selectedYear = widget.initialDate.year;
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
                Expanded(
                  child: MyButton(
                    buttonText: "Done",
                    onTap: () async {
                      widget.onSelected(
                        DateTime(selectedYear, selectedMonth + 1),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
