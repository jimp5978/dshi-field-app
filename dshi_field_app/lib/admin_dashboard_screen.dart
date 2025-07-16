import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'main.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userInfo;
  
  const AdminDashboardScreen({super.key, required this.userInfo});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _serverUrl = 'http://203.251.108.199:5001';
  final _serverUrlController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
    _loadUsers();
  }

  @override
  void dispose() {
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

  // 서버 연결 테스트
  Future<void> _testServerConnection() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('$_serverUrl/');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _showMessage('서버 연결 성공: ${data['message']}');
      } else {
        _showMessage('서버 연결 실패: ${response.statusCode}');
      }
    } catch (e) {
      _showMessage('서버 연결 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 사용자 목록 로드 (API 연동)
  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 저장된 토큰 가져오기
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      
      if (token == null) {
        _showMessage('로그인 토큰이 없습니다');
        return;
      }

      final url = Uri.parse('$_serverUrl/api/admin/users');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _users = List<Map<String, dynamic>>.from(data['users']);
          });
        } else {
          _showMessage('사용자 목록 로드 실패: ${data['message']}');
        }
      } else if (response.statusCode == 403) {
        _showMessage('Admin 권한이 필요합니다');
      } else {
        _showMessage('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      _showMessage('사용자 목록 로드 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 일반 사용자 화면으로 이동
  void _navigateToAssemblyScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => AssemblySearchScreen(userInfo: widget.userInfo),
      ),
    );
  }

  // 로그아웃 함수
  Future<void> _logout() async {
    try {
      // 저장된 토큰 제거
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      
      // 로그인 화면으로 이동
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/', 
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      _showMessage('로그아웃 오류: $e');
    }
  }

  // 새 사용자 생성 API 호출
  Future<void> _createUser(String username, String password, String fullName, String company, int permissionLevel) async {
    try {
      // 저장된 토큰 가져오기
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      
      if (token == null) {
        _showMessage('로그인 토큰이 없습니다');
        return;
      }

      final url = Uri.parse('$_serverUrl/api/admin/users');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'username': username,
          'password': password,
          'full_name': fullName,
          'company': company,
          'permission_level': permissionLevel,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _showMessage(data['message']);
          // 사용자 목록 새로고침
          _loadUsers();
        } else {
          _showMessage('사용자 생성 실패: ${data['message']}');
        }
      } else if (response.statusCode == 403) {
        _showMessage('Admin 권한이 필요합니다');
      } else {
        _showMessage('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      _showMessage('사용자 생성 오류: $e');
    }
  }

  // 새 사용자 생성 다이얼로그
  void _showCreateUserDialog() {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final fullNameController = TextEditingController();
    final companyController = TextEditingController();
    int selectedLevel = 1;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 사용자 생성'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'ID',
                  hintText: '영문, 숫자만 입력',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'PW',
                  hintText: '비밀번호 입력',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: fullNameController,
                decoration: const InputDecoration(
                  labelText: '이름',
                  hintText: '표시될 이름',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: companyController,
                decoration: const InputDecoration(
                  labelText: '회사',
                  hintText: '소속 회사',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedLevel,
                decoration: const InputDecoration(
                  labelText: '권한 레벨',
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Level 1 (외부업체)')),
                  DropdownMenuItem(value: 3, child: Text('Level 3 (DSHI 현장)')),
                  DropdownMenuItem(value: 5, child: Text('Level 5 (Admin)')),
                ],
                onChanged: (value) {
                  selectedLevel = value!;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (usernameController.text.isNotEmpty && 
                  passwordController.text.isNotEmpty && 
                  fullNameController.text.isNotEmpty) {
                Navigator.of(context).pop();
                _createUser(
                  usernameController.text,
                  passwordController.text,
                  fullNameController.text,
                  companyController.text,
                  selectedLevel,
                );
              }
            },
            child: const Text('생성'),
          ),
        ],
      ),
    );
  }

  // 사용자 수정 다이얼로그
  void _showEditUserDialog(Map<String, dynamic> user) {
    final fullNameController = TextEditingController(text: user['full_name']);
    final companyController = TextEditingController(text: user['company'] ?? '');
    final passwordController = TextEditingController();
    int selectedLevel = user['permission_level'];
    
    // 유효한 레벨 목록 생성
    List<int> validLevels = [1, 2, 3, 4, 5];
    if (!validLevels.contains(selectedLevel)) {
      validLevels.add(selectedLevel);
      validLevels.sort();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('사용자 수정: ${user['username']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fullNameController,
                decoration: const InputDecoration(
                  labelText: '이름',
                  hintText: '표시될 이름',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: companyController,
                decoration: const InputDecoration(
                  labelText: '회사',
                  hintText: '소속 회사',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'PW',
                  hintText: '새 비밀번호 (변경 시에만 입력)',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedLevel,
                decoration: const InputDecoration(
                  labelText: '권한 레벨',
                ),
                items: validLevels.map((level) {
                  String levelText;
                  if (level == 1) {
                    levelText = 'Level 1 (외부업체)';
                  } else if (level == 2) {
                    levelText = 'Level 2 (협력업체)';
                  } else if (level == 3) {
                    levelText = 'Level 3 (DSHI 현장)';
                  } else if (level == 4) {
                    levelText = 'Level 4 (DSHI 관리자)';
                  } else if (level == 5) {
                    levelText = 'Level 5 (Admin)';
                  } else {
                    levelText = 'Level $level';
                  }
                  return DropdownMenuItem(value: level, child: Text(levelText));
                }).toList(),
                onChanged: (value) {
                  selectedLevel = value!;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (fullNameController.text.isNotEmpty) {
                Navigator.of(context).pop();
                _updateUser(
                  user['id'],
                  fullNameController.text,
                  companyController.text,
                  selectedLevel,
                  passwordController.text.isNotEmpty ? passwordController.text : null,
                );
              }
            },
            child: const Text('수정'),
          ),
        ],
      ),
    );
  }

  // 사용자 수정 API 호출
  Future<void> _updateUser(int userId, String fullName, String company, int permissionLevel, String? password) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      
      if (token == null) {
        _showMessage('로그인 토큰이 없습니다');
        return;
      }

      final url = Uri.parse('$_serverUrl/api/admin/users/$userId');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'full_name': fullName,
          'company': company,
          'permission_level': permissionLevel,
          if (password != null) 'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _showMessage(data['message']);
          _loadUsers();
        } else {
          _showMessage('사용자 수정 실패: ${data['message']}');
        }
      } else if (response.statusCode == 403) {
        _showMessage('Admin 권한이 필요합니다');
      } else {
        _showMessage('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      _showMessage('사용자 수정 오류: $e');
    }
  }

  // 사용자 완전 삭제
  Future<void> _deleteUserPermanently(Map<String, dynamic> user) async {
    // 확인 다이얼로그
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사용자 완전 삭제'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${user['full_name']} 사용자를 완전히 삭제하시겠습니까?'),
            const SizedBox(height: 8),
            const Text(
              '⚠️ 이 작업은 되돌릴 수 없습니다!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('완전 삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      
      if (token == null) {
        _showMessage('로그인 토큰이 없습니다');
        return;
      }

      final url = Uri.parse('$_serverUrl/api/admin/users/${user['id']}/delete-permanently');
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _showMessage(data['message']);
          _loadUsers();
        } else {
          _showMessage('사용자 삭제 실패: ${data['message']}');
        }
      } else if (response.statusCode == 403) {
        _showMessage('Admin 권한이 필요합니다');
      } else {
        _showMessage('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      _showMessage('사용자 삭제 오류: $e');
    }
  }

  // 사용자 상태 토글 (활성화/비활성화)
  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    final bool currentStatus = (user['is_active'] == 1 || user['is_active'] == true);
    final String action = currentStatus ? '비활성화' : '활성화';
    
    // 확인 다이얼로그
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('사용자 $action'),
        content: Text('${user['full_name']} 사용자를 $action하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      
      if (token == null) {
        _showMessage('로그인 토큰이 없습니다');
        return;
      }

      if (currentStatus) {
        // 비활성화 (DELETE 요청)
        final url = Uri.parse('$_serverUrl/api/admin/users/${user['id']}');
        final response = await http.delete(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            _showMessage(data['message']);
            _loadUsers();
          } else {
            _showMessage('사용자 비활성화 실패: ${data['message']}');
          }
        } else {
          _showMessage('서버 오류: ${response.statusCode}');
        }
      } else {
        // 활성화 (PUT 요청)
        final url = Uri.parse('$_serverUrl/api/admin/users/${user['id']}');
        final response = await http.put(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode({
            'is_active': true,
          }),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            _showMessage(data['message']);
            _loadUsers();
          } else {
            _showMessage('사용자 활성화 실패: ${data['message']}');
          }
        } else {
          _showMessage('서버 오류: ${response.statusCode}');
        }
      }
    } catch (e) {
      _showMessage('사용자 상태 변경 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DSHI Admin Dashboard'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _navigateToAssemblyScreen,
            tooltip: '검색 화면으로',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 관리자 정보
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.admin_panel_settings, size: 40, color: Colors.red),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '관리자: ${widget.userInfo['full_name']}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text('권한: Level ${widget.userInfo['permission_level']}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 서버 설정 섹션
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.settings, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('서버 설정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _serverUrlController,
                            decoration: const InputDecoration(
                              labelText: '서버 주소',
                              hintText: 'http://203.251.108.199:5001',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              _serverUrl = value;
                              _saveServerUrl();
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _testServerConnection,
                                icon: const Icon(Icons.wifi_find),
                                label: const Text('연결 테스트'),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '현재: $_serverUrl',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 사용자 관리 섹션
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.people, color: Colors.green),
                              const SizedBox(width: 8),
                              const Text('사용자 관리', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              IconButton(
                                onPressed: _loadUsers,
                                icon: const Icon(Icons.refresh),
                                tooltip: '새로고침',
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _showCreateUserDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('사용자 추가'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: user['permission_level'] >= 5 
                                        ? Colors.red 
                                        : user['permission_level'] >= 3 
                                            ? Colors.orange 
                                            : Colors.blue,
                                    child: Text(
                                      user['permission_level'].toString(),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(user['full_name']),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('ID: ${user['username']} (${user['company'] ?? ''})'),
                                      if (user['created_at'] != null)
                                        Text(
                                          '생성일: ${user['created_at']}',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () {
                                          _showEditUserDialog(user);
                                        },
                                        tooltip: '수정',
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          (user['is_active'] == 1 || user['is_active'] == true) ? Icons.block : Icons.check_circle,
                                          color: (user['is_active'] == 1 || user['is_active'] == true) ? Colors.red : Colors.green,
                                        ),
                                        onPressed: () {
                                          _toggleUserStatus(user);
                                        },
                                        tooltip: (user['is_active'] == 1 || user['is_active'] == true) ? '비활성화' : '활성화',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                                        onPressed: () {
                                          _deleteUserPermanently(user);
                                        },
                                        tooltip: '완전 삭제',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}