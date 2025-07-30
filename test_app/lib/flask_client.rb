# -*- coding: utf-8 -*-

require 'net/http'
require 'json'
require 'uri'
require_relative '../config/settings'
require_relative 'logger'
require_relative 'process_manager'

class FlaskClient
  def initialize(base_url = FLASK_API_URL)
    @base_url = base_url
    @uri = URI(base_url)
    @connection = nil
    @connection_mutex = Mutex.new
    @last_used = Time.now
    @connection_ttl = 30 # 30초 후 연결 만료
    
    # 캐시 시스템 초기화
    @cache = {}
    @cache_mutex = Mutex.new
    @cache_ttl = 15 # 15초 캐시 TTL
    
    # 연결 초기화
    initialize_connection
  end
  
  private
  
  # HTTP 연결 초기화 및 재사용 관리
  def initialize_connection
    @connection_mutex.synchronize do
      # 기존 연결이 있고 아직 유효한 경우 재사용
      if @connection && connection_valid?
        return @connection
      end
      
      # 기존 연결 종료
      close_connection if @connection
      
      # 새 연결 생성 (Keep-Alive 활성화)
      @connection = Net::HTTP.new(@uri.host, @uri.port)
      @connection.open_timeout = 3
      @connection.read_timeout = 5
      @connection.keep_alive_timeout = 30
      @connection.start
      @last_used = Time.now
      
      AppLogger.debug("새로운 HTTP 연결 생성: #{@uri.host}:#{@uri.port}")
      @connection
    end
  end
  
  # 연결 유효성 확인
  def connection_valid?
    return false unless @connection
    return false unless @connection.started?
    return false if Time.now - @last_used > @connection_ttl
    true
  end
  
  # 안전한 HTTP 요청 실행
  def execute_request(request)
    @connection_mutex.synchronize do
      # 연결 확인 및 재초기화
      initialize_connection unless connection_valid?
      
      begin
        @last_used = Time.now
        response = @connection.request(request)
        AppLogger.debug("HTTP 요청 성공: #{request.method} #{request.path} - #{response.code}")
        response
      rescue Net::ReadTimeout, Net::OpenTimeout, EOFError, Errno::ECONNRESET => e
        AppLogger.debug("연결 오류 발생, 재시도: #{e.message}")
        # 연결 재초기화 후 재시도
        close_connection
        initialize_connection
        @connection.request(request)
      end
    end
  end
  
  # 연결 종료
  def close_connection
    if @connection && @connection.started?
      @connection.finish
      AppLogger.debug("HTTP 연결 종료")
    end
    @connection = nil
  end
  
  # 소멸자에서 연결 정리
  def finalize
    close_connection
  end
  
  # 캐시 관련 메서드
  def get_cache(key)
    @cache_mutex.synchronize do
      entry = @cache[key]
      return nil unless entry
      
      # TTL 체크
      if Time.now - entry[:timestamp] > @cache_ttl
        @cache.delete(key)
        return nil
      end
      
      AppLogger.debug("캐시 히트: #{key}")
      entry[:data]
    end
  end
  
  def set_cache(key, data)
    @cache_mutex.synchronize do
      @cache[key] = {
        data: data,
        timestamp: Time.now
      }
      AppLogger.debug("캐시 저장: #{key}")
    end
  end
  
  def clear_cache
    @cache_mutex.synchronize do
      @cache.clear
      AppLogger.debug("캐시 전체 초기화")
    end
  end
  
  public
  
  # 로그인 API 호출
  def login(username, password)
    password_hash = ProcessManager.sha256_hash(password)
    AppLogger.debug("로그인 시도 - 사용자명: #{username}")
    
    begin
      request = Net::HTTP::Post.new("/api/login")
      request['Content-Type'] = 'application/json'
      request.body = {
        username: username,
        password_hash: password_hash
      }.to_json
      
      response = execute_request(request)
      AppLogger.debug("로그인 API 응답: #{response.code}")
      
      if response.code == '200'
        data = JSON.parse(response.body)
        if data['success']
          { success: true, token: data['token'], user: data['user'] }
        else
          { success: false, error: data['message'] || '로그인 실패' }
        end
      else
        { success: false, error: '로그인 중 오류가 발생했습니다' }
      end
    rescue => e
      AppLogger.debug("로그인 API 연결 실패: #{e.message}")
      { success: false, error: "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." }
    end
  end
  
  # 조립품 검색 API 호출 (캐싱 적용)
  def search_assemblies(query, token)
    AppLogger.debug("검색 API 호출")
    AppLogger.debug("검색어: #{query}")
    
    # 캐시 키 생성
    cache_key = "search_#{query}"
    
    # 캐시 확인
    cached_result = get_cache(cache_key)
    return cached_result if cached_result
    
    begin
      request = Net::HTTP::Get.new("/api/assemblies/search?q=#{URI.encode_www_form_component(query)}")
      request['Authorization'] = "Bearer #{token}" if token && !token.empty?
      
      response = execute_request(request)
      AppLogger.debug("Flask API 응답: #{response.code}")
      
      if response.code == '200'
        data = JSON.parse(response.body)
        AppLogger.debug("조립품 개수: #{data['data'] ? data['data'].length : 0}")
        result = { success: true, data: data['data'] || [] }
        
        # 결과 캐싱 (검색 결과는 자주 변경되지 않음)
        set_cache(cache_key, result)
        result
      else
        { success: false, error: "검색 중 오류가 발생했습니다 (#{response.code})" }
      end
    rescue => e
      AppLogger.debug("검색 API 연결 실패: #{e.message}")
      { success: false, error: "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." }
    end
  end
  
  # 검사신청 조회 API 호출
  def get_inspection_requests(token, user_level, username = nil)
    AppLogger.debug("검사신청 조회: #{username} (Level #{user_level})")
    
    begin
      url = "#{@base_url}/api/inspection-requests"
      url += "?requester=#{username}" if user_level == 1 && username
      
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 3
      http.read_timeout = 5
      
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{token}"
      
      response = http.request(request)
      
      if response.code == '200'
        data = JSON.parse(response.body)
        { success: true, data: data }
      else
        { success: false, error: "검사신청 조회 중 오류가 발생했습니다 (#{response.code})" }
      end
    rescue => e
      AppLogger.debug("검사신청 조회 API 연결 실패: #{e.message}")
      { success: false, error: "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." }
    end
  end
  
  def get_inspection_management_requests(token)
    AppLogger.debug("검사신청 관리 조회 API 호출")
    
    begin
      url = "#{@base_url}/api/inspection-management/requests"
      
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 3
      http.read_timeout = 5
      
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{token}"
      
      response = http.request(request)
      
      if response.code == '200'
        data = JSON.parse(response.body)
        { success: true, data: data }
      else
        { success: false, error: "검사신청 관리 조회 중 오류가 발생했습니다 (#{response.code})" }
      end
    rescue => e
      AppLogger.debug("검사신청 관리 조회 API 연결 실패: #{e.message}")
      { success: false, error: "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." }
    end
  end
  
  # 검사신청 생성 API 호출
  def create_inspection_request(data, token)
    AppLogger.debug("검사신청 생성 API 호출")
    AppLogger.debug("검사신청 생성 요청: #{data[:assembly_codes].length}개 항목, 검사일: #{data[:request_date]}")
    AppLogger.debug("Flask API로 전송할 데이터: #{data.to_json}")
    AppLogger.debug("JWT 토큰 설정됨: Bearer #{token[0..20]}...")
    
    begin
      uri = URI("#{@base_url}/api/inspection-requests")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 3
      http.read_timeout = 5
      
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{token}"
      request.body = data.to_json
      
      response = http.request(request)
      AppLogger.debug("Flask API 검사신청 응답: #{response.code}")
      AppLogger.debug("Flask API 검사신청 응답 본문: #{response.body}")
      
      if response.code == '200'
        parsed_response = JSON.parse(response.body)
        AppLogger.debug("Flask API 파싱된 응답: #{parsed_response}")
        { success: true, data: parsed_response }
      else
        { success: false, error: "검사신청 중 오류가 발생했습니다 (#{response.code})" }
      end
    rescue => e
      AppLogger.debug("검사신청 API 연결 실패: #{e.message}")
      { success: false, error: "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." }
    end
  end
  
  # 검사신청 승인 API 호출
  def approve_inspection_request(request_id, token)
    AppLogger.debug("검사신청 승인 API 호출: ID #{request_id}")
    
    begin
      uri = URI("#{@base_url}/api/inspection-requests/#{request_id}/approve")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 3
      http.read_timeout = 5
      
      request = Net::HTTP::Put.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{token}"
      
      response = http.request(request)
      AppLogger.debug("Flask API 승인 응답: #{response.code}")
      AppLogger.debug("Flask API 승인 응답 본문: #{response.body}")
      
      if response.code == '200'
        parsed_response = JSON.parse(response.body)
        { success: true, data: parsed_response }
      else
        error_data = JSON.parse(response.body) rescue {}
        { success: false, error: error_data['message'] || "승인 중 오류가 발생했습니다 (#{response.code})" }
      end
    rescue => e
      AppLogger.debug("검사신청 승인 API 연결 실패: #{e.message}")
      { success: false, error: "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." }
    end
  end
  
  # 검사신청 거부 API 호출
  def reject_inspection_request(request_id, reject_reason, token)
    AppLogger.debug("검사신청 거부 API 호출: ID #{request_id}, 사유: #{reject_reason}")
    
    begin
      uri = URI("#{@base_url}/api/inspection-requests/#{request_id}/reject")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 3
      http.read_timeout = 5
      
      request = Net::HTTP::Put.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{token}"
      request.body = { reject_reason: reject_reason }.to_json
      
      response = http.request(request)
      AppLogger.debug("Flask API 거부 응답: #{response.code}")
      AppLogger.debug("Flask API 거부 응답 본문: #{response.body}")
      
      if response.code == '200'
        parsed_response = JSON.parse(response.body)
        { success: true, data: parsed_response }
      else
        error_data = JSON.parse(response.body) rescue {}
        { success: false, error: error_data['message'] || "거부 중 오류가 발생했습니다 (#{response.code})" }
      end
    rescue => e
      AppLogger.debug("검사신청 거부 API 연결 실패: #{e.message}")
      { success: false, error: "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." }
    end
  end
  
  # 검사신청 확정 API 호출
  def confirm_inspection_request(request_id, confirmed_date, token)
    AppLogger.debug("검사신청 확정 API 호출: ID #{request_id}, 확정일: #{confirmed_date}")
    
    begin
      uri = URI("#{@base_url}/api/inspection-requests/#{request_id}/confirm")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 3
      http.read_timeout = 5
      
      request = Net::HTTP::Put.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{token}"
      request.body = { confirmed_date: confirmed_date }.to_json
      
      response = http.request(request)
      AppLogger.debug("Flask API 확정 응답: #{response.code}")
      AppLogger.debug("Flask API 확정 응답 본문: #{response.body}")
      
      if response.code == '200'
        parsed_response = JSON.parse(response.body)
        { success: true, data: parsed_response }
      else
        error_data = JSON.parse(response.body) rescue {}
        { success: false, error: error_data['message'] || "확정 중 오류가 발생했습니다 (#{response.code})" }
      end
    rescue => e
      AppLogger.debug("검사신청 확정 API 연결 실패: #{e.message}")
      { success: false, error: "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." }
    end
  end
  
  # 검사신청 삭제 API 호출
  def delete_inspection_request(request_id, token)
    AppLogger.debug("검사신청 삭제 API 호출: ID #{request_id}")
    
    begin
      uri = URI("#{@base_url}/api/inspection-requests/#{request_id}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 3
      http.read_timeout = 5
      
      request = Net::HTTP::Delete.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{token}"
      
      response = http.request(request)
      AppLogger.debug("Flask API 삭제 응답: #{response.code}")
      AppLogger.debug("Flask API 삭제 응답 본문: #{response.body}")
      
      if response.code == '200'
        parsed_response = JSON.parse(response.body)
        { success: true, data: parsed_response }
      else
        error_data = JSON.parse(response.body) rescue {}
        { success: false, error: error_data['message'] || "삭제 중 오류가 발생했습니다 (#{response.code})" }
      end
    rescue => e
      AppLogger.debug("검사신청 삭제 API 연결 실패: #{e.message}")
      { success: false, error: "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." }
    end
  end
  
  # 저장된 리스트에 항목 추가 API 호출
  def save_assembly_list(items, token)
    AppLogger.debug("저장된 리스트 추가 API 호출: #{items.length}개 항목")
    
    begin
      request = Net::HTTP::Post.new("/api/saved-list")
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{token}"
      request.body = { items: items }.to_json
      
      AppLogger.debug("Flask API 요청 전송 중...")
      response = execute_request(request)
      AppLogger.debug("Flask API 저장 응답: #{response.code}")
      AppLogger.debug("Flask API 응답 본문: #{response.body}")
      
      if response.code == '200'
        begin
          parsed_response = JSON.parse(response.body)
          AppLogger.debug("JSON 파싱 성공: #{parsed_response}")
          
          # 저장 후 검색 캐시 무효화 (새로 저장된 항목이 검색에서 제외되어야 함)
          clear_cache
          
          { success: true, message: parsed_response['message'], total: parsed_response['total'] }
        rescue JSON::ParserError => json_error
          AppLogger.debug("JSON 파싱 오류: #{json_error.message}")
          { success: false, error: "서버 응답 형식 오류: #{json_error.message}" }
        end
      else
        begin
          error_data = JSON.parse(response.body)
          error_message = error_data['message'] || "저장 중 오류가 발생했습니다 (#{response.code})"
        rescue JSON::ParserError
          error_message = "저장 중 오류가 발생했습니다 (#{response.code})"
        end
        AppLogger.debug("Flask API 저장 실패: #{error_message}")
        { success: false, error: error_message }
      end
    rescue Net::ReadTimeout, Net::OpenTimeout => timeout_error
      AppLogger.debug("Flask API 타임아웃 오류: #{timeout_error.message}")
      { success: false, error: "요청 시간이 초과되었습니다. 잠시 후 다시 시도해주세요." }
    rescue EOFError, Errno::ECONNRESET => connection_error
      AppLogger.debug("Flask API 연결 오류: #{connection_error.message}")
      { success: false, error: "서버 연결이 끊어졌습니다. 잠시 후 다시 시도해주세요." }
    rescue => e
      AppLogger.debug("저장된 리스트 추가 API 일반 오류: #{e.class} - #{e.message}")
      AppLogger.debug("오류 백트레이스: #{e.backtrace.first(5).join('\n')}")
      { success: false, error: "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." }
    end
  end
  
  # 저장된 리스트 조회 API 호출
  def get_saved_list(token)
    AppLogger.debug("저장된 리스트 조회 API 호출")
    
    begin
      request = Net::HTTP::Get.new("/api/saved-list")
      request['Authorization'] = "Bearer #{token}"
      
      response = execute_request(request)
      AppLogger.debug("Flask API 조회 응답: #{response.code}")
      
      if response.code == '200'
        parsed_response = JSON.parse(response.body)
        { success: true, items: parsed_response['items'], total: parsed_response['total'] }
      else
        error_data = JSON.parse(response.body) rescue {}
        { success: false, error: error_data['message'] || "조회 중 오류가 발생했습니다 (#{response.code})" }
      end
    rescue => e
      AppLogger.debug("저장된 리스트 조회 API 연결 실패: #{e.message}")
      { success: false, error: "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." }
    end
  end
  
  # 저장된 리스트에서 특정 항목 삭제 API 호출
  def delete_saved_item(assembly_code, token)
    AppLogger.debug("저장된 항목 삭제 API 호출: #{assembly_code}")
    
    begin
      uri = URI("#{@base_url}/api/saved-list/#{assembly_code}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 3
      http.read_timeout = 5
      
      request = Net::HTTP::Delete.new(uri)
      request['Authorization'] = "Bearer #{token}"
      
      response = http.request(request)
      AppLogger.debug("Flask API 항목 삭제 응답: #{response.code}")
      
      if response.code == '200'
        parsed_response = JSON.parse(response.body)
        { success: true, message: parsed_response['message'] }
      else
        error_data = JSON.parse(response.body) rescue {}
        { success: false, error: error_data['message'] || "삭제 중 오류가 발생했습니다 (#{response.code})" }
      end
    rescue => e
      AppLogger.debug("저장된 항목 삭제 API 연결 실패: #{e.message}")
      { success: false, error: "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." }
    end
  end
  
  # 저장된 리스트 전체 삭제 API 호출
  def clear_saved_list(token)
    AppLogger.debug("저장된 리스트 전체 삭제 API 호출")
    
    begin
      uri = URI("#{@base_url}/api/saved-list/clear")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 3
      http.read_timeout = 5
      
      request = Net::HTTP::Delete.new(uri)
      request['Authorization'] = "Bearer #{token}"
      
      response = http.request(request)
      AppLogger.debug("Flask API 전체 삭제 응답: #{response.code}")
      
      if response.code == '200'
        parsed_response = JSON.parse(response.body)
        { success: true, message: parsed_response['message'] }
      else
        error_data = JSON.parse(response.body) rescue {}
        { success: false, error: error_data['message'] || "삭제 중 오류가 발생했습니다 (#{response.code})" }
      end
    rescue => e
      AppLogger.debug("저장된 리스트 전체 삭제 API 연결 실패: #{e.message}")
      { success: false, error: "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." }
    end
  end
  
  # =================================
  # 검사신청 관리 API 메서드들
  # =================================
  
  # 검사신청 목록 조회 API 호출
  def get_inspection_management_requests(token)
    AppLogger.debug("검사신청 관리 목록 조회 API 호출")
    
    # 캐시 키 설정 (짧은 TTL로 설정하여 빠른 업데이트 보장)
    cache_key = "inspection_management_requests"
    cached_result = get_cache(cache_key)
    if cached_result
      AppLogger.debug("검사신청 관리 목록 캐시에서 반환")
      return cached_result
    end
    
    begin
      uri = URI("#{@base_url}/api/inspection-management/requests")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 3
      http.read_timeout = 10
      
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{token}"
      request['Content-Type'] = 'application/json'
      
      response = http.request(request)
      AppLogger.debug("Flask API 검사신청 관리 조회 응답: #{response.code}")
      
      if response.code == '200'
        parsed_response = JSON.parse(response.body)
        if parsed_response['success']
          result = { success: true, data: parsed_response['data'] }
          # 매우 짧은 TTL (5초)로 캐시하여 빠른 업데이트 보장
          set_cache(cache_key, result, 5)
          result
        else
          { success: false, error: parsed_response['message'] || '검사신청 조회 실패' }
        end
      else
        error_data = JSON.parse(response.body) rescue {}
        { success: false, error: error_data['message'] || "검사신청 조회 중 오류가 발생했습니다 (#{response.code})" }
      end
    rescue => e
      AppLogger.debug("검사신청 관리 조회 API 연결 실패: #{e.message}")
      { success: false, error: "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." }
    end
  end
  
  # 검사신청 승인 API 호출
  def approve_inspection_request(request_id, token)
    AppLogger.debug("검사신청 승인 API 호출: #{request_id}")
    
    begin
      uri = URI("#{@base_url}/api/inspection-management/requests/#{request_id}/approve")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 3
      http.read_timeout = 10
      
      request = Net::HTTP::Put.new(uri)
      request['Authorization'] = "Bearer #{token}"
      request['Content-Type'] = 'application/json'
      
      response = http.request(request)
      AppLogger.debug("Flask API 검사신청 승인 응답: #{response.code}")
      
      if response.code.to_i.between?(200, 299)
        parsed_response = JSON.parse(response.body)
        { success: parsed_response['success'], message: parsed_response['message'] }
      else
        error_data = JSON.parse(response.body) rescue {}
        { success: false, message: error_data['message'] || "승인 중 오류가 발생했습니다 (#{response.code})" }
      end
    rescue => e
      AppLogger.debug("검사신청 승인 API 연결 실패: #{e.message}")
      { success: false, message: "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." }
    end
  end
  
  # 검사신청 거부 API 호출
  def reject_inspection_request(request_id, reject_reason, token)
    AppLogger.debug("검사신청 거부 API 호출: #{request_id}")
    
    begin
      uri = URI("#{@base_url}/api/inspection-management/requests/#{request_id}/reject")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 3
      http.read_timeout = 10
      
      request = Net::HTTP::Put.new(uri)
      request['Authorization'] = "Bearer #{token}"
      request['Content-Type'] = 'application/json'
      request.body = { reject_reason: reject_reason }.to_json
      
      response = http.request(request)
      AppLogger.debug("Flask API 검사신청 거부 응답: #{response.code}")
      
      if response.code.to_i.between?(200, 299)
        parsed_response = JSON.parse(response.body)
        { success: parsed_response['success'], message: parsed_response['message'] }
      else
        error_data = JSON.parse(response.body) rescue {}
        { success: false, message: error_data['message'] || "거부 중 오류가 발생했습니다 (#{response.code})" }
      end
    rescue => e
      AppLogger.debug("검사신청 거부 API 연결 실패: #{e.message}")
      { success: false, message: "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." }
    end
  end
  
  # 검사신청 확정 API 호출
  def confirm_inspection_request(request_id, confirmed_date, token)
    AppLogger.debug("검사신청 확정 API 호출: #{request_id}")
    
    begin
      uri = URI("#{@base_url}/api/inspection-management/requests/#{request_id}/confirm")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 3
      http.read_timeout = 10
      
      request = Net::HTTP::Put.new(uri)
      request['Authorization'] = "Bearer #{token}"
      request['Content-Type'] = 'application/json'
      request.body = { confirmed_date: confirmed_date }.to_json
      
      response = http.request(request)
      AppLogger.debug("Flask API 검사신청 확정 응답: #{response.code}")
      
      if response.code.to_i.between?(200, 299)
        parsed_response = JSON.parse(response.body)
        { success: parsed_response['success'], message: parsed_response['message'] }
      else
        error_data = JSON.parse(response.body) rescue {}
        { success: false, message: error_data['message'] || "확정 중 오류가 발생했습니다 (#{response.code})" }
      end
    rescue => e
      AppLogger.debug("검사신청 확정 API 연결 실패: #{e.message}")
      { success: false, message: "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." }
    end
  end
  
  # 검사신청 삭제 API 호출 (Level 3+ 또는 취소 기능)
  def delete_inspection_request(request_id, token)
    AppLogger.debug("검사신청 삭제/취소 API 호출: #{request_id}")
    
    begin
      # 먼저 취소 API 시도 (PUT /cancel)
      uri = URI("#{@base_url}/api/inspection-management/requests/#{request_id}/cancel")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 3
      http.read_timeout = 10
      
      request = Net::HTTP::Put.new(uri)
      request['Authorization'] = "Bearer #{token}"
      request['Content-Type'] = 'application/json'
      
      response = http.request(request)
      AppLogger.debug("Flask API 검사신청 취소 응답: #{response.code}")
      
      if response.code.to_i.between?(200, 299)
        parsed_response = JSON.parse(response.body)
        # 취소 성공 시 캐시 무효화
        clear_cache("inspection_management_requests")
        { success: parsed_response['success'], message: parsed_response['message'] }
      else
        # 취소 실패 시 삭제 API 시도 (DELETE)
        AppLogger.debug("취소 실패, 삭제 API 시도")
        uri = URI("#{@base_url}/api/inspection-management/requests/#{request_id}")
        request = Net::HTTP::Delete.new(uri)
        request['Authorization'] = "Bearer #{token}"
        request['Content-Type'] = 'application/json'
        
        response = http.request(request)
        AppLogger.debug("Flask API 검사신청 삭제 응답: #{response.code}")
        
        if response.code.to_i.between?(200, 299)
          parsed_response = JSON.parse(response.body)
          # 삭제 성공 시 캐시 무효화
          clear_cache("inspection_management_requests")
          { success: parsed_response['success'], message: parsed_response['message'] }
        else
          error_data = JSON.parse(response.body) rescue {}
          { success: false, message: error_data['message'] || "삭제 중 오류가 발생했습니다 (#{response.code})" }
        end
      end
    rescue => e
      AppLogger.debug("검사신청 삭제/취소 API 연결 실패: #{e.message}")
      { success: false, message: "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." }
    end
  end
  
  # 캐시 무효화 메서드
  def clear_cache(key)
    @cache_mutex.synchronize do
      @cache.delete(key)
      AppLogger.debug("캐시 무효화: #{key}")
    end
  end
end