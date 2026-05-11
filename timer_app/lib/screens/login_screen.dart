import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoggingIn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.timer,
                  size: 100,
                  color: AppConstants.primaryBlue,
                ),
                const SizedBox(height: 24),
                const Text(
                  'HealthTimer',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryText,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '기록하며 성장하는 나만의 운동 타이머',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppConstants.secondaryText,
                  ),
                ),
                const SizedBox(height: 60),
                _buildGoogleLoginButton(),
                const SizedBox(height: 16),
                _buildKakaoLoginButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleLoginButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: _isLoggingIn
          ? null
          : () async {
              setState(() {
                _isLoggingIn = true;
              });

              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              bool success = await authProvider.signInWithGoogle();

              if (mounted) {
                setState(() {
                  _isLoggingIn = false;
                });
                
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('구글 로그인에 실패했습니다. 다시 시도해주세요.')),
                  );
                }
              }
            },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.g_mobiledata, size: 36, color: Colors.blue),
          ),
          const SizedBox(width: 8),
          const Text(
            'Google로 계속하기',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildKakaoLoginButton() {
    // 카카오 브랜드 컬러: #FEE500, 글자색: #000000 (85% opacity recommended, using black here for clarity)
    const Color kakaoColor = Color(0xFFFEE500); 
    
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: kakaoColor,
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0, // 카카오 로그인 버튼은 보통 그림자가 없습니다.
      ),
      onPressed: _isLoggingIn
          ? null
          : () async {
              setState(() {
                _isLoggingIn = true;
              });

              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              bool success = await authProvider.signInWithKakao();

              if (mounted) {
                setState(() {
                  _isLoggingIn = false;
                });
                
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('카카오 로그인에 실패했습니다. 다시 시도해주세요.')),
                  );
                }
              }
            },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble, size: 24, color: Colors.black),
          const SizedBox(width: 12),
          const Text(
            '카카오 로그인',
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w600, // 약간 더 굵게
              color: Colors.black87
            ),
          ),
        ],
      ),
    );
  }
}
