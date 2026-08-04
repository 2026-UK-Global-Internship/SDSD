//goal_screen.dart
import 'character_color_screen.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:sdsd/server/services/auth_service.dart';

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key, required this.name});

  final String name;

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  int? _selectedGoal;
  bool _isLoading = false;

  final AuthService _authService = AuthService();

  static const List<String> _goalValues = ['beginner', 'regular', 'ecoHero'];

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFBBF24), Color(0xFFF472B6)],
  );

  Future<void> _handleContinue() async {
    if (_selectedGoal == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final uid = _authService.currentUserId;

      if (uid == null) {
        throw Exception('로그인된 사용자가 없습니다');
      }

      final goalValue = _goalValues[_selectedGoal!];

      await _authService.updateWeeklyGoal(uid, goalValue);
      await _authService.completeOnboarding(uid);

      // 저장 성공 → 홈 화면으로 이동
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CharacterColorScreen(name: widget.name),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 3),
      ),
    );
  }

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
                    onPressed: (_selectedGoal != null && !_isLoading)
                        ? _handleContinue
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
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
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
      onTap: _isLoading
          ? null
          : () {
              setState(() => _selectedGoal = index);
            },
      child: Container(
        width: double.infinity,
        height: 110,
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
