#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# Bundler 환경 설정
require 'bundler/setup'

# 필요한 gem들 직접 require
require 'sinatra'
require 'webrick'
require 'jwt'

require 'net/http'
require 'json'
require 'uri'

# 헬퍼 로드
require_relative 'lib/auth_helper'
require_relative 'lib/api_client'

# Sinatra 설정
enable :sessions
set :session_secret, 'your-super-secret-session-key-change-this-in-production-must-be-at-least-64-characters-long-for-security'
set :port, 5008
set :bind, '0.0.0.0'

class DSHIDashboard
  def initialize
    @flask_api_url = "http://203.251.108.199:5001"  # Flask API 서버 URL (실제 MySQL 데이터)
  end

  def get_dashboard_data
    begin
      # Flask API 호출 시도
      uri = URI("#{@flask_api_url}/api/dashboard/stats")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 5
      http.read_timeout = 10
      
      request = Net::HTTP::Get.new(uri)
      request['Content-Type'] = 'application/json'
      
      response = http.request(request)
      
      if response.code == '200'
        JSON.parse(response.body)
      else
        puts "Flask API 응답 오류: #{response.code} - #{response.body}"
        get_mock_data
      end
    rescue => e
      puts "Flask API 연결 실패: #{e.message}"
      get_mock_data
    end
  end

  def get_mock_data
    # Python API 연결 실패시 모의 데이터 사용
    {
      "total_assemblies" => 373,
      "process_completion" => {
        "Fit-up" => 95.2,
        "NDE" => 87.4,
        "VIDI" => 79.1,
        "GALV" => 68.9,
        "SHOT" => 61.3,
        "PAINT" => 52.7,
        "PACKING" => 45.0
      },
      "status_distribution" => {
        "완료" => 168,
        "진행중" => 142,
        "대기" => 45,
        "지연" => 18
      },
      "monthly_progress" => {
        "planned" => 373,
        "completed" => 168,
        "remaining" => 205,
        "percentage" => 45.0
      },
      "issues" => [
        {
          "title" => "GALV 공정 장비 점검 필요",
          "description" => "GALV 라인 3번 장비에서 온도 불안정으로 품질 저하 위험",
          "priority" => "high",
          "time" => Time.now.strftime("%Y-%m-%d %H:%M")
        },
        {
          "title" => "SHOT 공정 자재 부족",
          "description" => "SHOT 블라스팅용 연마재 재고 부족으로 작업 지연 예상",
          "priority" => "medium",
          "time" => (Time.now - 7200).strftime("%Y-%m-%d %H:%M")
        },
        {
          "title" => "18개 조립품 공정 지연",
          "description" => "NDE 검사 대기로 인한 후속 공정 지연 발생",
          "priority" => "medium",
          "time" => (Time.now - 14400).strftime("%Y-%m-%d %H:%M")
        }
      ]
    }
  end
end

# 전역 dashboard 인스턴스
dashboard = DSHIDashboard.new

# 개발 단계에서는 인증 건너뛰기
before '/*' do
  # 개발용: 모든 페이지에 대해 인증 불필요
  pass
end

# 라우트 정의
get '/login' do
  erb :login
end

post '/login' do
  username = params[:username]
  password = params[:password]
  
  result = AuthHelper.login(username, password)
  
  if result[:success]
    session[:jwt_token] = result[:token]
    session[:user_info] = result[:user]
    redirect '/'
  else
    @error = result[:error]
    erb :login
  end
end

get '/logout' do
  AuthHelper.logout(session)
  redirect '/login'
end

get '/' do
  @user = { 'username' => 'admin', 'level' => 5 }  # 개발용 임시 사용자
  @data = dashboard.get_dashboard_data
  erb :index
end

get '/api/stats' do
  content_type :json
  dashboard.get_dashboard_data.to_json
end

get '/health' do
  content_type :json
  { status: 'ok', timestamp: Time.now.to_i }.to_json
end