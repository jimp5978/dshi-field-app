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
  
  # 인증 확인 헬퍼 - API 경로와 이 컨트롤러에서 처리하는 경로만 대상
  before do
    # 이 컨트롤러에서 처리하는 경로들만 인증 확인
    controller_paths = [
      '/saved-list',
      '/api/create-inspection-request',
      '/api/inspection-management/requests',
      '/api/debug-session'
    ]
    
    # API 경로 또는 이 컨트롤러의 경로인 경우에만 인증 확인
    if request.path.start_with?('/api/') || controller_paths.include?(request.path)
      unless session[:jwt_token]
        halt 401, { error: '로그인이 필요합니다.' }.to_json if request.path.start_with?('/api/')
        redirect '/login' unless request.path.start_with?('/api/')
      end
    end
  end
  
  # 테스트 라우트 (최우선)
  get '/admin-test' do
    "관리자 기능 테스트 성공! #{Time.now}"
  end
  
  # 검사신청 관리 페이지 (모든 Level 접근 가능) - 이미 app.rb에서 처리하므로 제거
  
  # 저장된 리스트 페이지
  get '/saved-list' do
    AppLogger.debug("저장된 리스트 페이지 접근")
    
    @user_info = session[:user_info] || {}
    @saved_list = []
    @total_weight = 0
    
    # Flask API를 통해 사용자별 저장된 리스트 조회
    flask_client = FlaskClient.new
    result = flask_client.get_saved_list(session[:jwt_token])
    
    if result[:success]
      @saved_list = result[:items] || []
      AppLogger.debug("Flask API에서 저장된 리스트 조회 성공: #{@saved_list.length}개")
    else
      AppLogger.debug("Flask API에서 저장된 리스트 조회 실패: #{result[:error]}")
      @saved_list = []
    end
    
    # Flask API에서 이미 상태 계산이 완료된 데이터를 받으므로 총 중량만 계산
    @total_weight = 0
    
    @saved_list.each do |item|
      @total_weight += (item['weight_net'] || 0).to_f
      AppLogger.debug("#{item['assembly_code']} - 상태: #{item['status']}, 마지막 공정: #{item['lastProcess']}, 다음 공정: #{item['nextProcess']}")
    end
    
    AppLogger.debug("저장된 리스트 조회 결과: #{@saved_list.length}개, 총 중량: #{@total_weight}kg")
    
    erb :saved_list, layout: false  # 원본 HTML 구조를 유지하기 위해 layout 비활성화
  end
  
  # 기존 /inspection-requests 페이지는 삭제됨 (검사신청 관리로 통합)
  
  
  # 디버깅용 세션 조회 API
  get '/api/debug-session' do
    content_type :json
    {
      saved_list: session[:saved_list] || [],
      saved_list_count: (session[:saved_list] || []).length,
      user_info: session[:user_info] || {},
      jwt_token: session[:jwt_token] ? "존재함 (#{session[:jwt_token][0..20]}...)" : "없음",
      session_keys: session.keys
    }.to_json
  end
  
  # 검사신청 관리 API 프록시들
  get '/api/inspection-management/requests' do
    content_type :json
    
    begin
      # 기본값으로 'active' 탭, 1페이지 설정
      tab = params[:tab] || 'active'
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 20).to_i
      search_term = params[:search] || ''
      
      AppLogger.debug("검사신청 관리 조회 요청 (GET): tab=#{tab}, page=#{page}, search=#{search_term}")
      
      # 사용자 정보 조회
      user_info = session[:user_info] || {}
      user_level = user_info['permission_level'] || 1
      username = user_info['username']
      
      flask_client = FlaskClient.new
      result = flask_client.get_inspection_management_requests(session[:jwt_token])
      
      if result[:success]
        all_requests = result[:data]['requests'] || []
        
        # 탭별 필터링
        filtered_requests = case tab
        when 'active'
          # 기본 탭: 대기중, 승인됨 상태
          all_requests.select { |req| ['대기중', '승인됨'].include?(req['status']) }
        when 'completed'
          # 완료 탭: 확정됨, 거부됨 상태
          all_requests.select { |req| ['확정됨', '거부됨'].include?(req['status']) }
        else
          all_requests
        end
        
        # 검색 필터링 (완료 탭에서만)
        if tab == 'completed' && !search_term.empty?
          filtered_requests = filtered_requests.select do |req|
            req['assembly_code']&.downcase&.include?(search_term.downcase)
          end
        end
        
        # 페이지네이션 (완료 탭에서만)
        total_count = filtered_requests.length
        if tab == 'completed'
          start_index = (page - 1) * per_page
          end_index = start_index + per_page - 1
          paginated_requests = filtered_requests[start_index..end_index] || []
          
          pagination_info = {
            current_page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: (total_count.to_f / per_page).ceil
          }
        else
          paginated_requests = filtered_requests
          pagination_info = nil
        end
        
        # 응답 구조 생성
        response_data = {
          success: true,
          data: {
            requests: paginated_requests,
            user_level: result[:data]['user_level'],
            pagination: pagination_info
          }
        }
        
        AppLogger.debug("탭별 필터링 결과 (GET): tab=#{tab}, 전체=#{all_requests.length}, 필터링=#{filtered_requests.length}, 페이지=#{paginated_requests.length}")
        response_data.to_json
      else
        { success: false, error: result[:error] }.to_json
      end
      
    rescue => e
      AppLogger.debug("검사신청 관리 조회 API 오류: #{e.message}")
      { success: false, error: '검사신청 조회 중 오류가 발생했습니다.' }.to_json
    end
  end
  
  put '/api/inspection-management/requests/:id/approve' do
    content_type :json
    
    begin
      request_id = params[:id].to_i
      flask_client = FlaskClient.new
      result = flask_client.approve_inspection_request(request_id, session[:jwt_token])
      
      result.to_json
      
    rescue => e
      AppLogger.debug("검사신청 승인 API 오류: #{e.message}")
      { success: false, message: '검사신청 승인 중 오류가 발생했습니다.' }.to_json
    end
  end
  
  put '/api/inspection-management/requests/:id/reject' do
    content_type :json
    
    begin
      request_id = params[:id].to_i
      request_body = JSON.parse(request.body.read)
      reject_reason = request_body['reject_reason'] || '거부됨'
      
      flask_client = FlaskClient.new
      result = flask_client.reject_inspection_request(request_id, reject_reason, session[:jwt_token])
      
      result.to_json
      
    rescue => e
      AppLogger.debug("검사신청 거부 API 오류: #{e.message}")
      { success: false, message: '검사신청 거부 중 오류가 발생했습니다.' }.to_json
    end
  end
  
  put '/api/inspection-management/requests/:id/confirm' do
    content_type :json
    
    begin
      request_id = params[:id].to_i
      request_body = JSON.parse(request.body.read)
      confirmed_date = request_body['confirmed_date']
      
      flask_client = FlaskClient.new
      result = flask_client.confirm_inspection_request(request_id, confirmed_date, session[:jwt_token])
      
      result.to_json
      
    rescue => e
      AppLogger.debug("검사신청 확정 API 오류: #{e.message}")
      { success: false, message: '검사신청 확정 중 오류가 발생했습니다.' }.to_json
    end
  end
  
  put '/api/inspection-management/requests/:id/cancel' do
    content_type :json
    
    begin
      request_id = params[:id].to_i
      
      flask_client = FlaskClient.new
      result = flask_client.delete_inspection_request(request_id, session[:jwt_token])
      
      result.to_json
      
    rescue => e
      AppLogger.debug("검사신청 취소 API 오류: #{e.message}")
      { success: false, message: '검사신청 취소 중 오류가 발생했습니다.' }.to_json
    end
  end
  
  delete '/api/inspection-management/requests/:id' do
    content_type :json
    
    begin
      request_id = params[:id].to_i
      
      flask_client = FlaskClient.new
      result = flask_client.delete_inspection_request(request_id, session[:jwt_token])
      
      result.to_json
      
    rescue => e
      AppLogger.debug("검사신청 삭제 API 오류: #{e.message}")
      { success: false, message: '검사신청 삭제 중 오류가 발생했습니다.' }.to_json
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
      
      # Flask API에서 저장된 리스트 조회
      flask_client = FlaskClient.new
      list_result = flask_client.get_saved_list(session[:jwt_token])
      
      if !list_result[:success]
        return { success: false, error: '저장된 리스트를 조회할 수 없습니다.' }.to_json
      end
      
      saved_list = list_result[:items] || []
      AppLogger.debug("Flask API 저장된 리스트: #{saved_list.length}개")
      AppLogger.debug("요청된 조립품 코드: #{assembly_codes.inspect}")
      
      selected_items = saved_list.select { |item| 
        item_code = item['assembly_code']
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
          
          # Flask API를 통해 성공한 항목들 삭제
          if successful_codes.length > 0
            successful_codes.each do |code|
              delete_result = flask_client.delete_saved_item(code, session[:jwt_token])
              if delete_result[:success]
                AppLogger.debug("저장된 리스트에서 #{code} 제거 완료")
              else
                AppLogger.debug("저장된 리스트에서 #{code} 제거 실패: #{delete_result[:error]}")
              end
            end
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
  
  # 검사신청 승인/거부/확정/삭제 API - Flask에서 직접 처리하므로 제거

  # 검사신청 관리용 통합 API (새 경로)
  post '/api/inspection-management/requests' do
    content_type :json
    
    begin
      request_body = JSON.parse(request.body.read)
      
      # 요청 데이터 구조로 조회/생성 구분
      if request_body.key?('tab') && request_body.key?('page')
        # 조회 요청: tab, page 파라미터가 있으면 데이터 조회
        tab = request_body['tab']
        page = request_body['page'] || 1
        per_page = request_body['per_page'] || 20
        search_term = request_body['search'] || ''
        
        AppLogger.debug("검사신청 관리 조회 요청: tab=#{tab}, page=#{page}, search=#{search_term}")
        
        # Flask API에서 전체 데이터 조회
        user_info = session[:user_info] || {}
        user_level = user_info['permission_level'] || 1
        username = user_info['username']
        
        flask_client = FlaskClient.new
        result = flask_client.get_inspection_management_requests(session[:jwt_token])
        
        if result[:success]
          all_requests = result[:data]['requests'] || []
          
          # 탭별 필터링
          filtered_requests = case tab
          when 'active'
            # 기본 탭: 대기중, 승인됨 상태
            all_requests.select { |req| ['대기중', '승인됨'].include?(req['status']) }
          when 'completed'
            # 완료 탭: 확정됨, 거부됨 상태
            all_requests.select { |req| ['확정됨', '거부됨'].include?(req['status']) }
          else
            all_requests
          end
          
          # 검색 필터링 (완료 탭에서만)
          if tab == 'completed' && !search_term.empty?
            filtered_requests = filtered_requests.select do |req|
              req['assembly_code']&.downcase&.include?(search_term.downcase)
            end
          end
          
          # 페이지네이션 (완료 탭에서만)
          total_count = filtered_requests.length
          if tab == 'completed'
            start_index = (page - 1) * per_page
            end_index = start_index + per_page - 1
            paginated_requests = filtered_requests[start_index..end_index] || []
            
            pagination_info = {
              current_page: page,
              per_page: per_page,
              total_count: total_count,
              total_pages: (total_count.to_f / per_page).ceil
            }
          else
            paginated_requests = filtered_requests
            pagination_info = nil
          end
          
          # 응답 구조 생성
          response_data = {
            success: true,
            data: {
              requests: paginated_requests,
              user_level: result[:data]['user_level'],
              pagination: pagination_info
            }
          }
          
          AppLogger.debug("탭별 필터링 결과: tab=#{tab}, 전체=#{all_requests.length}, 필터링=#{filtered_requests.length}, 페이지=#{paginated_requests.length}")
          response_data.to_json
        else
          { success: false, error: result[:error] }.to_json
        end
        
      elsif request_body.key?('assembly_codes') && request_body.key?('inspection_type')
        # 생성 요청: assembly_codes, inspection_type이 있으면 검사신청 생성
        AppLogger.debug("검사신청 생성 요청: #{request_body}")
        
        # 기존 생성 API로 리다이렉트
        call env.merge("PATH_INFO" => "/api/create-inspection-request")
        
      else
        # 알 수 없는 요청 구조
        AppLogger.debug("알 수 없는 요청 구조: #{request_body}")
        { success: false, error: '잘못된 요청 형식입니다.' }.to_json
      end
      
    rescue JSON::ParserError
      { success: false, error: '잘못된 JSON 형식입니다.' }.to_json
    rescue => e
      AppLogger.debug("검사신청 관리 API 오류: #{e.message}")
      { success: false, error: '요청 처리 중 오류가 발생했습니다.' }.to_json
    end
  end
  
  private
  
  def current_user
    session[:user_info]
  end
end