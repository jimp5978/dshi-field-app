# -*- coding: utf-8 -*-

require 'sinatra/base'
require 'json'
require_relative '../config/settings'
require_relative '../lib/logger'
require_relative '../lib/flask_client'

class SearchController < Sinatra::Base
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
  
  # 메인 검색 페이지 (루트)
  get '/' do
    @user_info = session[:user_info] || {}
    @flask_api_url = FLASK_API_URL
    erb :search, layout: false  # 원본 HTML 구조를 유지하기 위해 layout 비활성화
  end

  # 검색 페이지
  get '/search' do
    @user_info = session[:user_info] || {}
    @flask_api_url = FLASK_API_URL
    erb :search, layout: false  # 원본 HTML 구조를 유지하기 위해 layout 비활성화
  end
  
  # 조립품 검색 API
  post '/api/search' do
    content_type :json
    
    begin
      request_body = JSON.parse(request.body.read)
      query = request_body['query']
      
      if query.nil? || query.strip.empty?
        return { success: false, error: '검색어를 입력해주세요.' }.to_json
      end
      
      unless query.match?(/^\d{1,3}$/)
        return { success: false, error: '1-3자리 숫자만 입력해주세요.' }.to_json
      end
      
      flask_client = FlaskClient.new
      result = flask_client.search_assemblies(query, session[:jwt_token])
      
      if result[:success]
        { success: true, data: result[:data] }.to_json
      else
        { success: false, error: result[:error] }.to_json
      end
      
    rescue JSON::ParserError
      { success: false, error: '잘못된 요청 형식입니다.' }.to_json
    rescue => e
      AppLogger.debug("검색 API 오류: #{e.message}")
      { success: false, error: '검색 중 오류가 발생했습니다.' }.to_json
    end
  end
  
  # 저장 리스트에 항목 추가 API
  post '/api/save-list' do
    content_type :json
    
    begin
      request_body = JSON.parse(request.body.read)
      items = request_body['items']
      
      if items.nil? || !items.is_a?(Array) || items.empty?
        return { success: false, error: '저장할 항목이 없습니다.' }.to_json
      end
      
      AppLogger.debug("저장 리스트 API 호출")
      AppLogger.debug("저장할 항목 수: #{items.length}")
      AppLogger.debug("받은 항목들: #{items.map { |item| item['assembly_code'] }.join(', ')}")
      
      # Flask API를 통해 사용자별 저장
      flask_client = FlaskClient.new
      result = flask_client.save_assembly_list(items, session[:jwt_token])
      
      if result[:success]
        AppLogger.debug("Flask API 저장 성공: #{result[:message]}")
        { success: true, message: result[:message], total: result[:total] }.to_json
      else
        AppLogger.debug("Flask API 저장 실패: #{result[:error]}")
        { success: false, error: result[:error] }.to_json
      end
      
    rescue JSON::ParserError
      { success: false, error: '잘못된 요청 형식입니다.' }.to_json
    rescue => e
      AppLogger.debug("저장 리스트 API 오류: #{e.message}")
      { success: false, error: '저장 중 오류가 발생했습니다.' }.to_json
    end
  end
  
  # 저장된 리스트 전체 삭제 API
  get '/api/clear-saved-list' do
    content_type :json
    
    begin
      # Flask API를 통해 사용자별 전체 삭제
      flask_client = FlaskClient.new
      result = flask_client.clear_saved_list(session[:jwt_token])
      
      if result[:success]
        AppLogger.debug("Flask API 전체 삭제 성공: #{result[:message]}")
        { success: true, message: result[:message] }.to_json
      else
        AppLogger.debug("Flask API 전체 삭제 실패: #{result[:error]}")
        { success: false, error: result[:error] }.to_json
      end
      
    rescue => e
      AppLogger.debug("저장된 리스트 전체 삭제 오류: #{e.message}")
      { success: false, error: '삭제 중 오류가 발생했습니다.' }.to_json
    end
  end
  
  # 저장된 리스트에서 선택 항목 삭제 API
  post '/api/remove-from-saved-list' do
    content_type :json
    
    begin
      request_body = JSON.parse(request.body.read)
      items_to_remove = request_body['items']
      
      if items_to_remove.nil? || !items_to_remove.is_a?(Array) || items_to_remove.empty?
        return { success: false, error: '삭제할 항목을 선택해주세요.' }.to_json
      end
      
      AppLogger.debug("삭제할 항목들: #{items_to_remove}")
      
      # Flask API를 통해 각 항목 삭제
      flask_client = FlaskClient.new
      deleted_count = 0
      
      items_to_remove.each do |assembly_code|
        result = flask_client.delete_saved_item(assembly_code, session[:jwt_token])
        if result[:success]
          deleted_count += 1
          AppLogger.debug("항목 삭제 성공: #{assembly_code}")
        else
          AppLogger.debug("항목 삭제 실패: #{assembly_code} - #{result[:error]}")
        end
      end
      
      { success: true, message: "#{deleted_count}개 항목이 삭제되었습니다." }.to_json
      
    rescue JSON::ParserError
      { success: false, error: '잘못된 요청 형식입니다.' }.to_json
    rescue => e
      AppLogger.debug("항목 삭제 API 오류: #{e.message}")
      { success: false, error: '삭제 중 오류가 발생했습니다.' }.to_json
    end
  end
  
  # 현재 시간 테스트 API (코드 업데이트 확인용)
  get '/api/test-time' do
    content_type :json
    { 
      current_time: Time.now.strftime('%Y-%m-%d %H:%M:%S'),
      message: '새로운 코드가 실행되고 있습니다!',
      version: 'updated-v2.0'
    }.to_json
  end
  
  # 테스트용 데이터 추가 API (임시)
  post '/api/test-add-saved-items' do
    content_type :json
    
    begin
      request_body = JSON.parse(request.body.read)
      items = request_body['items']
      
      session[:saved_list] = items
      AppLogger.debug("테스트 데이터 추가: #{items.length}개 항목")
      
      { success: true, message: "#{items.length}개 테스트 항목이 추가되었습니다." }.to_json
      
    rescue JSON::ParserError
      { success: false, error: '잘못된 요청 형식입니다.' }.to_json
    rescue => e
      AppLogger.debug("테스트 데이터 추가 오류: #{e.message}")
      { success: false, error: '테스트 데이터 추가 중 오류가 발생했습니다.' }.to_json
    end
  end
  
  # 관리자 패널 페이지
  get '/admin' do
    # 권한 확인
    user_info = session[:user_info]
    if user_info.nil? || user_info['permission_level'].to_i < 2
      redirect '/'
    end
    
    @user_info = session[:user_info] || {}
    erb :admin_panel, layout: false
  end
  
  private
  
  def current_user
    session[:user_info]
  end
end