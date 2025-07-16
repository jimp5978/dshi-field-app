# DSHI Field Pad UI 변경 가이드

> 📅 **작성일**: 2025-07-15  
> 🎯 **목적**: Flutter UI 구성 요소 및 변경 방법 가이드

## 📱 **Flutter UI 변경 항목**

### 1. **메인 UI 파일**
- `/mnt/e/DSHI_RPA/APP/dshi_field_app/lib/main.dart` (1900+ 줄)
- `/mnt/e/DSHI_RPA/APP/dshi_field_app/lib/login_screen.dart` (360+ 줄)

### 2. **테마 및 색상 변경**
```dart
// main.dart의 MaterialApp 테마 설정
theme: ThemeData(
  primarySwatch: Colors.blue,        // 기본 색상
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.blue,     // AppBar 배경색
    foregroundColor: Colors.white,   // AppBar 텍스트 색상
  ),
),
```

### 3. **개별 화면별 UI 요소**

#### **로그인 화면 (LoginScreen)**
- 로고/아이콘 변경
- 입력 필드 스타일
- 버튼 디자인
- 배경색/레이아웃

#### **검색 화면 (AssemblySearchScreen)**
- 숫자 키패드 디자인
- 검색 결과 리스트 스타일
- 버튼 크기/색상
- 체크박스 디자인

#### **저장 리스트 화면 (SavedListScreen)**
- 상단 3개 버튼 스타일
- 리스트 아이템 디자인
- 날짜 선택 UI
- 검사신청 버튼

#### **검사신청 확인 화면 (InspectionRequestScreen)**
- 필터 드롭다운 디자인
- 상태별 색상/이모지
- 액션 버튼 (승인/확정/취소)
- 전체선택 버튼

---

## 🎨 **색상 시스템**

### **현재 사용 중인 색상들**
```dart
Colors.blue      // 기본 테마, 승인됨 상태
Colors.green     // 승인 버튼
Colors.orange    // 전체선택, 경고, 대기중 상태
Colors.red       // 취소 버튼, 취소됨 상태
Colors.grey      // 비활성화
```

### **상태별 색상 매핑**
```dart
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
  }
}
```

---

## 🔤 **폰트 및 크기**

### **현재 설정된 폰트 크기들**
```dart
fontSize: 28     // 키패드 숫자
fontSize: 24     // 입력창 텍스트
fontSize: 18     // 제목
fontSize: 16     // 일반 텍스트
fontSize: 14     // 버튼 텍스트
fontSize: 12     // 상세 정보
```

### **폰트 스타일 예시**
```dart
TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.bold,
  color: Colors.blue,
)
```

---

## 📐 **레이아웃 구조**

### **패딩/마진**
```dart
EdgeInsets.all(16)           // 기본 패딩
EdgeInsets.symmetric(horizontal: 16, vertical: 12)  // 버튼 패딩
SizedBox(height: 16)         // 세로 간격
SizedBox(width: 8)           // 가로 간격
```

### **버튼 크기**
```dart
minimumSize: Size(0, 45)     // 기본 버튼 높이
padding: EdgeInsets.symmetric(vertical: 12)  // 버튼 내부 패딩
```

### **컨테이너 크기**
```dart
height: 500px                // 검색 결과창
width: double.infinity       // 전체 너비
```

---

## 🎯 **아이콘 및 이모지**

### **사용 중인 아이콘들**
```dart
Icons.account_circle  // 로그인 아이콘
Icons.check_circle    // 승인 아이콘
Icons.verified        // 확정 아이콘
Icons.cancel          // 취소 아이콘
Icons.schedule        // 대기 아이콘
Icons.person          // 사용자 아이콘
Icons.lock            // 비밀번호 아이콘
```

### **상태별 이모지**
```dart
'🟡' // 대기중
'🟢' // 승인됨
'🔵' // 확정됨
'❌' // 취소됨
'⚠️' // 경고
```

---

## 📱 **반응형 디자인**

### **태블릿 최적화**
- 현재 태블릿용으로 설계됨
- 터치하기 쉬운 버튼 크기
- 가로 화면 레이아웃 최적화

### **화면 분할**
```dart
Row(
  children: [
    // 좌측: 검색 결과 (고정 너비)
    Container(width: 400, child: searchResults),
    
    // 우측: 키패드 (나머지 공간)
    Expanded(child: keypad),
  ],
)
```

---

## 🛠️ **주요 UI 변경 방법**

### 1. **색상 테마 변경**
```dart
// main.dart에서 MaterialApp 테마 수정
theme: ThemeData(
  primarySwatch: Colors.green,  // 파란색 → 초록색
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.green,
    foregroundColor: Colors.white,
  ),
),
```

### 2. **버튼 스타일 변경**
```dart
ElevatedButton.styleFrom(
  backgroundColor: Colors.purple,  // 배경색
  foregroundColor: Colors.white,   // 텍스트 색상
  padding: EdgeInsets.symmetric(vertical: 16),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),  // 둥근 모서리
  ),
)
```

### 3. **폰트 크기 변경**
```dart
Text(
  '검사신청',
  style: TextStyle(
    fontSize: 20,  // 기존 18에서 20으로 변경
    fontWeight: FontWeight.bold,
  ),
)
```

### 4. **레이아웃 구조 변경**
```dart
// 세로 배치 → 가로 배치
Column(children: [...]) → Row(children: [...])

// 패딩 조정
EdgeInsets.all(16) → EdgeInsets.all(24)
```

### 5. **아이콘 변경**
```dart
Icons.check_circle → Icons.thumb_up  // 승인 아이콘 변경
'🟢' → '✅'  // 이모지 변경
```

---

## 🎛️ **권한별 UI 분기**

### **Level 1 (외부업체)**
```dart
if (userLevel == 1) {
  // 취소 버튼만 표시
  ElevatedButton(
    onPressed: _cancelSelectedRequests,
    child: Text('선택된 항목 취소'),
  )
}
```

### **Level 3+ (DSHI 직원)**
```dart
if (userLevel >= 3) {
  // 승인, 확정, 취소 버튼 모두 표시
  Row(
    children: [
      ElevatedButton(onPressed: _approveSelectedRequests, child: Text('승인')),
      ElevatedButton(onPressed: _confirmSelectedRequests, child: Text('확정')),
      ElevatedButton(onPressed: _cancelSelectedRequests, child: Text('취소')),
    ],
  )
}
```

---

## 📦 **패키지 의존성**

### **UI 관련 패키지**
```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:  # 한국어 지원
  intl: ^0.19.0           # 날짜 포맷팅
  http: ^1.1.0            # API 통신
  shared_preferences: ^2.2.2  # 데이터 저장
  crypto: ^3.0.3          # 암호화
```

---

## ⚠️ **UI 변경 시 주의사항**

### 1. **한국어 지원**
- 모든 텍스트가 한국어로 설정됨
- 날짜 형식도 한국 표준 (YYYY-MM-DD)

### 2. **권한별 UI**
- Level 1과 Level 3+에 따라 다른 버튼/기능 표시
- 권한 확인 후 UI 요소 표시/숨김

### 3. **상태별 스타일링**
- 검사신청 상태에 따른 색상 변화
- 이모지와 아이콘 일관성 유지

### 4. **실시간 업데이트**
- 상태 변경 시 즉시 UI 반영
- setState() 호출 필요

### 5. **반응형 디자인**
- 다양한 태블릿 크기 고려
- 터치 친화적 UI 유지

---

## 📋 **UI 변경 체크리스트**

- [ ] 색상 테마 일관성 확인
- [ ] 폰트 크기 가독성 확인
- [ ] 버튼 터치 영역 적절성 확인
- [ ] 권한별 UI 분기 정상 작동 확인
- [ ] 한국어 텍스트 표시 확인
- [ ] 상태별 색상/아이콘 일관성 확인
- [ ] 반응형 레이아웃 확인
- [ ] 실시간 업데이트 확인

---

*📅 작성일: 2025-07-15*  
*🎯 대상: DSHI Field Pad Flutter UI 개발자*