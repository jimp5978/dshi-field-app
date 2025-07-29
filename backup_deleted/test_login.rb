#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'bundler/setup'
require 'sinatra'
require 'webrick'

# Sinatra 설정
enable :sessions
set :session_secret, 'your-super-secret-session-key-change-this-in-production-must-be-at-least-64-characters-long-for-security'
set :port, 5003
set :bind, '0.0.0.0'

# 간단한 라우트 테스트
get '/login' do
  erb :login_test
end

get '/' do
  redirect '/login'
end

post '/login' do
  username = params[:username]
  password = params[:password]
  
  # 간단한 테스트 로그인
  if username == 'test' && password == 'test'
    session[:logged_in] = true
    "로그인 성공! username: #{username}"
  else
    @error = '잘못된 사용자명 또는 비밀번호'
    erb :login_test
  end
end

# HTML 템플릿
__END__

@@login_test
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ARUP ECS - 테스트 로그인</title>
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
        
        .test-info {
            background: #e3f2fd;
            border-radius: 8px;
            padding: 15px;
            margin-bottom: 20px;
            text-align: center;
        }
        
        .test-info h3 {
            color: #1565c0;
            font-size: 16px;
            margin-bottom: 8px;
        }
        
        .test-info p {
            color: #1976d2;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="logo">
            <h1>ARUP ECS</h1>
            <p>테스트 로그인 시스템</p>
        </div>

        <div class="test-info">
            <h3>🧪 테스트 계정</h3>
            <p>사용자명: <strong>test</strong></p>
            <p>비밀번호: <strong>test</strong></p>
        </div>

        <% if @error %>
            <div class="error-message">
                <%= @error %>
            </div>
        <% end %>

        <form method="post" action="/login">
            <div class="form-group">
                <label for="username">사용자명</label>
                <input type="text" id="username" name="username" value="test" required>
            </div>

            <div class="form-group">
                <label for="password">비밀번호</label>
                <input type="password" id="password" name="password" value="test" required>
            </div>

            <button type="submit" class="btn-login">테스트 로그인</button>
        </form>
    </div>

    <script>
        window.addEventListener('load', function() {
            document.getElementById('username').focus();
        });
    </script>
</body>
</html>