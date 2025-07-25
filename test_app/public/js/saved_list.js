// 저장된 리스트 관리 클래스
class SavedListManager {
    constructor() {
        this.selectedItems = [];
        this.initializeEvents();
    }
    
    initializeEvents() {
        // 전체 선택 체크박스 이벤트
        const selectAllCheckbox = document.getElementById('selectAll');
        if (selectAllCheckbox) {
            selectAllCheckbox.addEventListener('change', () => {
                this.toggleAllSelection();
            });
        }
        
        // 개별 체크박스 이벤트
        document.querySelectorAll('.item-checkbox').forEach(checkbox => {
            checkbox.addEventListener('change', () => {
                this.updateSelection();
            });
        });
    }
    
    // 전체 선택/해제
    toggleAllSelection() {
        const selectAll = document.getElementById('selectAll');
        const checkboxes = document.querySelectorAll('.item-checkbox');
        
        checkboxes.forEach(checkbox => {
            checkbox.checked = selectAll.checked;
        });
        
        this.updateSelection();
    }
    
    // 선택 항목 업데이트
    updateSelection() {
        const checkboxes = document.querySelectorAll('.item-checkbox:checked');
        this.selectedItems = Array.from(checkboxes).map(cb => cb.value);
        
        // 전체 선택 체크박스 상태 업데이트
        const selectAll = document.getElementById('selectAll');
        const allCheckboxes = document.querySelectorAll('.item-checkbox');
        if (selectAll && allCheckboxes.length > 0) {
            selectAll.checked = this.selectedItems.length === allCheckboxes.length;
        }
    }
    
    // 검사신청 폼 표시
    showInspectionForm() {
        if (this.selectedItems.length === 0) {
            alert('검사신청할 항목을 선택해주세요.');
            return;
        }
        
        // 선택된 항목들의 다음 공정이 모두 같은지 확인
        const selectedProcesses = this.getSelectedProcesses();
        const uniqueProcesses = [...new Set(selectedProcesses)];
        
        if (uniqueProcesses.length > 1) {
            alert('같은 공정의 항목들만 함께 검사신청할 수 있습니다.');
            return;
        }
        
        if (uniqueProcesses[0] === null) {
            alert('선택한 항목들은 이미 모든 공정이 완료되었습니다.');
            return;
        }
        
        const form = document.getElementById('inspectionForm');
        if (form) {
            form.style.display = 'block';
            
            // 내일 날짜를 기본값으로 설정
            const tomorrow = new Date();
            tomorrow.setDate(tomorrow.getDate() + 1);
            const dateString = tomorrow.toISOString().split('T')[0];
            document.getElementById('inspectionDate').value = dateString;
        }
    }
    
    // 검사신청 폼 숨기기
    hideInspectionForm() {
        const form = document.getElementById('inspectionForm');
        if (form) {
            form.style.display = 'none';
        }
    }
    
    // 선택된 항목들의 다음 공정 확인
    getSelectedProcesses() {
        // 이 함수는 실제로는 서버에서 계산되어야 하지만, 
        // 클라이언트에서 간단히 구현
        return this.selectedItems.map(assembly => {
            // 실제 구현에서는 DOM에서 해당 항목의 다음 공정을 읽어옴
            const row = document.querySelector(`input[value="${assembly}"]`).closest('tr');
            const nextProcessCell = row.cells[3]; // 다음 공정 컬럼
            const processText = nextProcessCell.textContent.trim();
            // 한글 공정명에서 영문 코드 추출 (예: "FIT-UP (조립)" -> "FIT_UP")
            if (processText.includes('FIT-UP')) return 'FIT_UP';
            if (processText.includes('FINAL')) return 'FINAL';
            if (processText.includes('ARUP_FINAL')) return 'ARUP_FINAL';
            if (processText.includes('GALV')) return 'GALV';
            if (processText.includes('ARUP_GALV')) return 'ARUP_GALV';
            if (processText.includes('SHOT')) return 'SHOT';
            if (processText.includes('PAINT')) return 'PAINT';
            if (processText.includes('ARUP_PAINT')) return 'ARUP_PAINT';
            return processText;
        });
    }
    
    // 공정명을 한글로 변환
    getProcessKoreanName(process) {
        switch(process) {
            case 'FIT_UP': return 'FIT-UP (조립)';
            case 'FINAL': return 'FINAL (완료)';
            case 'ARUP_FINAL': return 'ARUP_FINAL (아룹 최종)';
            case 'GALV': return 'GALV (도금)';
            case 'ARUP_GALV': return 'ARUP_GALV (아룹 도금)';
            case 'SHOT': return 'SHOT (쇼트블라스트)';
            case 'PAINT': return 'PAINT (도장)';
            case 'ARUP_PAINT': return 'ARUP_PAINT (아룹 도장)';
            default: return process;
        }
    }
    
    // 날짜를 한글 형식으로 포맷팅
    formatDate(dateString) {
        const date = new Date(dateString);
        const year = date.getFullYear();
        const month = date.getMonth() + 1;
        const day = date.getDate();
        
        // 요일 계산
        const weekdays = ['일요일', '월요일', '화요일', '수요일', '목요일', '금요일', '토요일'];
        const weekday = weekdays[date.getDay()];
        
        return `${year}년 ${month}월 ${day}일 (${weekday})`;
    }
    
    // 검사신청 제출
    async submitInspectionRequest() {
        if (this.selectedItems.length === 0) {
            alert('검사신청할 항목을 선택해주세요.');
            return;
        }
        
        const inspectionDate = document.getElementById('inspectionDate').value;
        if (!inspectionDate) {
            alert('검사 희망일을 선택해주세요.');
            return;
        }
        
        const selectedProcesses = this.getSelectedProcesses();
        const uniqueProcesses = [...new Set(selectedProcesses)];
        
        if (uniqueProcesses.length > 1) {
            alert('같은 공정의 항목들만 함께 검사신청할 수 있습니다.');
            return;
        }
        
        const inspectionType = uniqueProcesses[0];
        const processKorean = this.getProcessKoreanName(inspectionType);
        const formattedDate = this.formatDate(inspectionDate);
        const confirmMessage = `${this.selectedItems.length}개 항목을 ${processKorean} 검사로 ${formattedDate}에 신청하시겠습니까?`;
        
        if (!confirm(confirmMessage)) {
            return;
        }
        
        try {
            const response = await fetch('/api/create-inspection-request', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    assembly_codes: this.selectedItems,
                    inspection_type: inspectionType,
                    request_date: inspectionDate
                })
            });
            
            const data = await response.json();
            
            if (data.success) {
                if (data.data.success) {
                    const processKorean = this.getProcessKoreanName(inspectionType);
                    const formattedDate = this.formatDate(inspectionDate);
                    const successMessage = `${this.selectedItems.length}개 항목의 ${processKorean} 검사신청이 ${formattedDate}으로 완료되었습니다.`;
                    alert(successMessage);
                    // 페이지 새로고침
                    location.reload();
                } else {
                    // 중복 검사신청 등의 경우
                    let errorMessage = data.data.message || '검사신청에 실패했습니다.';
                    
                    if (data.data.duplicate_items && data.data.duplicate_items.length > 0) {
                        errorMessage += '\\n\\n중복 항목 상세:';
                        data.data.duplicate_items.forEach(item => {
                            const existingFormattedDate = this.formatDate(item.existing_date);
                            errorMessage += `\\n- ${item.assembly_code}: ${item.existing_requester}님이 ${existingFormattedDate}에 이미 신청하셨습니다.`;
                        });
                    }
                    
                    alert(errorMessage);
                }
            } else {
                alert(data.error || '검사신청 중 오류가 발생했습니다.');
            }
        } catch (error) {
            console.error('검사신청 오류:', error);
            alert('검사신청 중 오류가 발생했습니다.');
        } finally {
            this.hideInspectionForm();
        }
    }
    
    // 선택 항목 삭제
    async removeSelectedItems() {
        if (this.selectedItems.length === 0) {
            alert('삭제할 항목을 선택해주세요.');
            return;
        }
        
        if (!confirm(`선택한 ${this.selectedItems.length}개 항목을 삭제하시겠습니까?`)) {
            return;
        }
        
        try {
            const response = await fetch('/api/remove-from-saved-list', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ items: this.selectedItems })
            });
            
            const data = await response.json();
            
            if (data.success) {
                alert(`${this.selectedItems.length}개 항목이 삭제되었습니다.`);
                // 페이지 새로고침
                location.reload();
            } else {
                alert(data.error || '삭제 중 오류가 발생했습니다.');
            }
        } catch (error) {
            console.error('삭제 오류:', error);
            alert('삭제 중 오류가 발생했습니다.');
        }
    }
}

// 전역 관리자 인스턴스
let savedListManager;

// 페이지 로드 시 초기화
document.addEventListener('DOMContentLoaded', () => {
    savedListManager = new SavedListManager();
});

// 전역 함수들 (HTML에서 호출)
function toggleAllSelection() {
    if (savedListManager) {
        savedListManager.toggleAllSelection();
    }
}

function showInspectionForm() {
    if (savedListManager) {
        savedListManager.showInspectionForm();
    }
}

function hideInspectionForm() {
    if (savedListManager) {
        savedListManager.hideInspectionForm();
    }
}

function submitInspectionRequest() {
    if (savedListManager) {
        savedListManager.submitInspectionRequest();
    }
}

function removeSelectedItems() {
    if (savedListManager) {
        savedListManager.removeSelectedItems();
    }
}