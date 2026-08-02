import 'package:flutter/material.dart';
import 'home_screen.dart';

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key, required this.name});

  final String name;

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  int? _selectedGoal; // null = 아직 선택 안 함, 0/1/2 = 선택한 카드

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFBBF24), Color(0xFFF472B6)],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _gradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 93),
                // 전달받은 이름 표시!
                Text(
                  'Welcome!\n${widget.name}.',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 40,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Let's set your weekly goal.",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 32),
                _buildGoalCard(
                  index: 0,
                  title: 'Beginner',
                  subtitle: '3 cleans / week',
                  description: 'Perfect for starting a new habit',
                  selectedImage: 'assets/images/card_beginner.png',
                  unselectedImage: 'assets/images/card_beginner_unselected.png',
                ),
                const SizedBox(height: 14),
                _buildGoalCard(
                  index: 1,
                  title: 'Regular',
                  subtitle: '5 cleans / week',
                  description: 'Build a consistent routine',
                  selectedImage: 'assets/images/card_regular.png',
                  unselectedImage: 'assets/images/card_regular_unselected.png',
                ),
                const SizedBox(height: 14),
                _buildGoalCard(
                  index: 2,
                  title: 'Eco Hero',
                  subtitle: '7 cleans / week',
                  description: 'Make an impact every day',
                  selectedImage: 'assets/images/card_hero.png',
                  unselectedImage: 'assets/images/card_hero_unselected.png',
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _selectedGoal != null
                        ? () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => HomeScreen(name: widget.name),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      disabledBackgroundColor: Colors.black.withValues(
                        alpha: 0.35,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: _selectedGoal != null
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- 목표 선택 카드 ----------
  Widget _buildGoalCard({
    required int index,
    required String title,
    required String subtitle,
    required String description,
    required String selectedImage,
    required String unselectedImage,
  }) {
    final bool isSelected = _selectedGoal == index;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedGoal = index);
      },
      child: Container(
        width: double.infinity,
        height: 110, // 카드 높이 — 이미지 비율 보고 조절
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(isSelected ? selectedImage : unselectedImage),
            fit: BoxFit.fill,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
