#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'bundler/setup'
require 'sinatra'
require 'webrick'
require 'jwt'
require 'net/http'
require 'json'
require 'uri'

# Sinatra 설정
enable :sessions
set :session_secret, 'your-super-secret-session-key-change-this-in-production-must-be-at-least-64-characters-long-for-security'
set :port, 5004
set :bind, '0.0.0.0'

# Flask API 서버 URL
FLASK_API_URL = 'http://203.251.108.199:5001'

# 실제 Flask API 로그인 함수
def flask_login(username, password)
  begin
    uri = URI("#{FLASK_API_URL}/api/login")
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 10
    http.read_timeout = 10
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = {
      username: username,
      password_hash: password  # Flask API에서는 이미 해시된 패스워드를 기대할 수 있음
    }.to_json
    
    response = http.request(request)
    puts "API Response: #{response.code} - #{response.body}"
    
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
      {
        success: false,
        error: "HTTP 에러: #{response.code}"
      }
    end
  rescue => e
    puts "로그인 API 연결 실패: #{e.message}"
    {
      success: false,
      error: "서버 연결 실패: #{e.message}"
    }
  end
end

# 라우트
get '/login' do
  erb :real_login
end

get '/' do
  if session[:logged_in]
    user = session[:user_info] || {}
    "로그인 완료! 사용자: #{user['username']}, 권한: Level #{user['permission_level']}"
  else
    redirect '/login'
  end
end

post '/login' do
  username = params[:username]
  password = params[:password]
  
  puts "로그인 시도: #{username} / #{password}"
  
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
    erb :real_login
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

# HTML 템플릿
__END__

@@real_login
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ARUP ECS - 실제 로그인</title>
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
            max-width: 400px;
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
        }
        
        .system-info {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 15px;
            margin-bottom: 20px;
        }
        
        .system-info h3 {
            color: #495057;
            font-size: 16px;
            margin-bottom: 8px;
        }
        
        .system-info p {
            color: #6c757d;
            font-size: 14px;
            margin: 3px 0;
        }
        
        .api-status {
            background: #e3f2fd;
            border-radius: 8px;
            padding: 10px;
            margin-bottom: 20px;
            text-align: center;
        }
        
        .footer {
            text-align: center;
            margin-top: 20px;
            color: #999;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="logo">
            <h1>ARUP ECS</h1>
            <p>실제 시스템 로그인</p>
        </div>

        <div class="system-info">
            <h3>🏭 시스템 정보</h3>
            <p>• 8단계 공정: FIT-UP → FINAL → ARUP_FINAL → GALV → ARUP_GALV → SHOT → PAINT → ARUP_PAINT</p>
            <p>• 데이터: 5,758개 조립품 (arup_ecs 테이블)</p>
            <p>• 권한: Level 1~5 지원</p>
        </div>

        <div class="api-status">
            <p>🔗 Flask API: <%= FLASK_API_URL %></p>
            <p id="api-status">연결 상태 확인 중...</p>
        </div>

        <% if @error %>
            <div class="error-message">
                <%= @error %>
            </div>
        <% end %>

        <form method="post" action="/login">
            <div class="form-group">
                <label for="username">사용자명</label>
                <input type="text" id="username" name="username" value="<%= @username %>" required placeholder="실제 사용자명 입력">
            </div>

            <div class="form-group">
                <label for="password">비밀번호</label>
                <input type="password" id="password" name="password" required placeholder="실제 비밀번호 입력">
            </div>

            <button type="submit" class="btn-login">실제 로그인</button>
        </form>

        <div class="footer">
            <p>&copy; 2025 DSHI RPA System - ARUP ECS</p>
            <p><a href="/api/status" style="color: #667eea;">API 상태 확인</a></p>
        </div>
    </div>

    <script>
        // API 서버 상태 확인
        fetch('/api/status')
            .then(response => response.json())
            .then(data => {
                const statusElement = document.getElementById('api-status');
                if (data.flask_api_status === 'online') {
                    statusElement.textContent = '✅ Flask API 서버 온라인';
                    statusElement.style.color = '#4caf50';
                } else {
                    statusElement.textContent = '❌ Flask API 서버 오프라인';
                    statusElement.style.color = '#f44336';
                }
            })
            .catch(error => {
                document.getElementById('api-status').textContent = '❌ 연결 실패';
            });

        // 폼 제출 시 로딩 상태
        document.querySelector('form').addEventListener('submit', function() {
            const submitBtn = document.querySelector('.btn-login');
            submitBtn.textContent = '로그인 중...';
            submitBtn.disabled = true;
        });

        // 사용자명 필드에 포커스
        window.addEventListener('load', function() {
            document.getElementById('username').focus();
        });
    </script>
</body>
</html>