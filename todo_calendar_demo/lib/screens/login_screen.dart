import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return; // 중복 호출 방지
    
    if (!mounted) return;
    
    // 모든 예외를 안전하게 처리
    try {
      if (mounted) {
        setState(() => _isLoading = true);
      }
      
      // 안전하게 로그인 시도
      UserCredential? result;
      try {
        result = await AuthService.instance.signInWithGoogle().timeout(
          const Duration(seconds: 120), // 타임아웃 시간 증가
          onTimeout: () {
            throw TimeoutException('로그인 시간이 초과되었습니다.');
          },
        );
      } catch (e, stackTrace) {
        // 모든 예외를 로그에 기록
        debugPrint('Google 로그인 중 예외 발생: $e');
        debugPrint('스택 트레이스: $stackTrace');
        rethrow;
      }
      
      // 사용자가 취소한 경우 (null 반환)
      if (result == null) {
        if (mounted) {
          // 취소는 에러가 아니므로 조용히 처리
          setState(() => _isLoading = false);
        }
        return;
      }
      
      // 로그인 성공
      debugPrint('Google 로그인 성공');
      if (mounted) {
        // StreamBuilder가 자동으로 화면을 업데이트할 때까지 잠시 대기
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Google 로그인 최종 에러: $e');
      debugPrint('스택 트레이스: $stackTrace');
      
      if (mounted) {
        try {
          final errorMessage = e is TimeoutException 
              ? '로그인 시간이 초과되었습니다. 다시 시도해주세요.'
              : 'Google 로그인 실패: ${e.toString()}';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        } catch (snackError) {
          debugPrint('SnackBar 표시 중 오류: $snackError');
        }
      }
    } finally {
      if (mounted) {
        try {
          setState(() => _isLoading = false);
        } catch (e) {
          debugPrint('setState 오류: $e');
        }
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    if (_isLoading) return; // 중복 호출 방지
    
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final result = await AuthService.instance.signInWithApple().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('로그인 시간이 초과되었습니다.');
        },
      );
      
      // 사용자가 취소한 경우 (null 반환)
      if (result == null) {
        if (mounted) {
          // 취소는 에러가 아니므로 조용히 처리
          setState(() => _isLoading = false);
        }
        return;
      }
      // 로그인 성공 시 자동으로 StreamBuilder가 화면을 업데이트합니다
    } catch (e) {
      if (mounted) {
        final errorMessage = e is TimeoutException 
            ? '로그인 시간이 초과되었습니다. 다시 시도해주세요.'
            : 'Apple 로그인 실패: ${e.toString()}';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleKakaoSignIn() async {
    if (_isLoading) return; // 중복 호출 방지
    
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final result = await AuthService.instance.signInWithKakao().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('로그인 시간이 초과되었습니다.');
        },
      );
      
      // 사용자가 취소한 경우 (null 반환)
      if (result == null) {
        if (mounted) {
          // 취소는 에러가 아니므로 조용히 처리
          setState(() => _isLoading = false);
        }
        return;
      }
      // 로그인 성공 시 자동으로 StreamBuilder가 화면을 업데이트합니다
    } catch (e) {
      if (mounted) {
        final errorMessage = e is TimeoutException 
            ? '로그인 시간이 초과되었습니다. 다시 시도해주세요.'
            : '카카오톡 로그인 실패: ${e.toString()}';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 64,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                // 앱 로고/제목
                Text(
                  'Ordoo',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '할 일을 체계적으로 관리하세요',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 64),

                // 소셜 로그인 버튼들
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  Column(
                    children: [
                      // Google 로그인
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _handleGoogleSignIn,
                          icon: Image.asset(
                            'assets/google_logo.png',
                            width: 20,
                            height: 20,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.g_mobiledata, size: 20);
                            },
                          ),
                          label: const Text('Google로 로그인'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Apple 로그인 (iOS만)
                      if (Theme.of(context).platform == TargetPlatform.iOS)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _handleAppleSignIn,
                            icon: const Icon(Icons.apple, size: 20),
                            label: const Text('Apple로 로그인'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        ),
                      if (Theme.of(context).platform == TargetPlatform.iOS)
                        const SizedBox(height: 12),

                      // 카카오톡 로그인
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _handleKakaoSignIn,
                          icon: const Icon(Icons.chat, size: 20),
                          label: const Text('카카오톡으로 로그인'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 32),

                // 안내 문구
                Text(
                  '로그인하여 모든 기기에서\n할 일을 동기화하세요',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

