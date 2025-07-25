# -*- coding: utf-8 -*-

require 'sinatra/base'
require 'json'
require_relative '../config/settings'
require_relative '../lib/logger'
require_relative '../lib/flask_client'

class AdminController < Sinatra::Base
  enable :sessions
  set :session_secret, SESSION_SECRET
  
  # 뷰 및 정적 파일 설정
  set :views, File.dirname(__FILE__) + '/../views'
  set :public_folder, File.dirname(__FILE__) + '/../public'
  
  # 인증 확인 헬퍼
  before do
    puts "AdminController before 필터 - 경로: #{request.path}"
    puts "JWT 토큰: #{session[:jwt_token] ? '있음' : '없음'}"
    puts "사용자 정보: #{session[:user_info]}"
    
    unless session[:jwt_token]
      puts "JWT 토큰이 없어서 로그인 페이지로 리다이렉트"
      halt 401, { error: '로그인이 필요합니다.' }.to_json if request.path.start_with?('/api/')
      redirect '/login' unless request.path.start_with?('/api/')
    end
    
    # 관리자 권한 확인 (Level 2+)
    user_info = session[:user_info]
    if user_info.nil? || user_info['permission_level'].to_i < 2
      puts "권한 부족 - Level #{user_info ? user_info['permission_level'] : 'nil'}"
      halt 403, { error: '관리자 권한이 필요합니다.' }.to_json if request.path.start_with?('/api/')
      redirect '/' unless request.path.start_with?('/api/')
    end
    
    puts "AdminController before 필터 통과"
  end
  
  # 테스트 라우트
  get '/admin-test' do
    "AdminController가 정상 동작합니다!"
  end
  
  # 관리자 패널 페이지
  get '/admin' do
    puts "관리자 패널 라우트 호출됨"
    @user_info = session[:user_info] || {}
    puts "사용자 정보: #{@user_info}"
    erb :admin_panel, layout: false
  end
  
  # 검사신청 승인 API
  put '/api/inspection-requests/:id/approve' do
    content_type :json
    
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
  
  # 검사신청 거부 API
  put '/api/inspection-requests/:id/reject' do
    content_type :json
    
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
  
  # 검사신청 확정 API
  put '/api/inspection-requests/:id/confirm' do
    content_type :json
    
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
      
      # 권한 확인 (Level 3+ 필요)
      user_info = session[:user_info]
      if user_info.nil? || user_info['permission_level'].to_i < 3
        return { success: false, error: '확정 권한이 없습니다 (Level 3+ 필요).' }.to_json
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
  
  private
  
  def current_user
    session[:user_info]
  end
end