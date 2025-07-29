import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["filterBtn", "section", "updateTime"]
  
  connect() {
    console.log("대시보드 컨트롤러 연결됨")
    this.startRealTimeUpdates()
    this.initializeFilters()
  }
  
  disconnect() {
    if (this.updateInterval) {
      clearInterval(this.updateInterval)
    }
  }
  
  // 필터 기능
  filter(event) {
    const filterValue = event.target.dataset.filter
    
    // 모든 필터 버튼에서 active 클래스 제거
    this.filterBtnTargets.forEach(btn => {
      btn.classList.remove('active')
    })
    
    // 클릭된 버튼에 active 클래스 추가
    event.target.classList.add('active')
    
    // 섹션 필터링
    this.sectionTargets.forEach(section => {
      if (filterValue === 'all') {
        section.style.display = 'flex'
      } else {
        const hasPriorityClass = section.querySelector(`.${filterValue}`)
        section.style.display = hasPriorityClass ? 'flex' : 'none'
      }
    })
  }
  
  // 실시간 업데이트 시작
  startRealTimeUpdates() {
    // 즉시 업데이트
    this.updateMetrics()
    
    // 5초마다 업데이트
    this.updateInterval = setInterval(() => {
      this.updateMetrics()
    }, 5000)
  }
  
  // 메트릭 업데이트
  updateMetrics() {
    // 진행률 업데이트
    this.updateProgressBars()
    
    // 시간 업데이트 (헤더의 시간은 서버 시간이므로 클라이언트에서 업데이트하지 않음)
    console.log('메트릭 업데이트 완료:', new Date().toLocaleTimeString())
  }
  
  // 진행률 바 업데이트
  updateProgressBars() {
    const progressBars = this.element.querySelectorAll('.progress-bar-fill, .company-fill, .process-fill')
    
    progressBars.forEach(bar => {
      const currentWidth = parseInt(bar.style.width)
      if (currentWidth && currentWidth > 0) {
        // ±2% 범위에서 랜덤 변화
        const variation = (Math.random() - 0.5) * 4
        const newWidth = Math.max(0, Math.min(100, currentWidth + variation))
        bar.style.width = `${Math.round(newWidth)}%`
        
        // 해당 퍼센트 텍스트도 업데이트
        const percentageElement = bar.closest('.company-item, .process-item')?.querySelector('.company-percentage, .process-percentage')
        if (percentageElement) {
          percentageElement.textContent = `${Math.round(newWidth)}%`
        }
      }
    })
    
    // 전체 진행률 업데이트
    const overallProgress = this.element.querySelector('.progress-value')
    if (overallProgress) {
      const currentValue = parseInt(overallProgress.textContent)
      const variation = (Math.random() - 0.5) * 4
      const newValue = Math.max(0, Math.min(100, currentValue + variation))
      overallProgress.textContent = `${Math.round(newValue)}%`
      
      // 해당 진행률 바도 업데이트
      const progressBar = this.element.querySelector('.progress-bar-fill')
      if (progressBar) {
        progressBar.style.width = `${Math.round(newValue)}%`
      }
    }
  }
  
  // 필터 초기화
  initializeFilters() {
    // 전체 필터가 기본으로 선택되도록 설정
    const allFilter = this.element.querySelector('[data-filter="all"]')
    if (allFilter) {
      allFilter.classList.add('active')
    }
  }
  
  // 카드 클릭 시 상세 정보 표시
  showDetails(event) {
    const card = event.currentTarget
    const cardType = card.dataset.type || '정보'
    const cardTitle = card.querySelector('.volume-process, .company-name, .process-name, .issue-title')?.textContent || '상세 정보'
    
    // 임시로 alert 사용 (실제로는 모달이나 다른 UI로 대체)
    alert(`${cardType}: ${cardTitle}`)
  }
  
  // 호버 효과 개선
  enhanceHover(event) {
    const card = event.currentTarget
    card.style.transform = 'translateX(5px) scale(1.02)'
  }
  
  resetHover(event) {
    const card = event.currentTarget
    card.style.transform = 'translateX(0) scale(1)'
  }
}