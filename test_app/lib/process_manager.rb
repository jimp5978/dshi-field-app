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
    
    # 마지막 완료된 공정 찾기
    last_completed_process = nil
    PROCESS_ORDER.each do |process|
      date = processes[process]
      # 날짜가 있고 1900-01-01이 아닌 경우 완료된 것으로 간주
      if date && date != '1900-01-01' && !date.empty?
        last_completed_process = process
      else
        break # 첫 번째 미완료 공정에서 중단
      end
    end
    
    # 다음 공정 반환
    if last_completed_process.nil?
      PROCESS_ORDER.first # 첫 번째 공정
    else
      current_index = PROCESS_ORDER.index(last_completed_process)
      if current_index && current_index < PROCESS_ORDER.length - 1
        PROCESS_ORDER[current_index + 1]
      else
        nil # 모든 공정 완료
      end
    end
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