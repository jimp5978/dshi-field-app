#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'bundler/setup'
require 'sinatra'
require 'webrick'
require 'jwt'
require 'net/http'
require 'json'
require 'uri'
require 'digest'

# Sinatra 설정
enable :sessions
set :session_secret, 'your-super-secret-session-key-change-this-in-production-must-be-at-least-64-characters-long-for-security'
set :port, 5005
set :bind, '0.0.0.0'

# Flask API 서버 URL (운영 서버)
FLASK_API_URL = 'http://203.251.108.199:5001'

# SHA256 해시 함수
def sha256_hash(password)
  Digest::SHA256.hexdigest(password)
end

# 실제 Flask API 로그인 함수
def flask_login(username, password)
  # 평문 패스워드를 SHA256으로 해시
  password_hash = sha256_hash(password)
  
  puts "로그인 시도:"
  puts "- 사용자명: #{username}"
  puts "- 평문 패스워드: #{password}"
  puts "- SHA256 해시: #{password_hash}"
  
  begin
    uri = URI("#{FLASK_API_URL}/api/login")
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 10
    http.read_timeout = 10
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = {
      username: username,
      password_hash: password_hash  # 해시된 패스워드 전송
    }.to_json
    
    puts "API 요청 데이터: #{request.body}"
    
    response = http.request(request)
    puts "API 응답: #{response.code} - #{response.body}"
    
    if response.code == '200'
      data = JSON.parse(response.body)
      if data['success']
        {
          success: true,
          token: data['token'],
          user: data['user']
        }
      else
        {
          success: false,
          error: data['message'] || '로그인 실패'
        }
      end
    else
      # HTTP 에러 상태 코드별 사용자 친화적 메시지 처리
      error_message = case response.code
                     when '401'
                       '아이디 또는 비밀번호를 확인해주세요'
                     when '403'
                       '접근 권한이 없습니다'
                     when '404'
                       '서버를 찾을 수 없습니다'
                     when '500'
                       '서버 오류가 발생했습니다'
                     when '503'
                       '서버가 일시적으로 사용할 수 없습니다'
                     else
                       '로그인 중 오류가 발생했습니다'
                     end
      
      # JSON 응답에서 더 구체적인 에러 메시지가 있는지 확인
      begin
        if response.body && !response.body.empty?
          data = JSON.parse(response.body)
          if data['message'] && !data['message'].empty?
            error_message = data['message']
          end
        end
      rescue JSON::ParserError
        # JSON 파싱 실패 시 기본 메시지 사용
      end
      
      {
        success: false,
        error: error_message
      }
    end
  rescue => e
    puts "로그인 API 연결 실패: #{e.message}"
    {
      success: false,
      error: "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요."
    }
  end
end

# 라우트
get '/login' do
  erb :production_login
end

get '/' do
  if session[:logged_in]
    user = session[:user_info] || {}
    erb :dashboard, locals: { user: user }
  else
    redirect '/login'
  end
end

post '/login' do
  username = params[:username]
  password = params[:password]
  
  puts "\n=== 로그인 요청 ==="
  puts "사용자명: #{username}"
  puts "패스워드: #{password}"
  
  # 실제 Flask API로 로그인 요청
  result = flask_login(username, password)
  
  if result[:success]
    session[:logged_in] = true
    session[:jwt_token] = result[:token]
    session[:user_info] = result[:user]
    redirect '/'
  else
    @error = result[:error]
    @username = username  # 실패 시 사용자명 유지
    erb :production_login
  end
end

get '/logout' do
  session.clear
  redirect '/login'
end

# API 서버 상태 확인
get '/api/status' do
  begin
    uri = URI("#{FLASK_API_URL}/health")
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 5
    http.read_timeout = 5
    
    response = http.request(Net::HTTP::Get.new(uri))
    
    content_type :json
    {
      flask_api_status: response.code == '200' ? 'online' : 'error',
      response_code: response.code,
      response_body: response.body,
      flask_url: FLASK_API_URL
    }.to_json
  rescue => e
    content_type :json
    {
      flask_api_status: 'offline',
      error: e.message,
      flask_url: FLASK_API_URL
    }.to_json
  end
end

# 패스워드 해시 테스트 도구
get '/hash-test' do
  test_passwords = {
    'hello' => sha256_hash('hello'),
    'password123' => sha256_hash('password123'),
    'admin' => sha256_hash('admin')
  }
  
  content_type :json
  test_passwords.to_json
end

# HTML 템플릿
__END__

@@production_login
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ARUP ECS - Production 로그인</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .login-container {
            background: white;
            border-radius: 10px;
            box-shadow: 0 15px 35px rgba(0, 0, 0, 0.1);
            padding: 40px;
            width: 100%;
            max-width: 450px;
        }
        
        .logo {
            text-align: center;
            margin-bottom: 30px;
        }
        
        .logo h1 {
            color: #333;
            font-size: 28px;
            margin-bottom: 10px;
        }
        
        .logo p {
            color: #666;
            font-size: 14px;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        .form-group label {
            display: block;
            margin-bottom: 5px;
            color: #333;
            font-weight: 500;
        }
        
        .form-group input {
            width: 100%;
            padding: 12px 15px;
            border: 2px solid #e1e5e9;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        
        .form-group input:focus {
            outline: none;
            border-color: #667eea;
        }
        
        .btn-login {
            width: 100%;
            padding: 12px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s;
        }
        
        .btn-login:hover {
            transform: translateY(-2px);
        }
        
        .error-message {
            background: #ffe6e6;
            border: 1px solid #ffb3b3;
            color: #d32f2f;
            padding: 10px 15px;
            border-radius: 8px;
            margin-bottom: 20px;
            text-align: center;
            font-size: 14px;
        }
        
        
        
        
        .footer {
            text-align: center;
            margin-top: 20px;
            color: #999;
            font-size: 12px;
        }
        
        .footer a {
            color: #667eea;
            text-decoration: none;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="logo">
            <h1>🏭 DSHI</h1>
            <p>DSHI 로그인 시스템</p>
        </div>




        <% if @error %>
            <div class="error-message">
                <%= @error %>
            </div>
        <% end %>

        <form method="post" action="/login">
            <div class="form-group">
                <label for="username">ID</label>
                <input type="text" id="username" name="username" value="<%= @username %>" required placeholder="ID 입력">
            </div>

            <div class="form-group">
                <label for="password">비밀번호</label>
                <input type="password" id="password" name="password" required placeholder="비밀번호 입력">
            </div>

            <button type="submit" class="btn-login">로그인</button>
        </form>

        <div class="footer">
            <p>&copy; 2025 DSHI RPA System</p>
        </div>
    </div>

    <script>

        // 폼 제출 시 로딩 상태
        document.querySelector('form').addEventListener('submit', function() {
            const submitBtn = document.querySelector('.btn-login');
            submitBtn.textContent = '로그인 중...';
            submitBtn.disabled = true;
        });

        // 사용자명 필드에 포커스
        window.addEventListener('load', function() {
            const usernameField = document.getElementById('username');
            // 기본값 없이 포커스만
            usernameField.focus();
            usernameField.select();
        });
    </script>
</body>
</html>

@@dashboard
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ARUP ECS - Dashboard</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: #f5f5f5;
        }
        .header {
            background: white;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .user-info {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .user-details {
            font-size: 18px;
            color: #333;
        }
        .permission-badge {
            padding: 5px 15px;
            border-radius: 20px;
            color: white;
            font-weight: bold;
        }
        .level-1 { background: #4caf50; }
        .level-3 { background: #ff9800; }
        .level-4 { background: #2196f3; }
        .level-5 { background: #9c27b0; }
        .logout-btn {
            background: #f44336;
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            text-decoration: none;
            display: inline-block;
        }
        .welcome-message {
            background: white;
            padding: 30px;
            border-radius: 10px;
            text-align: center;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .welcome-message h1 {
            color: #333;
            margin-bottom: 20px;
        }
        .features {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-top: 30px;
        }
        .feature-card {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .feature-card h3 {
            color: #667eea;
            margin-bottom: 10px;
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="user-info">
            <div class="user-details">
                안녕하세요, <strong><%= user['full_name'] || user['username'] %></strong>님!
                <span class="permission-badge level-<%= user['permission_level'] %>">
                    Level <%= user['permission_level'] %>
                </span>
            </div>
            <a href="/logout" class="logout-btn">로그아웃</a>
        </div>
    </div>

    <div class="welcome-message">
        <h1>🎉 로그인 성공!</h1>
        <p>ARUP ECS 시스템에 성공적으로 로그인했습니다.</p>
        <p>JWT 토큰이 정상적으로 발급되었으며, 24시간 동안 유효합니다.</p>
        
        <div class="features">
            <div class="feature-card">
                <h3>🔍 조립품 검색</h3>
                <p>5,758개의 조립품 데이터를 검색하고 관리할 수 있습니다.</p>
            </div>
            
            <div class="feature-card">
                <h3>📋 검사신청</h3>
                <p>8단계 공정의 검사를 신청하고 승인 과정을 관리할 수 있습니다.</p>
            </div>
            
            <div class="feature-card">
                <h3>📊 데이터 분석</h3>
                <p>실시간 진행률과 통계를 확인할 수 있습니다.</p>
            </div>
            
            <% if user['permission_level'] >= 5 %>
            <div class="feature-card">
                <h3>👥 사용자 관리</h3>
                <p>Level 5+ 권한으로 사용자를 생성하고 관리할 수 있습니다.</p>
            </div>
            <% end %>
        </div>
    </div>
</body>
</html>