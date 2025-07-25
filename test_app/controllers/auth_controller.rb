# -*- coding: utf-8 -*-

require 'sinatra/base'
require_relative '../config/settings'
require_relative '../lib/logger'
require_relative '../lib/flask_client'

class AuthController < Sinatra::Base
  enable :sessions
  set :session_secret, SESSION_SECRET
  
  # 뷰 및 정적 파일 설정
  set :views, File.dirname(__FILE__) + '/../views'
  set :public_folder, File.dirname(__FILE__) + '/../public'
  
  # 메인 페이지 - 로그인 상태 확인
  get '/' do
    AppLogger.debug("메인 페이지 접근")
    
    if session[:jwt_token]
      AppLogger.debug("인증된 사용자: #{session[:user_info]['username']}")
      redirect '/search'
    else
      @error_msg = params[:error]
      @username = params[:username]
      erb :login, layout: :layout
    end
  end
  
  # 로그인 페이지
  get '/login' do
    AppLogger.debug("로그인 페이지 접근")
    @error_msg = params[:error]
    @username = params[:username]
    erb :login, layout: :layout
  end
  
  # 로그인 처리
  post '/login' do
    username = params[:username]
    password = params[:password]
    
    AppLogger.debug("로그인 요청: #{username}")
    
    if username.nil? || username.empty? || password.nil? || password.empty?
      redirect "/login?error=#{URI.encode_www_form_component('사용자명과 비밀번호를 입력해주세요.')}&username=#{URI.encode_www_form_component(username || '')}"
    end
    
    flask_client = FlaskClient.new
    result = flask_client.login(username, password)
    
    if result[:success]
      session[:jwt_token] = result[:token]
      session[:user_info] = result[:user]
      AppLogger.debug("로그인 성공: #{username}")
      redirect '/'
    else
      AppLogger.debug("로그인 실패: #{result[:error]}")
      redirect "/login?error=#{URI.encode_www_form_component(result[:error])}&username=#{URI.encode_www_form_component(username)}"
    end
  end
  
  # 로그아웃
  get '/logout' do
    username = session[:user_info] && session[:user_info]['username']
    AppLogger.debug("로그아웃: #{username}")
    
    session.clear
    redirect '/login'
  end
  
  # 인증 미들웨어 (다른 컨트롤러에서 사용)
  def self.require_auth
    lambda do |env|
      request = Rack::Request.new(env)
      
      unless request.session[:jwt_token]
        [302, {'Location' => '/login'}, []]
      else
        # 인증된 사용자는 다음 미들웨어로 통과
        nil # Rack에서 nil을 반환하면 다음 미들웨어로 넘어감
      end
    end
  end
  
  private
  
  # 현재 사용자 정보 반환
  def current_user
    session[:user_info]
  end
  
  # 인증 확인
  def authenticated?
    !session[:jwt_token].nil?
  end
end