# -*- coding: utf-8 -*-

require 'sinatra/base'
require 'json'
require_relative '../config/settings'
require_relative '../lib/logger'
require_relative '../lib/flask_client'
require_relative '../lib/process_manager'

class InspectionController < Sinatra::Base
  enable :sessions
  set :session_secret, SESSION_SECRET
  
  # 뷰 및 정적 파일 설정
  set :views, File.dirname(__FILE__) + '/../views'
  set :public_folder, File.dirname(__FILE__) + '/../public'
  
  # 인증 확인 헬퍼
  before do
    unless session[:jwt_token]
      halt 401, { error: '로그인이 필요합니다.' }.to_json if request.path.start_with?('/api/')
      redirect '/login' unless request.path.start_with?('/api/')
    end
  end
  
  # 테스트 라우트 (최우선)
  get '/admin-test' do
    "관리자 기능 테스트 성공! #{Time.now}"
  end
  
  # 관리자 패널 페이지 (최우선)
  get '/admin' do
    puts "관리자 패널 라우트 접근됨"
    # 권한 확인
    user_info = session[:user_info]
    if user_info.nil? || user_info['permission_level'].to_i < 2
      redirect '/'
    end
    
    @user_info = session[:user_info] || {}
    erb :admin_panel, layout: false
  end
  
  # 저장된 리스트 페이지
  get '/saved-list' do
    AppLogger.debug("저장된 리스트 페이지 접근")
    
    # 테스트 데이터 제거 - 실제 저장된 리스트만 표시
    
    @saved_list = session[:saved_list] || []
    @user_info = session[:user_info] || {}
    @total_weight = 0
    
    AppLogger.debug("저장된 리스트 로드 - 세션 데이터: #{session[:saved_list].inspect}")
    AppLogger.debug("저장된 리스트 로드 - @saved_list 크기: #{@saved_list.length}")
    
    # 검사신청 가능한 항목만 필터링 (모든 공정이 완료되지 않은 항목)
    @saved_list = @saved_list.select do |item|
      next_process = ProcessManager.get_next_process(item)
      !next_process.nil?
    end
    
    AppLogger.debug("저장된 리스트 조회: 전체 #{session[:saved_list]&.length || 0}개, 검사신청 가능 #{@saved_list.length}개")
    
    # 각 항목의 다음 공정 계산
    @next_processes = {}
    @total_weight = 0
    
    @saved_list.each do |item|
      next_process = ProcessManager.get_next_process(item)
      @next_processes[item['assembly']] = next_process ? ProcessManager.to_korean(next_process) : '완료'
      @total_weight += (item['weight_net'] || 0).to_f
    end
    
    erb :saved_list, layout: false  # 원본 HTML 구조를 유지하기 위해 layout 비활성화
  end
  
  # 검사신청 조회 페이지
  get '/inspection-requests' do
    erb :inspection_requests, layout: :layout
  end
  
  
  # 디버깅용 세션 조회 API
  get '/api/debug-session' do
    content_type :json
    {
      saved_list: session[:saved_list] || [],
      saved_list_count: (session[:saved_list] || []).length,
      user_info: session[:user_info] || {}
    }.to_json
  end
  
  # 검사신청 조회 API
  get '/api/inspection-requests' do
    content_type :json
    
    user_info = session[:user_info]
    user_level = user_info['permission_level'].to_i
    username = user_level == 1 ? user_info['username'] : nil
    
    flask_client = FlaskClient.new
    result = flask_client.get_inspection_requests(session[:jwt_token], user_level, username)
    
    if result[:success]
      { success: true, data: result[:data] }.to_json
    else
      { success: false, error: result[:error] }.to_json
    end
  end
  
  # 검사신청 생성 API
  post '/api/create-inspection-request' do
    content_type :json
    
    begin
      request_body = JSON.parse(request.body.read)
      assembly_codes = request_body['assembly_codes']
      inspection_type = request_body['inspection_type']
      request_date = request_body['request_date']
      
      if assembly_codes.nil? || assembly_codes.empty?
        return { success: false, error: '검사신청할 항목을 선택해주세요.' }.to_json
      end
      
      if inspection_type.nil? || inspection_type.empty?
        return { success: false, error: '검사 타입이 지정되지 않았습니다.' }.to_json
      end
      
      if request_date.nil? || request_date.empty?
        return { success: false, error: '검사 희망일을 선택해주세요.' }.to_json
      end
      
      AppLogger.debug("검사신청 생성 API 호출")
      AppLogger.debug("검사신청 생성 요청: #{assembly_codes.length}개 항목, 검사일: #{request_date}")
      
      # 저장된 리스트에서 선택된 항목들의 다음 공정 확인
      saved_list = session[:saved_list] || []
      AppLogger.debug("세션 저장된 리스트: #{saved_list.inspect}")
      AppLogger.debug("요청된 조립품 코드: #{assembly_codes.inspect}")
      
      selected_items = saved_list.select { |item| 
        item_code = item['name'] || item['assembly']
        AppLogger.debug("항목 코드 확인: #{item_code} - 매칭: #{assembly_codes.include?(item_code)}")
        assembly_codes.include?(item_code)
      }
      
      if selected_items.empty?
        return { success: false, error: '선택된 항목들이 저장된 리스트에 없습니다.' }.to_json
      end
      
      # 모든 항목의 다음 공정이 동일한지 확인
      next_processes = selected_items.map { |item| ProcessManager.get_next_process(item) }
      unique_processes = next_processes.uniq
      
      if unique_processes.length > 1
        return { success: false, error: '같은 공정의 항목들만 함께 검사신청할 수 있습니다.' }.to_json
      end
      
      common_next_process = unique_processes.first
      
      if common_next_process.nil?
        return { success: false, error: '선택한 항목들은 이미 모든 공정이 완료되었습니다.' }.to_json
      end
      
      AppLogger.debug("공통 다음 공정: #{common_next_process}")
      
      # Flask API 호출
      data = {
        assembly_codes: assembly_codes,
        inspection_type: common_next_process,
        request_date: request_date
      }
      
      flask_client = FlaskClient.new
      result = flask_client.create_inspection_request(data, session[:jwt_token])
      
      if result[:success]
        response_data = result[:data]
        
        if response_data['success']
          # 성공한 항목들을 저장된 리스트에서 제거
          successful_codes = assembly_codes
          if response_data['duplicate_items'] && response_data['duplicate_items'].length > 0
            duplicate_codes = response_data['duplicate_items'].map { |item| item['assembly_code'] }
            successful_codes = assembly_codes - duplicate_codes
          end
          
          if successful_codes.length > 0
            session[:saved_list] = saved_list.reject { |item| successful_codes.include?(item['name'] || item['assembly']) }
            successful_codes.each do |code|
              AppLogger.debug("저장된 리스트에서 #{code} 제거 완료")
            end
            AppLogger.debug("남은 저장된 리스트: #{session[:saved_list].length}개")
          end
          
          if response_data['inserted_count'] > 0
            AppLogger.debug("검사신청 성공: #{response_data['inserted_count']}개")
          else
            AppLogger.debug("검사신청 실패: ")
          end
        end
        
        { success: true, data: response_data }.to_json
      else
        { success: false, error: result[:error] }.to_json
      end
      
    rescue JSON::ParserError
      { success: false, error: '잘못된 요청 형식입니다.' }.to_json
    rescue => e
      AppLogger.debug("검사신청 API 오류: #{e.message}")
      { success: false, error: '검사신청 중 오류가 발생했습니다.' }.to_json
    end
  end
  
  # 검사신청 승인 API (관리자용)
  put '/api/inspection-requests/:id/approve' do
    content_type :json
    
    # 권한 확인
    user_info = session[:user_info]
    if user_info.nil? || user_info['permission_level'].to_i < 2
      return { success: false, error: '승인 권한이 없습니다.' }.to_json
    end
    
    begin
      request_id = params[:id].to_i
      
      if request_id <= 0
        return { success: false, error: '유효하지 않은 요청 ID입니다.' }.to_json
      end
      
      AppLogger.debug("검사신청 승인 API 호출: ID #{request_id}")
      
      flask_client = FlaskClient.new
      result = flask_client.approve_inspection_request(request_id, session[:jwt_token])
      
      if result[:success]
        AppLogger.debug("검사신청 승인 성공: #{result[:data]}")
        { success: true, message: result[:data]['message'] }.to_json
      else
        AppLogger.debug("검사신청 승인 실패: #{result[:error]}")
        { success: false, error: result[:error] }.to_json
      end
      
    rescue => e
      AppLogger.debug("검사신청 승인 API 오류: #{e.message}")
      { success: false, error: '승인 중 오류가 발생했습니다.' }.to_json
    end
  end
  
  # 검사신청 거부 API (관리자용)
  put '/api/inspection-requests/:id/reject' do
    content_type :json
    
    # 권한 확인
    user_info = session[:user_info]
    if user_info.nil? || user_info['permission_level'].to_i < 2
      return { success: false, error: '거부 권한이 없습니다.' }.to_json
    end
    
    begin
      request_id = params[:id].to_i
      request_body = JSON.parse(request.body.read)
      reject_reason = request_body['reject_reason'] || '거부됨'
      
      if request_id <= 0
        return { success: false, error: '유효하지 않은 요청 ID입니다.' }.to_json
      end
      
      AppLogger.debug("검사신청 거부 API 호출: ID #{request_id}, 사유: #{reject_reason}")
      
      flask_client = FlaskClient.new
      result = flask_client.reject_inspection_request(request_id, reject_reason, session[:jwt_token])
      
      if result[:success]
        AppLogger.debug("검사신청 거부 성공: #{result[:data]}")
        { success: true, message: result[:data]['message'] }.to_json
      else
        AppLogger.debug("검사신청 거부 실패: #{result[:error]}")
        { success: false, error: result[:error] }.to_json
      end
      
    rescue JSON::ParserError
      { success: false, error: '잘못된 요청 형식입니다.' }.to_json
    rescue => e
      AppLogger.debug("검사신청 거부 API 오류: #{e.message}")
      { success: false, error: '거부 중 오류가 발생했습니다.' }.to_json
    end
  end
  
  # 검사신청 확정 API (관리자용)
  put '/api/inspection-requests/:id/confirm' do
    content_type :json
    
    # 권한 확인
    user_info = session[:user_info]
    if user_info.nil? || user_info['permission_level'].to_i < 3
      return { success: false, error: '확정 권한이 없습니다 (Level 3+ 필요).' }.to_json
    end
    
    begin
      request_id = params[:id].to_i
      request_body = JSON.parse(request.body.read)
      confirmed_date = request_body['confirmed_date']
      
      if request_id <= 0
        return { success: false, error: '유효하지 않은 요청 ID입니다.' }.to_json
      end
      
      if confirmed_date.nil? || confirmed_date.empty?
        return { success: false, error: '확정 날짜를 입력해주세요.' }.to_json
      end
      
      AppLogger.debug("검사신청 확정 API 호출: ID #{request_id}, 확정일: #{confirmed_date}")
      
      flask_client = FlaskClient.new
      result = flask_client.confirm_inspection_request(request_id, confirmed_date, session[:jwt_token])
      
      if result[:success]
        AppLogger.debug("검사신청 확정 성공: #{result[:data]}")
        { success: true, message: result[:data]['message'] }.to_json
      else
        AppLogger.debug("검사신청 확정 실패: #{result[:error]}")
        { success: false, error: result[:error] }.to_json
      end
      
    rescue JSON::ParserError
      { success: false, error: '잘못된 요청 형식입니다.' }.to_json
    rescue => e
      AppLogger.debug("검사신청 확정 API 오류: #{e.message}")
      { success: false, error: '확정 중 오류가 발생했습니다.' }.to_json
    end
  end
  
  # 검사신청 삭제 API (관리자용)
  delete '/api/inspection-requests/:id' do
    content_type :json
    
    # 권한 확인 (Level 3+ 필요)
    user_info = session[:user_info]
    if user_info.nil? || user_info['permission_level'].to_i < 3
      return { success: false, error: '삭제 권한이 없습니다 (Level 3+ 필요).' }.to_json
    end
    
    begin
      request_id = params[:id].to_i
      
      if request_id <= 0
        return { success: false, error: '유효하지 않은 요청 ID입니다.' }.to_json
      end
      
      AppLogger.debug("검사신청 삭제 API 호출: ID #{request_id}")
      
      flask_client = FlaskClient.new
      result = flask_client.delete_inspection_request(request_id, session[:jwt_token])
      
      if result[:success]
        AppLogger.debug("검사신청 삭제 성공: #{result[:data]}")
        { success: true, message: result[:data]['message'] }.to_json
      else
        AppLogger.debug("검사신청 삭제 실패: #{result[:error]}")
        { success: false, error: result[:error] }.to_json
      end
      
    rescue => e
      AppLogger.debug("검사신청 삭제 API 오류: #{e.message}")
      { success: false, error: '삭제 중 오류가 발생했습니다.' }.to_json
    end
  end
  
  private
  
  def current_user
    session[:user_info]
  end
end