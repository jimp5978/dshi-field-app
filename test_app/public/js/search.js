// 검색 관리 클래스
class SearchManager {
    constructor() {
        this.selectedItems = [];
        this.searchResults = [];
        this.initializeEvents();
    }
    
    initializeEvents() {
        // 엔터키 검색 지원
        document.getElementById('searchInput').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.performSearch();
            }
        });
    }
    
    // 검색 수행
    async performSearch() {
        const query = document.getElementById('searchInput').value.trim();
        
        if (!query) {
            alert('검색어를 입력해주세요.');
            return;
        }
        
        if (!/^\d{1,3}$/.test(query)) {
            alert('1-3자리 숫자만 입력해주세요.');
            return;
        }
        
        try {
            const response = await fetch('/api/search', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ query: query })
            });
            
            const data = await response.json();
            
            if (data.success) {
                this.searchResults = data.data;
                this.displayResults(data.data);
            } else {
                alert(data.error || '검색 중 오류가 발생했습니다.');
            }
        } catch (error) {
            console.error('검색 오류:', error);
            alert('검색 중 오류가 발생했습니다.');
        }
    }
    
    // 검색 결과 표시
    displayResults(results) {
        const resultsDiv = document.getElementById('results');
        const contentDiv = document.getElementById('resultsContent');
        
        if (results.length === 0) {
            contentDiv.innerHTML = '<p>검색 결과가 없습니다.</p>';
            resultsDiv.style.display = 'block';
            return;
        }
        
        let html = '<table class="results-table">';
        html += '<thead><tr>';
        html += '<th><input type="checkbox" id="selectAllResults" onchange="searchManager.toggleAllResults()"></th>';
        html += '<th>조립품 코드</th>';
        html += '<th>중량 (NET)</th>';
        html += '<th>다음 공정</th>';
        html += '<th>공정 현황</th>';
        html += '</tr></thead><tbody>';
        
        results.forEach(item => {
            const nextProcess = this.getNextProcess(item);
            const processStatus = this.getProcessStatus(item);
            
            html += '<tr>';
            html += `<td><input type="checkbox" class="result-checkbox" value="${item.assembly}" onchange="searchManager.updateSelection()"></td>`;
            html += `<td>${item.assembly}</td>`;
            html += `<td>${item.weight_net || 0} kg</td>`;
            html += `<td>${nextProcess || 'N/A'}</td>`;
            html += `<td>${processStatus}</td>`;
            html += '</tr>';
        });
        
        html += '</tbody></table>';
        contentDiv.innerHTML = html;
        resultsDiv.style.display = 'block';
        
        this.updateSummary();
    }
    
    // 다음 공정 계산 (간단 버전)
    getNextProcess(assembly) {
        const processes = ['FIT_UP', 'FINAL', 'ARUP_FINAL', 'GALV', 'ARUP_GALV', 'SHOT', 'PAINT', 'ARUP_PAINT'];
        const processMap = {
            'FIT_UP': assembly.fit_up_date,
            'FINAL': assembly.final_date,
            'ARUP_FINAL': assembly.arup_final_date,
            'GALV': assembly.galv_date,
            'ARUP_GALV': assembly.arup_galv_date,
            'SHOT': assembly.shot_date,
            'PAINT': assembly.paint_date,
            'ARUP_PAINT': assembly.arup_paint_date
        };
        
        for (let i = 0; i < processes.length; i++) {
            const process = processes[i];
            const date = processMap[process];
            if (!date || date === '1900-01-01') {
                return process;
            }
        }
        return null; // 모든 공정 완료
    }
    
    // 공정 현황 표시
    getProcessStatus(assembly) {
        const processes = ['FIT_UP', 'FINAL', 'ARUP_FINAL', 'GALV', 'ARUP_GALV', 'SHOT', 'PAINT', 'ARUP_PAINT'];
        let completed = 0;
        
        processes.forEach(process => {
            const dateField = process.toLowerCase().replace('_', '_') + '_date';
            const date = assembly[dateField];
            if (date && date !== '1900-01-01') {
                completed++;
            }
        });
        
        return `${completed}/${processes.length}`;
    }
    
    // 전체 선택/해제
    toggleAllResults() {
        const selectAll = document.getElementById('selectAllResults');
        const checkboxes = document.querySelectorAll('.result-checkbox');
        
        checkboxes.forEach(checkbox => {
            checkbox.checked = selectAll.checked;
        });
        
        this.updateSelection();
    }
    
    // 선택 항목 업데이트
    updateSelection() {
        const checkboxes = document.querySelectorAll('.result-checkbox:checked');
        this.selectedItems = Array.from(checkboxes).map(cb => cb.value);
        this.updateSummary();
    }
    
    // 요약 정보 업데이트
    updateSummary() {
        const summaryDiv = document.getElementById('summary');
        
        if (this.selectedItems.length > 0) {
            const selectedData = this.searchResults.filter(item => 
                this.selectedItems.includes(item.assembly)
            );
            
            const totalWeight = selectedData.reduce((sum, item) => 
                sum + (parseFloat(item.weight_net) || 0), 0
            );
            
            summaryDiv.innerHTML = `선택된 항목: ${this.selectedItems.length}개, 총 중량: ${totalWeight.toFixed(2)} kg`;
            summaryDiv.style.display = 'block';
        } else {
            summaryDiv.style.display = 'none';
        }
    }
    
    // 선택 항목 저장
    async saveSelectedItems() {
        if (this.selectedItems.length === 0) {
            alert('저장할 항목을 선택해주세요.');
            return;
        }
        
        const selectedData = this.searchResults.filter(item => 
            this.selectedItems.includes(item.assembly)
        );
        
        try {
            const response = await fetch('/api/save-list', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ items: selectedData })
            });
            
            const data = await response.json();
            
            if (data.success) {
                alert(`${selectedData.length}개 항목이 저장되었습니다.`);
                
                // 저장된 항목들을 검색 결과에서 제거
                const savedAssemblyCodes = selectedData.map(item => item.assembly);
                this.searchResults = this.searchResults.filter(item => 
                    !savedAssemblyCodes.includes(item.assembly)
                );
                
                // 검색 결과 다시 표시
                this.displayResults(this.searchResults);
                
                // 선택 초기화
                this.selectedItems = [];
                this.updateSummary();
            } else {
                alert(data.error || '저장 중 오류가 발생했습니다.');
            }
        } catch (error) {
            console.error('저장 오류:', error);
            alert('저장 중 오류가 발생했습니다.');
        }
    }
}

// 전역 검색 관리자 인스턴스
let searchManager;

// 페이지 로드 시 초기화
document.addEventListener('DOMContentLoaded', () => {
    searchManager = new SearchManager();
});

// 전역 함수들 (HTML에서 호출)
function performSearch() {
    searchManager.performSearch();
}

function saveSelectedItems() {
    searchManager.saveSelectedItems();
}