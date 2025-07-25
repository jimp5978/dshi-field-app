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
      AppLogger.debug("받은 항목들: #{items.map { |item| item['name'] || item['assembly'] }.join(', ')}")
      
      # 세션에 저장된 리스트가 없으면 빈 배열로 초기화
      session[:saved_list] ||= []
      AppLogger.debug("기존 저장된 항목 수: #{session[:saved_list].length}")
      AppLogger.debug("기존 저장된 항목들: #{session[:saved_list].map { |item| item['name'] || item['assembly'] }.join(', ')}")
      
      # 중복 제거하면서 새 항목들 추가
      added_count = 0
      items.each do |item|
        # 이미 존재하는지 확인 (name 또는 assembly 코드로 비교)
        item_code = item['name'] || item['assembly']
        AppLogger.debug("처리 중인 항목: #{item_code}")
        
        duplicate_found = session[:saved_list].any? { |saved_item| 
          saved_code = saved_item['name'] || saved_item['assembly']
          AppLogger.debug("비교: #{item_code} vs #{saved_code} = #{saved_code == item_code}")
          saved_code == item_code
        }
        
        unless duplicate_found
          session[:saved_list] << item
          added_count += 1
          AppLogger.debug("항목 추가 성공: #{item_code} (총 #{session[:saved_list].length}개)")
        else
          AppLogger.debug("중복으로 인한 제외: #{item_code}")
        end
      end
      
      AppLogger.debug("추가된 항목 수: #{added_count}")
      
      AppLogger.debug("총 저장된 항목 수: #{session[:saved_list].length}")
      
      { success: true, message: "#{items.length}개 항목이 저장되었습니다.", total: session[:saved_list].length }.to_json
      
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
    
    session[:saved_list] = []
    AppLogger.debug("저장된 리스트 전체 삭제")
    
    { success: true, message: '저장된 리스트가 모두 삭제되었습니다.' }.to_json
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
      
      session[:saved_list] ||= []
      original_count = session[:saved_list].length
      
      # 선택된 항목들 제거 (name 필드로 비교하도록 수정)
      session[:saved_list].reject! { |item| items_to_remove.include?(item['name'] || item['assembly']) }
      
      removed_count = original_count - session[:saved_list].length
      AppLogger.debug("#{removed_count}개 항목 삭제, 남은 항목: #{session[:saved_list].length}개")
      
      { success: true, message: "#{removed_count}개 항목이 삭제되었습니다.", remaining: session[:saved_list].length }.to_json
      
    rescue JSON::ParserError
      { success: false, error: '잘못된 요청 형식입니다.' }.to_json
    rescue => e
      AppLogger.debug("항목 삭제 API 오류: #{e.message}")
      { success: false, error: '삭제 중 오류가 발생했습니다.' }.to_json
    end
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