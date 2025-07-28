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
  end
  
  # 로그인 API 호출
  def login(username, password)
    password_hash = ProcessManager.sha256_hash(password)
    AppLogger.debug("로그인 시도 - 사용자명: #{username}")
    
    begin
      uri = URI("#{@base_url}/api/login")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 10
      http.read_timeout = 10
      
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = {
        username: username,
        password_hash: password_hash
      }.to_json
      
      response = http.request(request)
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
  
  # 조립품 검색 API 호출
  def search_assemblies(query, token)
    AppLogger.debug("검색 API 호출")
    AppLogger.debug("검색어: #{query}")
    
    begin
      url = "#{@base_url}/api/assemblies/search?q=#{query}"
      AppLogger.debug("Flask API 요청: #{url}")
      
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 10
      http.read_timeout = 30
      
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{token}" if token && !token.empty?
      
      response = http.request(request)
      AppLogger.debug("Flask API 응답: #{response.code}")
      
      if response.code == '200'
        data = JSON.parse(response.body)
        AppLogger.debug("조립품 개수: #{data['data'] ? data['data'].length : 0}")
        { success: true, data: data['data'] || [] }
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
      http.open_timeout = 10
      http.read_timeout = 30
      
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
  
  # 검사신청 생성 API 호출
  def create_inspection_request(data, token)
    AppLogger.debug("검사신청 생성 API 호출")
    AppLogger.debug("검사신청 생성 요청: #{data[:assembly_codes].length}개 항목, 검사일: #{data[:request_date]}")
    AppLogger.debug("Flask API로 전송할 데이터: #{data.to_json}")
    AppLogger.debug("JWT 토큰 설정됨: Bearer #{token[0..20]}...")
    
    begin
      uri = URI("#{@base_url}/api/inspection-requests")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 10
      http.read_timeout = 30
      
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
      http.open_timeout = 10
      http.read_timeout = 30
      
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
      http.open_timeout = 10
      http.read_timeout = 30
      
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
      http.open_timeout = 10
      http.read_timeout = 30
      
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
      http.open_timeout = 10
      http.read_timeout = 30
      
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
end