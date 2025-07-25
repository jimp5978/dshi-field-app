# -*- coding: utf-8 -*-

class AppLogger
  def self.debug(message)
    log_message = "🐛 DEBUG [#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}]: #{message}"
    puts log_message
    
    # 로그 파일에도 저장
    begin
      File.open('debug.log', 'a') do |file|
        file.puts log_message
      end
    rescue => e
      puts "로그 파일 쓰기 실패: #{e.message}"
    end
  end
end