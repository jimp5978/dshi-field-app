import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverUrlController = TextEditingController();
  bool _isLoading = false;
  bool _showServerSettings = false;

  // Flask 서버 URL (실제 IP 주소 사용)
  String _serverUrl = 'http://203.251.108.199:5001';

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
    _serverUrlController.text = _serverUrl;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }
  
  // 저장된 서버 URL 로드
  Future<void> _loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverUrl = prefs.getString('server_url') ?? 'http://203.251.108.199:5001';
      _serverUrlController.text = _serverUrl;
    });
  }
  
  // 서버 URL 저장
  Future<void> _saveServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', _serverUrl);
  }

  // 권한 레벨별 화면 이동
  void _navigateToMainScreen(Map<String, dynamic> user) {
    // AssemblySearchScreen에서 레벨별 화면 분기 처리
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => AssemblySearchScreen(userInfo: user),
      ),
    );
  }

  // SHA256 해싱 함수
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Flask 서버 연결 테스트
  Future<void> _testServerConnection() async {
    try {
      final url = Uri.parse('$_serverUrl/');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('서버 연결 성공: ${data['message']}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('서버 연결 성공: ${data['message']}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        print('서버 연결 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('서버 연결 오류: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('서버 연결 오류: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('로그인 성공! ${user['full_name']} (Level $permissionLevel)'),
              backgroundColor: Colors.green,
            ),
          );
          
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '로그인 실패'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인 오류: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
                
                // 서버 설정 버튼
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showServerSettings = !_showServerSettings;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_showServerSettings ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                      const SizedBox(width: 4),
                      const Text('서버 설정'),
                    ],
                  ),
                ),
                
                // 서버 URL 입력 필드 (접을 수 있음)
                if (_showServerSettings) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _serverUrlController,
                    decoration: const InputDecoration(
                      labelText: '서버 주소',
                      prefixIcon: Icon(Icons.dns),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'http://203.251.108.199:5001',
                    ),
                    onChanged: (value) {
                      _serverUrl = value;
                      _saveServerUrl();
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '현재 서버: $_serverUrl',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                
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
                
                const SizedBox(height: 32),
                
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
                
                // 서버 연결 테스트 버튼
                ElevatedButton(
                  onPressed: _isLoading ? null : _testServerConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '서버 연결 테스트',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 테스트 계정 안내
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '사용자 계정:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('a / a (Admin - Level 5)'),
                      Text('seojin / 1234 (Level 1 - 외부업체)'),
                      Text('sookang / 1234 (Level 1 - 외부업체)'),
                      Text('gyeongin / 1234 (Level 1 - 외부업체)'),
                      Text('dshi_hy / 1234 (Level 3 - DSHI 현장직원)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
