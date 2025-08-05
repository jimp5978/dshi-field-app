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
      '/api/upload-excel',
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
      
      # 필터 파라미터 추가
      status_filter = params[:status_filter] || ''
      type_filter = params[:type_filter] || ''
      date_from = params[:date_from] || ''
      date_to = params[:date_to] || ''
      
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
        
        # 추가 필터 적용
        unless status_filter.empty?
          filtered_requests = filtered_requests.select { |req| req['status'] == status_filter }
        end
        
        unless type_filter.empty?
          filtered_requests = filtered_requests.select { |req| req['inspection_type'] == type_filter }
        end
        
        # 날짜 범위 필터 적용
        unless date_from.empty?
          begin
            from_date = Date.parse(date_from)
            filtered_requests = filtered_requests.select do |req|
              req_date = Date.parse(req['request_date']) rescue nil
              req_date && req_date >= from_date
            end
          rescue => e
            AppLogger.debug("날짜 from 파싱 오류: #{e.message}")
          end
        end
        
        unless date_to.empty?
          begin
            to_date = Date.parse(date_to)
            filtered_requests = filtered_requests.select do |req|
              req_date = Date.parse(req['request_date']) rescue nil
              req_date && req_date <= to_date
            end
          rescue => e
            AppLogger.debug("날짜 to 파싱 오류: #{e.message}")
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
        
        # 동적 필터 옵션 생성 - 현재 탭에 해당하는 데이터만 사용
        tab_requests = case tab
        when 'active'
          all_requests.select { |req| ['대기중', '승인됨'].include?(req['status']) }
        when 'completed'
          all_requests.select { |req| ['확정됨', '거부됨'].include?(req['status']) }
        else
          all_requests
        end
        
        available_statuses = tab_requests.map { |req| req['status'] }.compact.uniq.sort
        available_types = tab_requests.map { |req| req['inspection_type'] }.compact.uniq.sort
        
        # 응답 구조 생성
        response_data = {
          success: true,
          data: {
            requests: paginated_requests,
            user_level: result[:data]['user_level'],
            pagination: pagination_info,
            filter_options: {
              statuses: available_statuses,
              types: available_types
            }
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
          
          # Flask API를 통해 성공한 항목들 청크 단위 병렬 삭제 (5개씩)
          if successful_codes.length > 0
            chunk_size = 5
            total_chunks = (successful_codes.length.to_f / chunk_size).ceil
            deleted_count = 0
            failed_count = 0
            
            AppLogger.debug("검사신청 후 자동삭제 시작: #{successful_codes.length}개 항목을 #{total_chunks}개 그룹으로 처리")
            
            successful_codes.each_slice(chunk_size).with_index do |chunk, chunk_index|
              AppLogger.debug("자동삭제 청크 #{chunk_index + 1}/#{total_chunks} 처리 중 (#{chunk.length}개 항목)")
              
              # 각 청크를 Thread로 병렬 처리
              threads = chunk.map do |code|
                Thread.new do
                  begin
                    delete_result = flask_client.delete_saved_item(code, session[:jwt_token])
                    if delete_result[:success]
                      AppLogger.debug("저장된 리스트에서 #{code} 제거 완료")
                      { success: true, code: code }
                    else
                      AppLogger.debug("저장된 리스트에서 #{code} 제거 실패: #{delete_result[:error]}")
                      { success: false, code: code, error: delete_result[:error] }
                    end
                  rescue => e
                    AppLogger.debug("저장된 리스트에서 #{code} 제거 오류: #{e.message}")
                    { success: false, code: code, error: e.message }
                  end
                end
              end
              
              # 모든 Thread 완료 대기 및 결과 수집
              chunk_results = threads.map(&:value)
              
              # 결과 집계
              chunk_results.each do |result|
                if result[:success]
                  deleted_count += 1
                else
                  failed_count += 1
                end
              end
              
              # 청크 간 짧은 대기 (서버 부하 방지)
              sleep(0.1) if chunk_index < total_chunks - 1
            end
            
            AppLogger.debug("자동삭제 완료: 성공 #{deleted_count}개, 실패 #{failed_count}개")
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
        
        # 필터 파라미터 추가 (POST 방식)
        status_filter = request_body['status_filter'] || ''
        type_filter = request_body['type_filter'] || ''
        date_from = request_body['date_from'] || ''
        date_to = request_body['date_to'] || ''
        
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
          
          # 추가 필터 적용 (POST 방식에서도 동일한 로직)
          unless status_filter.empty?
            filtered_requests = filtered_requests.select { |req| req['status'] == status_filter }
          end
          
          unless type_filter.empty?
            filtered_requests = filtered_requests.select { |req| req['inspection_type'] == type_filter }
          end
          
          # 날짜 범위 필터 적용
          unless date_from.empty?
            begin
              from_date = Date.parse(date_from)
              filtered_requests = filtered_requests.select do |req|
                req_date = Date.parse(req['request_date']) rescue nil
                req_date && req_date >= from_date
              end
            rescue => e
              AppLogger.debug("날짜 from 파싱 오류 (POST): #{e.message}")
            end
          end
          
          unless date_to.empty?
            begin
              to_date = Date.parse(date_to)
              filtered_requests = filtered_requests.select do |req|
                req_date = Date.parse(req['request_date']) rescue nil
                req_date && req_date <= to_date
              end
            rescue => e
              AppLogger.debug("날짜 to 파싱 오류 (POST): #{e.message}")
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
          
          # 동적 필터 옵션 생성 (POST 방식에서도) - 현재 탭에 해당하는 데이터만 사용
          tab_requests = case tab
          when 'active'
            all_requests.select { |req| ['대기중', '승인됨'].include?(req['status']) }
          when 'completed'
            all_requests.select { |req| ['확정됨', '거부됨'].include?(req['status']) }
          else
            all_requests
          end
          
          available_statuses = tab_requests.map { |req| req['status'] }.compact.uniq.sort
          available_types = tab_requests.map { |req| req['inspection_type'] }.compact.uniq.sort
          
          # 응답 구조 생성
          response_data = {
            success: true,
            data: {
              requests: paginated_requests,
              user_level: result[:data]['user_level'],
              pagination: pagination_info,
              filter_options: {
                statuses: available_statuses,
                types: available_types
              }
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
  
  # Excel 파일 업로드 API (완전히 새로운 방식)
  post '/api/upload-excel' do
    content_type :json
    
    begin
      AppLogger.debug("=== 2025-08-04 11:26 NEW VERSION Excel 업로드 요청 수신 ===")
      
      # 파일 업로드 확인
      unless params[:excel_file] && params[:excel_file][:tempfile]
        AppLogger.debug("Excel 파일이 업로드되지 않음")
        return { success: false, error: 'Excel 파일이 업로드되지 않았습니다.' }.to_json
      end
      
      uploaded_file = params[:excel_file]
      filename = uploaded_file[:filename]
      
      # 파일명 인코딩 안전 처리
      safe_filename = filename.dup
      safe_filename.force_encoding('UTF-8') if safe_filename.respond_to?(:force_encoding)
      safe_filename = safe_filename.encode('UTF-8', :invalid => :replace, :undef => :replace)
      
      AppLogger.debug("Excel 파일 업로드 요청: #{safe_filename}")
      
      # 파일 확장자 확인 (안전한 파일명 사용)
      allowed_extensions = ['xlsx', 'xls']
      file_extension = safe_filename.split('.').last&.downcase
      
      unless allowed_extensions.include?(file_extension)
        AppLogger.debug("지원하지 않는 파일 형식: #{file_extension}")
        return { success: false, error: 'Excel 파일(.xlsx, .xls)만 업로드 가능합니다.' }.to_json
      end
      
      # 업로드된 파일을 직접 사용 (임시 저장 방식 변경)
      begin
        # 업로드된 tempfile을 직접 사용
        temp_file_path = uploaded_file[:tempfile].path
        
        # 파일이 존재하지 않으면 다른 방법 시도
        unless File.exist?(temp_file_path)
          temp_file_path = File.join(Dir.tmpdir, "excel_upload_#{Process.pid}_#{Time.now.to_i}.#{file_extension}")
          
          # IO 복사를 사용해서 인코딩 문제 방지
          uploaded_file[:tempfile].rewind
          File.open(temp_file_path, 'wb') do |output_file|
            IO.copy_stream(uploaded_file[:tempfile], output_file)
          end
          uploaded_file[:tempfile].rewind
        end
      rescue => e
        AppLogger.debug("파일 처리 오류: #{e.message}")
        return { success: false, error: '파일 처리 중 오류가 발생했습니다.' }.to_json
      end
      
      AppLogger.debug("임시 파일 저장: #{temp_file_path}")
      
      # Python 스크립트로 Excel 파싱
      python_script = File.expand_path('../../../parse_excel.py', __FILE__)
      command = "python \"#{python_script}\" \"#{temp_file_path}\""
      
      AppLogger.debug("Python 파싱 명령: #{command}")
      AppLogger.debug("Python 스크립트 경로: #{python_script}")
      AppLogger.debug("Python 스크립트 존재 여부: #{File.exist?(python_script)}")
      AppLogger.debug("임시 파일 경로: #{temp_file_path}")
      AppLogger.debug("임시 파일 존재 여부: #{File.exist?(temp_file_path)}")
      
      result_json = `#{command} 2>&1`  # stderr도 캡처
      exit_status = $?.exitstatus
      
      AppLogger.debug("Python 스크립트 종료 코드: #{exit_status}")
      AppLogger.debug("Python 스크립트 출력: #{result_json}")
      
      # 임시 파일 삭제 (안전하게 처리)
      begin
        File.delete(temp_file_path) if File.exist?(temp_file_path)
        AppLogger.debug("임시 파일 삭제 완료: #{temp_file_path}")
      rescue => e
        AppLogger.debug("임시 파일 삭제 실패 (무시함): #{e.message}")
        # 임시 파일 삭제 실패는 치명적이지 않으므로 무시
      end
      
      if exit_status == 0
        begin
          parsed_data = JSON.parse(result_json)
          AppLogger.debug("Excel 파싱 성공: #{parsed_data}")
          
          if parsed_data['success']
            assembly_codes = parsed_data['assembly_codes']
            
            # Flask API로 Assembly Code 목록 전송
            flask_client = FlaskClient.new
            result = flask_client.upload_assembly_codes(assembly_codes, session[:jwt_token])
            
            if result[:success]
              AppLogger.debug("Flask 업로드 성공: #{result[:message]}")
              { 
                success: true, 
                message: result[:message],
                data: result[:data]
              }.to_json
            else
              AppLogger.debug("Flask 업로드 실패: #{result[:error]}")
              { success: false, error: result[:error] }.to_json
            end
          else
            { success: false, error: parsed_data['error'] }.to_json
          end
        rescue JSON::ParserError => e
          AppLogger.debug("JSON 파싱 오류: #{e.message}")
          { success: false, error: 'Excel 파싱 결과 처리 중 오류가 발생했습니다.' }.to_json
        end
      else
        AppLogger.debug("Python 스크립트 실행 실패: #{result_json}")
        { success: false, error: 'Excel 파일 파싱 중 오류가 발생했습니다.' }.to_json
      end
      
    rescue => e
      AppLogger.debug("Excel 업로드 API 오류: #{e.message}")
      AppLogger.debug("백트레이스: #{e.backtrace.first(3).join('\n')}")
      { success: false, error: 'Excel 업로드 중 오류가 발생했습니다.' }.to_json
    end
  end
  
  private
  
  def current_user
    session[:user_info]
  end
end