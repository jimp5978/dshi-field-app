import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'login_screen.dart';

void main() {
  // 화면 회전 허용 설정
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const DSHIFieldApp());
}

class DSHIFieldApp extends StatelessWidget {
  const DSHIFieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DSHI Field Pad',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      // 로케일 설정 추가
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ko', 'KR'),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AssemblySearchScreen extends StatefulWidget {
  final Map<String, dynamic> userInfo;
  
  const AssemblySearchScreen({super.key, required this.userInfo});

  @override
  State<AssemblySearchScreen> createState() => _AssemblySearchScreenState();
}

enum SearchState {
  initial,    // 초기 상태 (검색 전)
  loading,    // 검색 중
  success,    // 검색 성공 (결과 있음)
  empty,      // 검색 성공 (결과 없음)
  error       // 검색 실패 (서버 오류 등)
}

class _AssemblySearchScreenState extends State<AssemblySearchScreen> {
  List<AssemblyItem> _searchResults = [];
  Set<int> _selectedItems = <int>{};
  List<AssemblyItem> _savedList = []; // 저장된 항목들
  bool _isLoading = false;
  SearchState _searchState = SearchState.initial;
  String _errorMessage = '';
  
  // 서버 URL (SharedPreferences에서 로드)
  String _serverUrl = 'http://203.251.108.199:5001';

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
  }

  // 저장된 서버 URL 로드
  Future<void> _loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverUrl = prefs.getString('server_url') ?? 'http://203.251.108.199:5001';
    });
  }

  // 검색 컨트롤러 추가
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // 실제 서버 API 호출
  Future<void> _onSearchPressed() async {
    String searchText = _searchController.text.trim();
    if (searchText.isEmpty) {
      _showMessage('검색어를 입력하세요');
      return;
    }

    setState(() {
      _isLoading = true;
      _searchState = SearchState.loading;
    });

    try {
      final url = Uri.parse('$_serverUrl/api/assemblies?search=$searchText');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          final List<dynamic> assembliesData = data['assemblies'] ?? [];
          
          setState(() {
            _searchResults = assembliesData.map((item) => AssemblyItem(
              assemblyNo: item['name'] ?? '',
              lastProcess: item['lastProcess'] ?? '',
              completedDate: item['completedDate'] ?? '',
              company: item['company'] ?? '',
              weightNet: (item['weight_net'] ?? 0.0).toDouble(),
            )).toList();
            _selectedItems.clear();
            // 검색 후 입력창 자동 삭제
            _searchController.clear();
            
            // 상태 업데이트
            if (_searchResults.isEmpty) {
              _searchState = SearchState.empty;
            } else {
              _searchState = SearchState.success;
              _showMessage('${_searchResults.length}개 결과를 찾았습니다');
            }
          });
        } else {
          setState(() {
            _searchResults = [];
            _searchState = SearchState.error;
            _errorMessage = data['message'] ?? '검색 실패';
          });
        }
      } else {
        setState(() {
          _searchResults = [];
          _searchState = SearchState.error;
          _errorMessage = '서버 연결 오류: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
        _searchState = SearchState.error;
        _errorMessage = '네트워크 오류: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 검색 결과를 상태별로 표시하는 함수
  Widget _buildSearchResults() {
    switch (_searchState) {
      case SearchState.initial:
        return const Center(
          child: Text(
            '입력창에 3자리 숫자를 입력하고\n검색을 누르세요',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        );
      case SearchState.loading:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                '검색 중...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );
      case SearchState.success:
        return ListView.builder(
          itemCount: _searchResults.length,
          itemBuilder: (context, index) {
            final item = _searchResults[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: CheckboxListTile(
                value: _selectedItems.contains(index),
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedItems.add(index);
                    } else {
                      _selectedItems.remove(index);
                    }
                  });
                },
                title: Text(
                  item.assemblyNo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEIGHT(NET): ${item.weightNet.toStringAsFixed(2)}kg',
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      '최종공정: ${item.lastProcess}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      '완료일자: ${item.completedDate}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            );
          },
        );
      case SearchState.empty:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              const Text(
                '검색 결과가 없습니다',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '다른 검색어를 시도해보세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );
      case SearchState.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              const Text(
                '검색 중 오류가 발생했습니다',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchState = SearchState.initial;
                    _errorMessage = '';
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
    }
  }

  // 메시지 표시 함수
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

  // 선택된 항목들의 총 중량 계산
  double _getSelectedItemsTotalWeight() {
    double totalWeight = 0.0;
    for (int index in _selectedItems) {
      if (index < _searchResults.length) {
        totalWeight += _searchResults[index].weightNet;
      }
    }
    return totalWeight;
  }

  // 로그아웃 기능
  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  // 저장된 리스트 보기 (새 화면으로)
  void _showSavedList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SavedListScreen(
          savedList: _savedList,
          onListUpdated: (updatedList) {
            setState(() {
              _savedList = updatedList;
            });
          },
        ),
      ),
    );
  }

  // 검사신청 확인 화면 (새 화면으로)
  void _showInspectionRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InspectionRequestScreen(userInfo: widget.userInfo),
      ),
    );
  }

  // LIST UP 버튼
  void _onListUpPressed() {
    if (_selectedItems.isNotEmpty) {
      // 선택된 항목들을 저장 리스트에 추가
      List<AssemblyItem> selectedAssemblies = [];
      for (int index in _selectedItems.toList()..sort((a, b) => b.compareTo(a))) {
        selectedAssemblies.add(_searchResults[index]);
        _savedList.add(_searchResults[index]);
      }
      
      // LIST 내에서 ASSEMBLY NO 기준으로 중복 제거 (나중에 추가된 것을 유지)
      Map<String, AssemblyItem> uniqueItems = {};
      for (AssemblyItem item in _savedList) {
        uniqueItems[item.assemblyNo] = item; // 같은 키면 덮어씀 (나중 것이 유지됨)
      }
      _savedList = uniqueItems.values.toList();
      
      // 선택된 항목들을 검색 결과에서 제거 (역순으로 제거)
      for (int index in _selectedItems.toList()..sort((a, b) => b.compareTo(a))) {
        _searchResults.removeAt(index);
      }
      
      setState(() {
        _selectedItems.clear();
      });
      
      _showMessage('${selectedAssemblies.length}개 항목이 리스트에 저장되었습니다');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.userInfo;
    final int permissionLevel = user['permission_level'];
    
    return Scaffold(
      appBar: AppBar(
        title: Text('DSHI Field Pad - ${user['full_name']} (Level ${user['permission_level']})'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 상단 버튼 영역 (LIST, 검사신청확인)
            Row(
              children: [
                // LIST 버튼
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showSavedList,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(0, 48),
                    ),
                    child: Text(
                      'LIST (${_savedList.length})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 검사신청 확인 버튼
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showInspectionRequests,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text(
                      '검사신청 확인',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // 검색 입력창 (안드로이드 기본 키패드 사용)
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                _onSearchPressed();
                // 검색 후 키패드 유지를 위해 포커스 유지
                Future.delayed(const Duration(milliseconds: 50), () {
                  _searchFocusNode.requestFocus();
                });
              },
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'ASSEMBLY 코드 입력',
                hintStyle: const TextStyle(
                  fontSize: 20,
                  color: Colors.grey,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue, width: 3),
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 검색 결과 리스트 영역
            Expanded(
              child: _buildSearchResults(),
            ),
            
            const SizedBox(height: 20),
            
            // 선택된 항목 정보 표시
            if (_selectedItems.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Text(
                  '선택된 항목: ${_selectedItems.length}개 (총 중량: ${_getSelectedItemsTotalWeight().toStringAsFixed(2)}kg)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            
            // 하단 LIST UP 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _onListUpPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'LIST UP',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

// 저장된 리스트 화면 (새로운 페이지)
class SavedListScreen extends StatefulWidget {
  final List<AssemblyItem> savedList;
  final Function(List<AssemblyItem>) onListUpdated;

  const SavedListScreen({
    super.key,
    required this.savedList,
    required this.onListUpdated,
  });

  @override
  State<SavedListScreen> createState() => _SavedListScreenState();
}

class _SavedListScreenState extends State<SavedListScreen> {
  late List<AssemblyItem> _savedList;
  Set<int> _selectedItems = <int>{};
  bool _selectAll = false;
  late DateTime _selectedDate; // 기본값을 내일로 설정
  
  // 서버 URL (SharedPreferences에서 로드)
  String _serverUrl = 'http://203.251.108.199:5001';

  // 전체 항목들의 총 중량 계산
  double _getTotalWeight() {
    double totalWeight = 0.0;
    for (AssemblyItem item in _savedList) {
      totalWeight += item.weightNet;
    }
    return totalWeight;
  }

  // 선택된 항목들의 총 중량 계산
  double _getSelectedItemsTotalWeight() {
    double totalWeight = 0.0;
    for (int index in _selectedItems) {
      if (index < _savedList.length) {
        totalWeight += _savedList[index].weightNet;
      }
    }
    return totalWeight;
  }

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
    _savedList = List.from(widget.savedList);
    // 기본값을 내일로 설정
    _selectedDate = DateTime.now().add(const Duration(days: 1));
  }

  // 저장된 서버 URL 로드
  Future<void> _loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverUrl = prefs.getString('server_url') ?? 'http://203.251.108.199:5001';
    });
  }

  // 전체 선택/해제
  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedItems = Set.from(List.generate(_savedList.length, (index) => index));
      } else {
        _selectedItems.clear();
      }
    });
  }

  // 선택된 항목들 삭제
  void _deleteSelectedItems() {
    if (_selectedItems.isNotEmpty) {
      setState(() {
        // 역순으로 삭제하여 인덱스 오류 방지
        for (int index in _selectedItems.toList()..sort((a, b) => b.compareTo(a))) {
          _savedList.removeAt(index);
        }
        _selectedItems.clear();
        _selectAll = false;
      });
      
      // 변경사항을 부모 위젯에 전달
      widget.onListUpdated(_savedList);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('선택된 항목들이 삭제되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // 전체 삭제
  void _deleteAllItems() {
    setState(() {
      _savedList.clear();
      _selectedItems.clear();
      _selectAll = false;
    });
    
    widget.onListUpdated(_savedList);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('전체 항목이 삭제되었습니다'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 날짜 선택 (오늘 이후만 선택 가능)
  void _selectDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now, // 오늘부터 선택 가능
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // 검사 신청 (조건 검사 및 확인 팝업)
  void _requestInspection() {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('검사신청할 항목을 선택해주세요'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('먼저 날짜를 선택해주세요'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // 선택된 항목들의 최종공정 확인
    Map<String, List<AssemblyItem>> processByItems = {};
    
    for (int index in _selectedItems) {
      AssemblyItem item = _savedList[index];
      if (!processByItems.containsKey(item.lastProcess)) {
        processByItems[item.lastProcess] = [];
      }
      processByItems[item.lastProcess]!.add(item);
    }
    
    // 다른 공정이 섞여 있는지 확인
    if (processByItems.length > 1) {
      // 가장 많은 공정 찾기 (정상 공정)
      String majorProcess = '';
      int maxCount = 0;
      for (String process in processByItems.keys) {
        if (processByItems[process]!.length > maxCount) {
          maxCount = processByItems[process]!.length;
          majorProcess = process;
        }
      }
      
      // 소수 공정들의 ASSEMBLY NO 수집 (에러 항목들)
      List<String> minorityItems = [];
      for (String process in processByItems.keys) {
        if (process != majorProcess) {
          for (AssemblyItem item in processByItems[process]!) {
            minorityItems.add('${item.assemblyNo} ($process)');
          }
        }
      }
      
      // 경고 팝업창 표시
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('검사신청 불가'),
            content: Text(
              '다른 공정을 가진 항목이 포함되어 있습니다\n\n'
              '다른 공정: ${minorityItems.join(', ')}\n\n'
              '같은 공정끼리만 신청 가능합니다',
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('확인'),
              ),
            ],
          );
        },
      );
      return;
    }
    
    // 확인 팝업 표시
    String currentProcess = processByItems.keys.first;
    String nextProcess = _getNextProcess(currentProcess);
    List<AssemblyItem> selectedAssemblies = processByItems[currentProcess]!;
    String firstAssemblyNo = selectedAssemblies.first.assemblyNo;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('검사 신청 확인'),
          content: Text(
            '$firstAssemblyNo 외 ${selectedAssemblies.length - 1}개의 제품을\n'
            '${_formatDate(_selectedDate)}일로 $nextProcess 검사를\n'
            '신청하시겠습니까?',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _submitInspectionRequest(selectedAssemblies, nextProcess);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('신청'),
            ),
          ],
        );
      },
    );
  }
  
  // 다음 공정 반환 (8단계 ARUP_ECS 프로젝트)
  String _getNextProcess(String currentProcess) {
    const Map<String, String> processMap = {
      'FIT-UP': 'FINAL',
      'FINAL': 'ARUP_FINAL',
      'ARUP_FINAL': 'GALV',
      'GALV': 'ARUP_GALV',
      'ARUP_GALV': 'SHOT',
      'SHOT': 'PAINT',
      'PAINT': 'ARUP_PAINT',
    };
    return processMap[currentProcess] ?? '완료';
  }
  
  // 검사 신청 제출 (실제 API 호출)
  Future<void> _submitInspectionRequest(List<AssemblyItem> items, String nextProcess) async {
    try {
      // 저장된 토큰 가져오기 (로그인 시 저장된 토큰)
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      
      if (token == null) {
        _showMessage('로그인이 필요합니다');
        return;
      }

      // ASSEMBLY 코드 리스트 생성
      final List<String> assemblyCodes = items.map((item) => item.assemblyNo).toList();
      
      // API 호출
      final url = Uri.parse('${_serverUrl}/api/inspection-requests');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'assembly_codes': assemblyCodes,
          'inspection_type': nextProcess,
          'request_date': _formatDate(_selectedDate),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          // 성공한 항목들만 LIST에서 제거
          int insertedCount = data['inserted_count'] ?? 0;
          List<dynamic> duplicateItems = data['duplicate_items'] ?? [];
          
          if (insertedCount > 0) {
            // 성공한 항목들을 LIST에서 제거 (전체가 아닌 성공한 개수만큼)
            setState(() {
              // 간단하게 성공한 만큼 앞에서부터 제거 (실제로는 더 정교한 로직 필요)
              for (int i = 0; i < insertedCount && items.isNotEmpty; i++) {
                _savedList.remove(items[i]);
              }
              _selectedItems.clear();
              _selectAll = false;
            });
            widget.onListUpdated(_savedList);
          }
          
          // 중복 항목이 있으면 상세 팝업 표시
          if (duplicateItems.isNotEmpty) {
            _showDuplicateDialog(data['message'], duplicateItems);
          } else {
            // 모두 성공 시 간단한 메시지
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['message'] ?? '검사신청이 완료되었습니다'),
                duration: const Duration(seconds: 3),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // 모두 실패 (모든 항목이 중복인 경우)
          List<dynamic> duplicateItems = data['duplicate_items'] ?? [];
          if (duplicateItems.isNotEmpty) {
            _showDuplicateDialog(data['message'], duplicateItems);
          } else {
            _showMessage(data['message'] ?? '검사신청 실패');
          }
        }
      } else {
        _showMessage('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      _showMessage('네트워크 오류: $e');
    }
  }

  // 메시지 표시 함수
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
  
  // 중복 항목 상세 팝업
  void _showDuplicateDialog(String message, List<dynamic> duplicateItems) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('검사신청 결과'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (duplicateItems.isNotEmpty) ...[
                const Text(
                  '이미 신청된 항목:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...duplicateItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${item['assembly_code']} (${item['existing_requester']} - ${item['existing_date']})',
                    style: const TextStyle(fontSize: 12),
                  ),
                )).toList(),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }
  
  // 날짜 포맷팅
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text('저장된 리스트 (${_savedList.length}개)'),
            Text(
              '총 중량: ${_getTotalWeight().toStringAsFixed(2)}kg',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 상단 버튼들 (3개 가로 배치)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 전체 선택 버튼
                Expanded(
                  child: ElevatedButton(
                    onPressed: _toggleSelectAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 45),
                    ),
                    child: Text(
                      _selectAll ? '전체해제' : '전체선택',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 선택 삭제 버튼
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedItems.isNotEmpty ? _deleteSelectedItems : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 45),
                    ),
                    child: Text(
                      '선택삭제(${_selectedItems.length})',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 전체 삭제 버튼
                Expanded(
                  child: ElevatedButton(
                    onPressed: _deleteAllItems,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 45),
                    ),
                    child: const Text(
                      '전체삭제',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 리스트
          Expanded(
            child: _savedList.isEmpty
                ? const Center(
                    child: Text(
                      '저장된 항목이 없습니다',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _savedList.length,
                    itemBuilder: (context, index) {
                      final item = _savedList[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: CheckboxListTile(
                          value: _selectedItems.contains(index),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedItems.add(index);
                              } else {
                                _selectedItems.remove(index);
                              }
                              
                              // 전체 선택 상태 업데이트
                              _selectAll = _selectedItems.length == _savedList.length;
                            });
                          },
                          title: Text(
                            item.assemblyNo,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('WEIGHT(NET): ${item.weightNet.toStringAsFixed(2)}kg'),
                              Text('최종공정: ${item.lastProcess}'),
                              Text('완료일자: ${item.completedDate}'),
                            ],
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      );
                    },
                  ),
          ),
          
          // 선택된 항목들의 중량 정보 표시
          if (_selectedItems.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.scale, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '선택된 ${_selectedItems.length}개 항목 총 중량: ${_getSelectedItemsTotalWeight().toStringAsFixed(2)}kg',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // 하단 신규 버튼들 (날짜선택, 검사신청)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 날짜 선택 버튼
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectDate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 50),
                    ),
                    child: Text(
                      _formatDate(_selectedDate), // 항상 내일 날짜 표시
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 검사 신청 버튼
                Expanded(
                  child: ElevatedButton(
                    onPressed: _requestInspection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 50),
                    ),
                    child: const Text(
                      '검사신청',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 검사신청 확인 화면
class InspectionRequestScreen extends StatefulWidget {
  final Map<String, dynamic> userInfo;

  const InspectionRequestScreen({super.key, required this.userInfo});

  @override
  State<InspectionRequestScreen> createState() => _InspectionRequestScreenState();
}

class _InspectionRequestScreenState extends State<InspectionRequestScreen> {
  DateTime _selectedDate = DateTime.now();
  List<InspectionRequest> _inspectionRequests = [];
  List<InspectionRequest> _allInspectionRequests = []; // 필터링 전 전체 데이터
  bool _isLoading = false;
  Set<int> _selectedItems = <int>{}; // 선택된 항목 인덱스
  bool _selectAll = false; // 전체 선택 상태
  
  // Level 3+ 전용 필터링 변수
  List<String> _availableRequesters = [];
  String? _selectedRequester;
  List<String> _availableProcessTypes = [];
  String? _selectedProcessType;
  
  // 서버 URL (SharedPreferences에서 로드)
  String _serverUrl = 'http://203.251.108.199:5001';

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
    _loadInspectionRequests();
  }

  // 저장된 서버 URL 로드
  Future<void> _loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverUrl = prefs.getString('server_url') ?? 'http://203.251.108.199:5001';
    });
  }

  // 검사신청 목록 로드 (실제 API 호출)
  Future<void> _loadInspectionRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 저장된 토큰 가져오기
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      
      if (token == null) {
        _showMessage('로그인이 필요합니다');
        return;
      }

      // API 호출 (날짜별 필터링만)
      final String dateParam = _formatDate(_selectedDate);
      String urlString = '$_serverUrl/api/inspection-requests?date=$dateParam';
      
      final url = Uri.parse(urlString);
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          setState(() {
            // 취소된 항목 제외하고 목록 생성
            List<InspectionRequest> allRequests = (data['requests'] as List)
                .where((requestData) => requestData['status'] != '취소됨')
                .map((requestData) {
              // 날짜 파싱 개선 (다양한 형식 지원)
              DateTime requestDate;
              try {
                String dateStr = requestData['request_date'];
                // GMT 형식 처리
                if (dateStr.contains('GMT')) {
                  requestDate = DateTime.parse(dateStr);
                } else {
                  requestDate = DateTime.parse(dateStr);
                }
              } catch (e) {
                // 파싱 실패 시 현재 날짜 사용
                print('날짜 파싱 오류: ${requestData['request_date']} - $e');
                requestDate = DateTime.now();
              }
              
              // 승인일/확정일 파싱
              DateTime? approvedDate;
              DateTime? confirmedDate;
              
              if (requestData['approved_date'] != null) {
                try {
                  String approvedDateStr = requestData['approved_date'];
                  // GMT 형식 또는 일반 형식 처리
                  if (approvedDateStr.contains('GMT')) {
                    approvedDate = DateTime.parse(approvedDateStr);
                  } else {
                    approvedDate = DateTime.parse(approvedDateStr);
                  }
                } catch (e) {
                  print('승인일 파싱 오류: ${requestData['approved_date']} - $e');
                  // 파싱 실패 시 null 유지
                  approvedDate = null;
                }
              }
              
              if (requestData['confirmed_date'] != null) {
                try {
                  String confirmedDateStr = requestData['confirmed_date'];
                  // GMT 형식 또는 일반 형식 처리
                  if (confirmedDateStr.contains('GMT')) {
                    confirmedDate = DateTime.parse(confirmedDateStr);
                  } else {
                    confirmedDate = DateTime.parse(confirmedDateStr);
                  }
                } catch (e) {
                  print('확정일 파싱 오류: ${requestData['confirmed_date']} - $e');
                  // 파싱 실패 시 null 유지
                  confirmedDate = null;
                }
              }
              
              return InspectionRequest(
                id: requestData['id'],
                assemblyNo: requestData['assembly_code'],
                requestDate: requestDate,
                inspectionType: requestData['inspection_type'],
                requestedBy: requestData['requested_by_name'],
                status: requestData['status'] ?? '대기중',
                approvedBy: requestData['approved_by_name'],
                approvedDate: approvedDate,
                confirmedDate: confirmedDate,
              );
            }).toList();
            
            // 전체 데이터 저장 (필터 옵션 생성용)
            _allInspectionRequests = List.from(allRequests);
            
            // 클라이언트 측 필터링 적용 (Level 3+만)
            if (widget.userInfo['permission_level'] >= 3) {
              if (_selectedRequester != null) {
                allRequests = allRequests.where((request) => 
                    request.requestedBy == _selectedRequester).toList();
              }
              if (_selectedProcessType != null) {
                allRequests = allRequests.where((request) => 
                    request.inspectionType == _selectedProcessType).toList();
              }
            }
            
            _inspectionRequests = allRequests;
            
            // 전체 선택 상태 초기화
            _selectedItems.clear();
            _selectAll = false;
            
            // 필터 옵션 업데이트 (전체 데이터 기반)
            _updateAvailableFilters();
          });
        } else {
          _showMessage(data['message'] ?? '데이터 로딩 실패');
        }
      } else {
        _showMessage('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      _showMessage('네트워크 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 날짜 선택
  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadInspectionRequests();
    }
  }

  // 메시지 표시
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

  // 전체 데이터에서 실제 존재하는 신청자/공정 목록 추출
  void _updateAvailableFilters() {
    if (widget.userInfo['permission_level'] >= 3) {
      // 전체 데이터에서 신청자들만 추출 (중복 제거)
      Set<String> requesters = _allInspectionRequests
          .map((request) => request.requestedBy)
          .toSet();
      
      // 전체 데이터에서 공정 타입들만 추출 (중복 제거)
      Set<String> processTypes = _allInspectionRequests
          .map((request) => request.inspectionType)
          .toSet();
      
      setState(() {
        _availableRequesters = requesters.toList()..sort();
        _availableProcessTypes = processTypes.toList()..sort();
        
        // 선택된 필터가 전체 데이터에 없으면 초기화
        if (_selectedRequester != null && !requesters.contains(_selectedRequester)) {
          _selectedRequester = null;
        }
        if (_selectedProcessType != null && !processTypes.contains(_selectedProcessType)) {
          _selectedProcessType = null;
        }
      });
    }
  }

  // 클라이언트 측 필터링 적용
  void _applyClientSideFiltering() {
    if (widget.userInfo['permission_level'] >= 3) {
      setState(() {
        List<InspectionRequest> filteredRequests = List.from(_allInspectionRequests);
        
        // 신청자 필터 적용
        if (_selectedRequester != null) {
          filteredRequests = filteredRequests.where((request) => 
              request.requestedBy == _selectedRequester).toList();
        }
        
        // 공정별 필터 적용
        if (_selectedProcessType != null) {
          filteredRequests = filteredRequests.where((request) => 
              request.inspectionType == _selectedProcessType).toList();
        }
        
        _inspectionRequests = filteredRequests;
        
        // 선택 상태 초기화
        _selectedItems.clear();
        _selectAll = false;
      });
    }
  }

  // 전체 선택/해제 토글
  void _toggleSelectAll() {
    setState(() {
      if (_selectAll) {
        // 전체 해제
        _selectedItems.clear();
        _selectAll = false;
      } else {
        // 전체 선택
        _selectedItems.clear();
        for (int i = 0; i < _inspectionRequests.length; i++) {
          _selectedItems.add(i);
        }
        _selectAll = true;
      }
    });
  }

  // 날짜 포맷팅
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  // 상태별 색상과 아이콘 반환
  Map<String, dynamic> _getStatusStyle(String status) {
    switch (status) {
      case '대기중':
        return {
          'color': Colors.orange,
          'icon': Icons.schedule,
          'emoji': '🟡'
        };
      case '승인됨':
        return {
          'color': Colors.green,
          'icon': Icons.check_circle,
          'emoji': '🟢'
        };
      case '확정됨':
        return {
          'color': Colors.blue,
          'icon': Icons.verified,
          'emoji': '🔵'
        };
      case '취소됨':
        return {
          'color': Colors.red,
          'icon': Icons.cancel,
          'emoji': '❌'
        };
      default:
        return {
          'color': Colors.grey,
          'icon': Icons.help,
          'emoji': '❓'
        };
    }
  }
  
  // 선택된 항목들 취소 (Level별 권한 적용)
  Future<void> _cancelSelectedRequests() async {
    if (_selectedItems.isEmpty) {
      _showMessage('취소할 항목을 선택해주세요');
      return;
    }
    
    final userLevel = widget.userInfo['permission_level'];
    
    // 선택된 항목들이 취소 가능한지 확인
    List<InspectionRequest> selectedRequests = [];
    List<String> invalidItems = [];
    
    for (int index in _selectedItems) {
      final request = _inspectionRequests[index];
      
      if (userLevel == 1) {
        // Level 1: 대기중 상태만 취소 가능
        if (request.status == '대기중') {
          selectedRequests.add(request);
        } else {
          invalidItems.add('${request.assemblyNo} (${request.status})');
        }
      } else {
        // Level 3+: 모든 상태 취소 가능
        selectedRequests.add(request);
      }
    }
    
    if (invalidItems.isNotEmpty) {
      _showMessage('대기중 상태만 취소 가능합니다: ${invalidItems.join(', ')}');
      return;
    }
    
    // 확인 팝업
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('검사신청 취소'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('선택한 ${selectedRequests.length}개 항목을 취소하시겠습니까?'),
              const SizedBox(height: 16),
              ...selectedRequests.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${r.assemblyNo} (${r.inspectionType}) - ${r.status}'),
              )).toList(),
              if (userLevel >= 3 && selectedRequests.any((r) => r.status == '확정됨')) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: const Text(
                    '⚠️ 확정된 항목을 취소하면 조립품 공정 날짜가 되돌려집니다.\n취소 후 다시 검사신청이 필요합니다.',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('아니오'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('취소하기'),
            ),
          ],
        );
      },
    );
    
    if (confirmed != true) return;
    
    // 실제 취소 API 호출
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      
      if (token == null) {
        _showMessage('로그인이 필요합니다');
        return;
      }
      
      int cancelledCount = 0;
      List<String> failedItems = [];
      
      for (final request in selectedRequests) {
        try {
          final url = Uri.parse('$_serverUrl/api/inspection-requests/${request.id}');
          final response = await http.delete(
            url,
            headers: {
              'Authorization': 'Bearer $token',
            },
          );
          
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['success'] == true) {
              cancelledCount++;
            } else {
              failedItems.add(request.assemblyNo);
            }
          } else {
            failedItems.add(request.assemblyNo);
          }
        } catch (e) {
          failedItems.add(request.assemblyNo);
        }
      }
      
      // 결과 메시지 표시
      if (cancelledCount > 0) {
        // 확정된 항목이 포함되어 있는지 확인
        bool hasConfirmedItems = selectedRequests.any((r) => r.status == '확정됨');
        String message = '$cancelledCount개 항목이 취소되었습니다';
        
        if (userLevel >= 3 && hasConfirmedItems) {
          message += '\n확정된 항목의 조립품 공정 날짜가 되돌려졌습니다';
        }
        
        _showMessage(message);
        
        // 취소된 항목들을 목록에서 즉시 제거
        setState(() {
          // 취소 성공한 항목들의 ID 수집
          Set<int> cancelledIds = selectedRequests
              .where((req) => !failedItems.contains(req.assemblyNo))
              .map((req) => req.id)
              .toSet();
          
          // 취소된 항목들을 목록에서 제거
          _inspectionRequests.removeWhere((req) => cancelledIds.contains(req.id));
          
          // 선택 해제
          _selectedItems.clear();
          _selectAll = false;
        });
      }
      
      if (failedItems.isNotEmpty) {
        _showMessage('취소 실패: ${failedItems.join(', ')}');
      }
      
    } catch (e) {
      _showMessage('네트워크 오류: $e');
    }
  }

  // 선택된 항목들 승인 (Level 3+ 전용)
  Future<void> _approveSelectedRequests() async {
    if (_selectedItems.isEmpty) {
      _showMessage('승인할 항목을 선택해주세요');
      return;
    }
    
    // 선택된 항목들이 승인 가능한지 확인
    List<InspectionRequest> selectedRequests = [];
    List<String> invalidItems = [];
    
    for (int index in _selectedItems) {
      final request = _inspectionRequests[index];
      if (request.status == '대기중') {
        selectedRequests.add(request);
      } else {
        invalidItems.add('${request.assemblyNo} (${request.status})');
      }
    }
    
    if (invalidItems.isNotEmpty) {
      _showMessage('대기중 상태만 승인 가능합니다: ${invalidItems.join(', ')}');
      return;
    }
    
    // 확인 팝업
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('검사신청 승인'),
          content: Text(
            '선택한 ${selectedRequests.length}개 항목을 승인하시겠습니까?\n\n'
            '${selectedRequests.map((r) => '• ${r.assemblyNo} (${r.inspectionType})').join('\n')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('아니오'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('승인하기'),
            ),
          ],
        );
      },
    );
    
    if (confirmed != true) return;
    
    // 실제 승인 API 호출
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      
      if (token == null) {
        _showMessage('로그인이 필요합니다');
        return;
      }
      
      int approvedCount = 0;
      List<String> failedItems = [];
      
      for (final request in selectedRequests) {
        try {
          final url = Uri.parse('$_serverUrl/api/inspection-requests/${request.id}/approve');
          final response = await http.put(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
          
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['success'] == true) {
              approvedCount++;
            } else {
              failedItems.add(request.assemblyNo);
            }
          } else {
            failedItems.add(request.assemblyNo);
          }
        } catch (e) {
          failedItems.add(request.assemblyNo);
        }
      }
      
      // 결과 메시지 표시
      if (approvedCount > 0) {
        _showMessage('$approvedCount개 항목이 승인되었습니다');
        
        // 데이터 새로고침
        _loadInspectionRequests();
        
        // 선택 해제
        setState(() {
          _selectedItems.clear();
          _selectAll = false;
        });
      } else {
        _showMessage('승인할 항목을 선택해주세요');
      }
      
      if (failedItems.isNotEmpty) {
        _showMessage('승인 실패 항목: ${failedItems.join(', ')}');
      }
    } catch (e) {
      _showMessage('네트워크 오류: $e');
    }
  }

  // 선택된 항목들 확정 (Level 3+ 전용)
  Future<void> _confirmSelectedRequests() async {
    if (_selectedItems.isEmpty) {
      _showMessage('확정할 항목을 선택해주세요');
      return;
    }
    
    // 선택된 항목들이 확정 가능한지 확인
    List<InspectionRequest> selectedRequests = [];
    List<String> invalidItems = [];
    
    for (int index in _selectedItems) {
      final request = _inspectionRequests[index];
      if (request.status == '승인됨') {
        selectedRequests.add(request);
      } else {
        invalidItems.add('${request.assemblyNo} (${request.status})');
      }
    }
    
    if (invalidItems.isNotEmpty) {
      _showMessage('승인됨 상태만 확정 가능합니다: ${invalidItems.join(', ')}');
      return;
    }
    
    // 확정 날짜 입력 팝업
    String? confirmedDate = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final dateController = TextEditingController();
        dateController.text = _formatDate(DateTime.now());
        
        return AlertDialog(
          title: const Text('검사신청 확정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('선택한 ${selectedRequests.length}개 항목을 확정하시겠습니까?'),
              const SizedBox(height: 16),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: '확정 날짜 (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    dateController.text = _formatDate(picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(dateController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('확정하기'),
            ),
          ],
        );
      },
    );
    
    if (confirmedDate == null) return;
    
    // 실제 확정 API 호출
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      
      if (token == null) {
        _showMessage('로그인이 필요합니다');
        return;
      }
      
      int confirmedCount = 0;
      List<String> failedItems = [];
      
      for (final request in selectedRequests) {
        try {
          final url = Uri.parse('$_serverUrl/api/inspection-requests/${request.id}/confirm');
          final response = await http.put(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'confirmed_date': confirmedDate,
            }),
          );
          
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['success'] == true) {
              confirmedCount++;
            } else {
              failedItems.add(request.assemblyNo);
            }
          } else {
            failedItems.add(request.assemblyNo);
          }
        } catch (e) {
          failedItems.add(request.assemblyNo);
        }
      }
      
      // 결과 메시지 표시
      if (confirmedCount > 0) {
        _showMessage('$confirmedCount개 항목이 확정되었습니다');
        
        // 데이터 새로고침
        _loadInspectionRequests();
        
        // 선택 해제
        setState(() {
          _selectedItems.clear();
          _selectAll = false;
        });
      } else {
        _showMessage('확정할 항목을 선택해주세요');
      }
      
      if (failedItems.isNotEmpty) {
        _showMessage('확정 실패 항목: ${failedItems.join(', ')}');
      }
    } catch (e) {
      _showMessage('네트워크 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.userInfo;
    final int userLevel = user['permission_level'];
    
    return Scaffold(
      appBar: AppBar(
        title: Text('검사신청 확인 - ${user['full_name']} (Level $userLevel)'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 상단 필터 및 버튼 영역
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userLevel == 1 
                          ? '본인이 신청한 검사신청 목록'
                          : '전체 검사신청 목록',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 날짜 선택
                    Row(
                      children: [
                        const Text('날짜: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _selectDate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.black,
                          ),
                          child: Text(
                            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')} ▼',
                          ),
                        ),
                      ],
                    ),
                    
                    // Level 3+ 전용 신청자 필터
                    if (userLevel >= 3) ...[
                      const SizedBox(height: 16),
                      
                      // 신청자 필터
                      Row(
                        children: [
                          const Text('신청자: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<String>(
                              value: _selectedRequester,
                              hint: const Text('전체 ▼'),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedRequester = newValue;
                                });
                                _applyClientSideFiltering();
                              },
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('전체'),
                                ),
                                ..._availableRequesters.map<DropdownMenuItem<String>>((String requester) {
                                  return DropdownMenuItem<String>(
                                    value: requester,
                                    child: Text(requester),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 공정 필터
                      Row(
                        children: [
                          const Text('공정: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<String>(
                              value: _selectedProcessType,
                              hint: const Text('전체 ▼'),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedProcessType = newValue;
                                });
                                _applyClientSideFiltering();
                              },
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('전체'),
                                ),
                                ..._availableProcessTypes.map<DropdownMenuItem<String>>((String processType) {
                                  return DropdownMenuItem<String>(
                                    value: processType,
                                    child: Text(processType),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    
                    // 새로고침과 전체선택 버튼
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _loadInspectionRequests,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: const Text('새로고침'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _inspectionRequests.isNotEmpty ? _toggleSelectAll : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectAll ? Colors.orange : Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: Text(_selectAll ? '전체해제' : '전체선택'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 검사신청 목록
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _inspectionRequests.isEmpty
                      ? const Center(
                          child: Text(
                            '해당 날짜에 검사신청이 없습니다',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _inspectionRequests.length,
                          itemBuilder: (context, index) {
                            final request = _inspectionRequests[index];
                            final statusStyle = _getStatusStyle(request.status);
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: CheckboxListTile(
                                value: _selectedItems.contains(index),
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedItems.add(index);
                                    } else {
                                      _selectedItems.remove(index);
                                    }
                                    // 전체 선택 상태 업데이트
                                    _selectAll = _selectedItems.length == _inspectionRequests.length;
                                  });
                                },
                                title: Text(
                                  request.assemblyNo,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('검사유형: ${request.inspectionType}'),
                                    Text('신청자: ${request.requestedBy}'),
                                    Text('신청일: ${_formatDate(request.requestDate)}'),
                                    if (request.approvedBy != null && request.approvedDate != null)
                                      Text('승인자: ${request.approvedBy} (${_formatDate(request.approvedDate!)})'),
                                    if (request.confirmedDate != null)
                                      Text('확정일: ${_formatDate(request.confirmedDate!)}'),
                                  ],
                                ),
                                secondary: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusStyle['color'],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        statusStyle['emoji'],
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        request.status,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                controlAffinity: ListTileControlAffinity.leading,
                              ),
                            );
                          },
                        ),
            ),
            
            // 하단 액션 버튼들 (Level별)
            if (userLevel == 1) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _selectedItems.isEmpty ? null : _cancelSelectedRequests,
                    icon: const Icon(Icons.cancel),
                    label: Text(
                      _selectedItems.isEmpty 
                          ? '선택된 항목 취소' 
                          : '선택된 항목 취소 (${_selectedItems.length}개)',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      disabledBackgroundColor: Colors.grey,
                      disabledForegroundColor: Colors.white54,
                    ),
                  ),
                ),
              ),
            ] else if (userLevel >= 3) ...[
              // Level 3+ 전용 액션 버튼들
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // 승인 버튼
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedItems.isEmpty ? null : _approveSelectedRequests,
                        icon: const Icon(Icons.check_circle),
                        label: Text(
                          _selectedItems.isEmpty 
                              ? '승인' 
                              : '승인 (${_selectedItems.length}개)',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          disabledBackgroundColor: Colors.grey,
                          disabledForegroundColor: Colors.white54,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 확정 버튼
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedItems.isEmpty ? null : _confirmSelectedRequests,
                        icon: const Icon(Icons.verified),
                        label: Text(
                          _selectedItems.isEmpty 
                              ? '확정' 
                              : '확정 (${_selectedItems.length}개)',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          disabledBackgroundColor: Colors.grey,
                          disabledForegroundColor: Colors.white54,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 취소 버튼
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedItems.isEmpty ? null : _cancelSelectedRequests,
                        icon: const Icon(Icons.cancel),
                        label: Text(
                          _selectedItems.isEmpty 
                              ? '취소' 
                              : '취소 (${_selectedItems.length}개)',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          disabledBackgroundColor: Colors.grey,
                          disabledForegroundColor: Colors.white54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 검사신청 데이터 모델
class InspectionRequest {
  final int id;
  final String assemblyNo;
  final DateTime requestDate;
  final String inspectionType;
  final String requestedBy;
  final String status;
  final String? approvedBy;
  final DateTime? approvedDate;
  final DateTime? confirmedDate;

  InspectionRequest({
    required this.id,
    required this.assemblyNo,
    required this.requestDate,
    required this.inspectionType,
    required this.requestedBy,
    required this.status,
    this.approvedBy,
    this.approvedDate,
    this.confirmedDate,
  });
}

// ASSEMBLY 아이템 데이터 모델
class AssemblyItem {
  final String assemblyNo;
  final String lastProcess;
  final String completedDate;
  final String company;
  final double weightNet;

  AssemblyItem({
    required this.assemblyNo,
    required this.lastProcess,
    required this.completedDate,
    this.company = '',
    this.weightNet = 0.0,
  });
}
