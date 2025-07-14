import 'package:flutter/material.dart';
import 'login_screen.dart';

// 기존 AssemblySearchScreen을 별도 파일로 분리
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

  // 검색 실행
  void _onSearchPressed() {
    if (_assemblyCode.isNotEmpty) {
      // 임시 검색 결과 (실제로는 API 호출)
      setState(() {
        _searchResults = [
          AssemblyItem(
            assemblyNo: 'ASM-${_assemblyCode}001',
            lastProcess: 'PAINT',
            completedDate: '2025-07-08',
          ),
          AssemblyItem(
            assemblyNo: 'ASM-${_assemblyCode}002',
            lastProcess: 'NDE',
            completedDate: '2025-07-05',
          ),
          AssemblyItem(
            assemblyNo: 'ASM-${_assemblyCode}003',
            lastProcess: 'VIDI',
            completedDate: '2025-07-03',
          ),
        ];
        _selectedItems.clear();
        // 검색 후 입력창 자동 삭제
        _assemblyCode = '';
      });
    }
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

  // 로그아웃 기능
  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.userInfo;
    final int permissionLevel = user['permission_level'];
    
    // 모든 레벨이 전체 기능 사용 가능 (Level 2는 추후 사용 예정)
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
                // 권한 레벨 표시
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getLevelColor(user['permission_level']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Level ${user['permission_level']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
                        // 검색 결과 리스트
                        Container(
                          height: 500,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.transparent,
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
                        // 입력 표시창
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
                              fontSize: 24,
                              color: _assemblyCode.isEmpty ? Colors.grey : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // 숫자 키패드
                        Expanded(
                          child: GridView.count(
                            crossAxisCount: 3,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                            childAspectRatio: 1.4,
                            children: [
                              _buildNumberButton('1'),
                              _buildNumberButton('2'),
                              _buildNumberButton('3'),
                              _buildNumberButton('4'),
                              _buildNumberButton('5'),
                              _buildNumberButton('6'),
                              _buildNumberButton('7'),
                              _buildNumberButton('8'),
                              _buildNumberButton('9'),
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
            
            // 하단 버튼들
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

  // 권한 레벨별 색상
  Color _getLevelColor(int level) {
    switch (level) {
      case 1: return Colors.orange;
      case 2: return Colors.deepOrange;
      case 3: return Colors.blue;
      case 4: return Colors.indigo;
      case 5: return Colors.purple;
      default: return Colors.grey;
    }
  }

  // 숫자 버튼 위젯
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
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _savedList = List.from(widget.savedList);
    _selectedDate = DateTime.now().add(const Duration(days: 1));
  }

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

  void _deleteSelectedItems() {
    if (_selectedItems.isNotEmpty) {
      setState(() {
        for (int index in _selectedItems.toList()..sort((a, b) => b.compareTo(a))) {
          _savedList.removeAt(index);
        }
        _selectedItems.clear();
        _selectAll = false;
      });
      
      widget.onListUpdated(_savedList);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('선택된 항목들이 삭제되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

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

  void _selectDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now,
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
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
    
    Map<String, List<AssemblyItem>> processByItems = {};
    
    for (int index in _selectedItems) {
      AssemblyItem item = _savedList[index];
      if (!processByItems.containsKey(item.lastProcess)) {
        processByItems[item.lastProcess] = [];
      }
      processByItems[item.lastProcess]!.add(item);
    }
    
    if (processByItems.length > 1) {
      String majorProcess = '';
      int maxCount = 0;
      for (String process in processByItems.keys) {
        if (processByItems[process]!.length > maxCount) {
          maxCount = processByItems[process]!.length;
          majorProcess = process;
        }
      }
      
      List<String> minorityItems = [];
      for (String process in processByItems.keys) {
        if (process != majorProcess) {
          for (AssemblyItem item in processByItems[process]!) {
            minorityItems.add('${item.assemblyNo} ($process)');
          }
        }
      }
      
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
  
  void _submitInspectionRequest(List<AssemblyItem> items, String nextProcess) {
    setState(() {
      for (AssemblyItem item in items) {
        _savedList.remove(item);
      }
      _selectedItems.clear();
      _selectAll = false;
    });
    
    widget.onListUpdated(_savedList);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${items.length}개 항목의 $nextProcess 검사가 신청되었습니다'),
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
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
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectDate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 50),
                    ),
                    child: Text(
                      _formatDate(_selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
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
