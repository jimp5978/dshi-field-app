import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';

void main() {
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

class _AssemblySearchScreenState extends State<AssemblySearchScreen> {
  String _assemblyCode = '';
  List<AssemblyItem> _searchResults = [];
  Set<int> _selectedItems = <int>{};
  List<AssemblyItem> _savedList = []; // 저장된 항목들
  bool _isLoading = false;
  
  // 서버 URL
  static const String _serverUrl = 'http://192.168.0.5:5001';

  // 숫자 키패드 버튼 클릭 처리
  void _onNumberPressed(String number) {
    setState(() {
      _assemblyCode += number;
    });
  }

  // 백스페이스 처리
  void _onBackspacePressed() {
    setState(() {
      if (_assemblyCode.isNotEmpty) {
        _assemblyCode = _assemblyCode.substring(0, _assemblyCode.length - 1);
      }
    });
  }

  // 전체 삭제 (DEL)
  void _onDeletePressed() {
    setState(() {
      _assemblyCode = '';
    });
  }

  // 실제 서버 API 호출
  Future<void> _onSearchPressed() async {
    if (_assemblyCode.isEmpty) {
      _showMessage('검색어를 입력하세요');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('$_serverUrl/api/assemblies?search=$_assemblyCode');
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
            )).toList();
            _selectedItems.clear();
            // 검색 후 입력창 자동 삭제
            _assemblyCode = '';
          });
          
          _showMessage('${_searchResults.length}개 결과를 찾았습니다');
        } else {
          _showMessage(data['message'] ?? '검색 실패');
          setState(() {
            _searchResults = [];
          });
        }
      } else {
        _showMessage('서버 연결 오류: ${response.statusCode}');
        setState(() {
          _searchResults = [];
        });
      }
    } catch (e) {
      _showMessage('네트워크 오류: $e');
      setState(() {
        _searchResults = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 메시지 표시 함수
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
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

  // LIST UP 버튼
  void _onListUpPressed() {
    if (_selectedItems.isNotEmpty) {
      // 선택된 항목들을 저장 리스트에 추가
      List<AssemblyItem> selectedAssemblies = [];
      for (int index in _selectedItems.toList()..sort((a, b) => b.compareTo(a))) {
        selectedAssemblies.add(_searchResults[index]);
        _savedList.add(_searchResults[index]);
      }
      
      // 선택된 항목들을 검색 결과에서 제거 (역순으로 제거)
      for (int index in _selectedItems.toList()..sort((a, b) => b.compareTo(a))) {
        _searchResults.removeAt(index);
      }
      
      setState(() {
        _selectedItems.clear();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedAssemblies.length}개 항목이 리스트에 저장되었습니다'),
          duration: const Duration(seconds: 2),
        ),
      );
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
            // 상단 영역 (타이틀과 LIST 버튼)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // LIST 버튼 (크기 확대)
                ElevatedButton(
                  onPressed: _showSavedList,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    minimumSize: const Size(100, 48),
                  ),
                  child: Text(
                    'LIST (${_savedList.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                // 타이틀
                const Text(
                  'ASSEMBLY 검색',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                // 빈 공간 (균형 맞추기)
                const SizedBox(width: 120),
              ],
            ),
            const SizedBox(height: 20),
            
            // 메인 컨텐츠 영역 (가로 배치)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 왼쪽: 검색 결과 + LIST UP 버튼
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        // 검색 결과 리스트 (크기 증가, 테두리 제거)
                        Container(
                          height: 500, // 400 → 500으로 증가
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.transparent, // 배경색 투명
                          ),
                          child: _searchResults.isEmpty
                              ? const Center(
                                  child: Text(
                                    '검색 결과가 없습니다',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(8),
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
                                            fontSize: 16,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
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
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 20),
                  
                  // 오른쪽: 키패드 + 검색 버튼
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        // 입력 표시창 (폰트 크기 증가)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue, width: 2),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[100],
                          ),
                          child: Text(
                            _assemblyCode.isEmpty ? 'ASSEMBLY 코드' : _assemblyCode,
                            style: TextStyle(
                              fontSize: 24, // 18 → 24로 증가
                              color: _assemblyCode.isEmpty ? Colors.grey : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        
                        const SizedBox(height: 16), // 입력창과 키패드 사이 여백
                        
                        // 숫자 키패드 (여백 제거, 박스 제거)
                        Expanded(
                          child: GridView.count(
                            crossAxisCount: 3,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                            childAspectRatio: 1.4,
                            children: [
                              // 첫 번째 행: 1, 2, 3
                              _buildNumberButton('1'),
                              _buildNumberButton('2'),
                              _buildNumberButton('3'),
                              // 두 번째 행: 4, 5, 6
                              _buildNumberButton('4'),
                              _buildNumberButton('5'),
                              _buildNumberButton('6'),
                              // 세 번째 행: 7, 8, 9
                              _buildNumberButton('7'),
                              _buildNumberButton('8'),
                              _buildNumberButton('9'),
                              // 네 번째 행: DEL, 0, ←
                              _buildDeleteButton(),
                              _buildNumberButton('0'),
                              _buildBackspaceButton(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 하단 버튼들 (같은 라인에 배치)
            Row(
              children: [
                // LIST UP 버튼
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
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
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // 검색 버튼
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _onSearchPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '검색',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 숫자 버튼 위젯 (폰트 크기 2배 증가)
  Widget _buildNumberButton(String number) {
    return ElevatedButton(
      onPressed: () => _onNumberPressed(number),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.grey),
        ),
      ),
      child: Text(
        number,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
    );
  }

  // DEL 버튼
  Widget _buildDeleteButton() {
    return ElevatedButton(
      onPressed: _onDeletePressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red[100],
        foregroundColor: Colors.red,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: const Text(
        'DEL',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  // 백스페이스 버튼
  Widget _buildBackspaceButton() {
    return ElevatedButton(
      onPressed: _onBackspacePressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange[100],
        foregroundColor: Colors.orange,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: const Icon(
        Icons.backspace,
        size: 28,
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

  @override
  void initState() {
    super.initState();
    _savedList = List.from(widget.savedList);
    // 기본값을 내일로 설정
    _selectedDate = DateTime.now().add(const Duration(days: 1));
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
  
  // 다음 공정 반환
  String _getNextProcess(String currentProcess) {
    const Map<String, String> processMap = {
      'Fit-up': 'NDE',
      'NDE': 'VIDI',
      'VIDI': 'GALV',
      'GALV': 'SHOT',
      'SHOT': 'PAINT',
      'PAINT': 'PACKING',
    };
    return processMap[currentProcess] ?? '완료';
  }
  
  // 검사 신청 제출
  void _submitInspectionRequest(List<AssemblyItem> items, String nextProcess) {
    // TODO: 실제 API 호출로 대체
    
    // 검사 신청된 항목들을 LIST에서 제거
    setState(() {
      // 신청된 항목들을 _savedList에서 제거
      for (AssemblyItem item in items) {
        _savedList.remove(item);
      }
      // 선택 상태 초기화
      _selectedItems.clear();
      _selectAll = false;
    });
    
    // 변경사항을 부모 위젯에 전달
    widget.onListUpdated(_savedList);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${items.length}개 항목의 $nextProcess 검사가 신청되었습니다'),
        duration: const Duration(seconds: 3),
      ),
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
        title: Text('저장된 리스트 (${_savedList.length}개)'),
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

// ASSEMBLY 아이템 데이터 모델
class AssemblyItem {
  final String assemblyNo;
  final String lastProcess;
  final String completedDate;

  AssemblyItem({
    required this.assemblyNo,
    required this.lastProcess,
    required this.completedDate,
  });
}
