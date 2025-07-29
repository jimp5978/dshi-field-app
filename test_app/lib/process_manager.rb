# -*- coding: utf-8 -*-

require_relative '../config/settings'

class ProcessManager
  # 패스워드 해싱
  def self.sha256_hash(password)
    Digest::SHA256.hexdigest(password)
  end
  
  # 조립품의 다음 공정을 계산하는 함수
  def self.get_next_process(assembly)
    # 각 공정의 완료 날짜 확인 (1900-01-01은 공정 불필요)
    processes = {
      'FIT_UP' => assembly['fit_up_date'],
      'FINAL' => assembly['final_date'],
      'ARUP_FINAL' => assembly['arup_final_date'],
      'GALV' => assembly['galv_date'],
      'ARUP_GALV' => assembly['arup_galv_date'],
      'SHOT' => assembly['shot_date'],
      'PAINT' => assembly['paint_date'],
      'ARUP_PAINT' => assembly['arup_paint_date']
    }
    
    # 다음 공정을 찾기 (1900-01-01 공정은 건너뛰기)
    PROCESS_ORDER.each do |process|
      date = processes[process]
      
      # 1900-01-01인 경우 불필요한 공정으로 건너뛰기
      if date && (date.include?('1900') || date == '1900-01-01')
        next
      end
      
      # 날짜가 없거나 비어있는 경우 미완료 공정
      if date.nil? || date.empty?
        return process
      end
      
      # 실제 날짜가 있는 경우 완료된 공정이므로 계속 진행
    end
    
    # 모든 공정을 확인했는데 미완료 공정이 없으면 완료
    nil
  end
  
  # 공정명을 한글로 변환
  def self.to_korean(process)
    case process
    when 'FIT_UP'
      'FIT-UP (조립)'
    when 'FINAL'
      'FINAL (완료)'
    when 'ARUP_FINAL'
      'ARUP_FINAL (아룹 최종)'
    when 'GALV'
      'GALV (도금)'
    when 'ARUP_GALV'
      'ARUP_GALV (아룹 도금)'
    when 'SHOT'
      'SHOT (쇼트블라스트)'
    when 'PAINT'
      'PAINT (도장)'
    when 'ARUP_PAINT'
      'ARUP_PAINT (아룹 도장)'
    else
      process
    end
  end
end