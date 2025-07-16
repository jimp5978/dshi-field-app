import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'main.dart';
import 'admin_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberCredentials = false;

  // Flask 서버 URL (실제 IP 주소 사용)
  String _serverUrl = 'http://203.251.108.199:5001';

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  // 저장된 서버 URL 로드
  Future<void> _loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverUrl = prefs.getString('server_url') ?? 'http://203.251.108.199:5001';
    });
  }
  
  
  // 저장된 아이디/비밀번호 로드
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberCredentials = prefs.getBool('remember_credentials') ?? false;
      if (_rememberCredentials) {
        _usernameController.text = prefs.getString('saved_username') ?? '';
        _passwordController.text = prefs.getString('saved_password') ?? '';
      }
    });
  }
  
  
  // 아이디/비밀번호 저장
  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_credentials', _rememberCredentials);
    if (_rememberCredentials) {
      await prefs.setString('saved_username', _usernameController.text);
      await prefs.setString('saved_password', _passwordController.text);
    } else {
      await prefs.remove('saved_username');
      await prefs.remove('saved_password');
    }
  }

  // 권한 레벨별 화면 이동
  void _navigateToMainScreen(Map<String, dynamic> user) {
    if (user['permission_level'] >= 5) {
      // Admin은 관리 화면으로
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => AdminDashboardScreen(userInfo: user),
        ),
      );
    } else {
      // 일반 사용자는 기존 화면으로
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => AssemblySearchScreen(userInfo: user),
        ),
      );
    }
  }

  // SHA256 해싱 함수
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<Map<String, dynamic>> _callLoginAPI(String username, String passwordHash) async {
    final url = Uri.parse('$_serverUrl/api/login');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'username': username,
        'password_hash': passwordHash,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('서버 오류: ${response.statusCode}');
    }
  }

  // 로그인 처리 함수
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String username = _usernameController.text.trim();
      String password = _passwordController.text;
      String passwordHash = _hashPassword(password);

      print('로그인 시도:');
      print('Username: $username');
      print('Password Hash: $passwordHash');

      // Flask 서버 API 호출
      final result = await _callLoginAPI(username, passwordHash);
      
      if (result['success'] == true) {
        final user = result['user'];
        final token = result['token'];
        final permissionLevel = user['permission_level'];
        
        // JWT 토큰을 SharedPreferences에 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        
        // 로그인 성공 시 아이디/비밀번호 저장 (체크박스가 선택된 경우)
        await _saveCredentials();
        
        if (mounted) {
          _showMessage('로그인 성공! ${user['full_name']} (Level $permissionLevel)');
          
          // 권한 레벨에 따른 화면 이동
          _navigateToMainScreen(user);
          
          print('로그인 성공:');
          print('User ID: ${user['id']}');
          print('Username: ${user['username']}');
          print('Full Name: ${user['full_name']}');
          print('Permission Level: $permissionLevel');
          print('Token saved: ${token.substring(0, 20)}...');
        }
      } else {
        if (mounted) {
          _showMessage(result['message'] ?? '로그인 실패');
        }
      }

    } catch (error) {
      if (mounted) {
        _showMessage('로그인 오류: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 메시지 표시 함수 (상단에 표시)
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150,
          right: 20,
          left: 20,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('DSHI Field Pad'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 로고 또는 제목
                const Icon(
                  Icons.account_circle,
                  size: 100,
                  color: Colors.blue,
                ),
                const SizedBox(height: 32),
                
                const Text(
                  'DSHI Field Pad',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                const Text(
                  '동성중공업 현장 관리 시스템',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 48),
                
                // 아이디 입력 필드
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: '아이디',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '아이디를 입력해주세요';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                
                const SizedBox(height: 16),
                
                // 비밀번호 입력 필드
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '비밀번호를 입력해주세요';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // 아이디/비밀번호 기억 체크박스
                Row(
                  children: [
                    Checkbox(
                      value: _rememberCredentials,
                      onChanged: (value) {
                        setState(() {
                          _rememberCredentials = value ?? false;
                        });
                      },
                    ),
                    const Text(
                      '아이디/비밀번호 기억',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // 로그인 버튼
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '로그인',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                
                const SizedBox(height: 16),
                
                
                const SizedBox(height: 16),
                
                // 서버 연결 테스트 버튼 (주석 처리 - 나중에 필요할 수 있음)
                // ElevatedButton(
                //   onPressed: _isLoading ? null : _testServerConnection,
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: Colors.orange,
                //     foregroundColor: Colors.white,
                //     padding: const EdgeInsets.symmetric(vertical: 16),
                //     shape: RoundedRectangleBorder(
                //       borderRadius: BorderRadius.circular(8),
                //     ),
                //   ),
                //   child: const Text(
                //     '서버 연결 테스트',
                //     style: TextStyle(
                //       fontSize: 18,
                //       fontWeight: FontWeight.bold,
                //     ),
                //   ),
                // ),
                
                const SizedBox(height: 24),
                
              ],
            ),
          ),
        ),
      ),
    );
  }
}
