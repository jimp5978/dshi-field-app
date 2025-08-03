#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# 설정 및 라이브러리 로드
require_relative 'config/settings'
require_relative 'lib/logger'
require_relative 'lib/process_manager'
require_relative 'lib/flask_client'

# 컨트롤러 로드
require_relative 'controllers/auth_controller'
require_relative 'controllers/search_controller'
require_relative 'controllers/inspection_controller'

class App < Sinatra::Base
  # 기본 설정
  set :port, 5008
  set :bind, '0.0.0.0'
  set :environment, :development
  enable :sessions
  set :session_secret, SESSION_SECRET
  
  # 정적 파일 및 뷰 설정
  set :public_folder, File.dirname(__FILE__) + '/public'
  set :views, File.dirname(__FILE__) + '/views'
  
  # 컨트롤러 등록
  use AuthController
  use InspectionController
  use SearchController
  
  # 정적 파일은 public 폴더에서 자동으로 서빙됩니다
  
  # 검사신청 관리 페이지 (모든 Level 접근 가능)
  get '/inspection-management' do
    # 권한 확인 (Level 1+ 모두 접근 가능)
    user_info = session[:user_info]
    if user_info.nil? || user_info['permission_level'].to_i < 1
      redirect '/login'
    end
    
    @user_info = session[:user_info] || {}
    erb :inspection_management, layout: false
  end
  
  # 기존 /admin 라우트 호환성 유지 (리디렉션)
  get '/admin' do
    redirect '/inspection-management'
  end
  
  # 헬스체크 엔드포인트
  get '/health' do
    content_type :json
    { 
      status: 'ok', 
      timestamp: Time.now,
      version: 'refactored-v1.0'
    }.to_json
  end
  
  # 코드 업데이트 테스트 엔드포인트 (인증 불필요)
  get '/test-update' do
    content_type :json
    { 
      message: '🎉 새로운 코드가 실행되고 있습니다!',
      timestamp: Time.now.strftime('%Y-%m-%d %H:%M:%S'),
      version: 'updated-v2.0',
      server_restart_time: '12:11:13'
    }.to_json
  end
  
  # 404 에러 핸들링
  not_found do
    if request.path.start_with?('/api/')
      content_type :json
      { error: 'API 엔드포인트를 찾을 수 없습니다.' }.to_json
    else
      erb :not_found, layout: :layout
    end
  end
  
  # 500 에러 핸들링
  error do
    AppLogger.debug("서버 오류: #{env['sinatra.error'].message}")
    
    if request.path.start_with?('/api/')
      content_type :json
      { error: '서버 내부 오류가 발생했습니다.' }.to_json
    else
      erb :error, layout: :layout
    end
  end
end

# 서버 시작 메시지
if __FILE__ == $0
  puts "🏭 DSHI Dashboard Starting (Refactored Version)"
  puts "📍 URL: http://localhost:5008"
  puts "🔗 Flask API: #{FLASK_API_URL}"
  puts "🎯 Architecture: Modular MVC Structure"
  puts "📁 Files: #{Dir['**/*.rb'].length} Ruby files, #{Dir['views/*.erb'].length} templates"
  
  App.run!
end