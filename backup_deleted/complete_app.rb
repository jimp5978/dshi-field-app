#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'sinatra'
require 'webrick'
require 'json'
require 'net/http'
require 'uri'
require 'digest'
require 'rubyXL'

# 포트와 기본 설정
set :port, 5007
set :bind, '0.0.0.0'
set :environment, :development
enable :sessions
set :session_secret, 'complete-app-session-secret-key-must-be-at-least-64-characters-long-for-security-purposes'

FLASK_API_URL = 'http://203.251.108.199:5001'

# 공정 순서 정의 (FIT_UP → FINAL → ARUP_PAINT → GALV → ARUP_FINAL)
PROCESS_ORDER = [
  'FIT_UP',
  'FINAL',
  'ARUP_FINAL', 
  'GALV',
  'ARUP_GALV',
  'SHOT',
  'PAINT',
  'ARUP_PAINT'
].freeze

puts "🏭 Complete DSHI Dashboard Starting"
puts "📍 URL: http://localhost:5007"
puts "🔗 Flask API: #{FLASK_API_URL}"
puts "🎯 Full Flow: Login → Search → Multi-select"

def debug_log(message)
  log_message = "🐛 DEBUG [#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}]: #{message}"
  puts log_message
  
  # 로그 파일에도 저장
  begin
    File.open('debug.log', 'a') do |file|
      file.puts log_message
    end
  rescue => e
    puts "로그 파일 쓰기 실패: #{e.message}"
  end
end

def sha256_hash(password)
  Digest::SHA256.hexdigest(password)
end

# 조립품의 다음 공정을 계산하는 함수
def get_next_process(assembly)
  # 각 공정의 완료 날짜 확인 (1900-01-01은 공정 불필요)
  processes = {
    'FIT_UP' => assembly['fit_up_date'],
    'FINAL' => assembly['final_date'],
    'ARUP_FINAL' => assembly['arup_final_date'],
    'GALV' => assembly['galv_date'],
    'ARUP_GALV' => assembly['arup_galv_date'],
    'SHOT' => assembly['shot_date'],
    'PAINT' => assembly['paint_date'],
    'ARUP_PAINT' => assembly['arup_paint_date']
  }
  
  # 마지막 완료된 공정 찾기
  last_completed_process = nil
  PROCESS_ORDER.each do |process|
    date = processes[process]
    # 날짜가 있고 1900-01-01이 아닌 경우 완료된 것으로 간주
    if date && date != '1900-01-01' && !date.empty?
      last_completed_process = process
    else
      break # 첫 번째 미완료 공정에서 중단
    end
  end
  
  # 다음 공정 반환
  if last_completed_process.nil?
    PROCESS_ORDER.first # 첫 번째 공정
  else
    current_index = PROCESS_ORDER.index(last_completed_process)
    if current_index && current_index < PROCESS_ORDER.length - 1
      PROCESS_ORDER[current_index + 1]
    else
      nil # 모든 공정 완료
    end
  end
end

# 공정명을 한글로 변환
def process_to_korean(process)
  case process
  when 'FIT_UP'
    'FIT-UP (조립)'
  when 'FINAL'
    'FINAL (완료)'
  when 'ARUP_FINAL'
    'ARUP_FINAL (아룹 최종)'
  when 'GALV'
    'GALV (도금)'
  when 'ARUP_GALV'
    'ARUP_GALV (아룹 도금)'
  when 'SHOT'
    'SHOT (쇼트블라스트)'
  when 'PAINT'
    'PAINT (도장)'
  when 'ARUP_PAINT'
    'ARUP_PAINT (아룹 도장)'
  else
    process
  end
end

# Flask 로그인 함수
def flask_login(username, password)
  password_hash = sha256_hash(password)
  debug_log("로그인 시도 - 사용자명: #{username}")
  
  begin
    uri = URI("#{FLASK_API_URL}/api/login")
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 10
    http.read_timeout = 10
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = {
      username: username,
      password_hash: password_hash
    }.to_json
    
    response = http.request(request)
    debug_log("로그인 API 응답: #{response.code}")
    
    if response.code == '200'
      data = JSON.parse(response.body)
      if data['success']
        { success: true, token: data['token'], user: data['user'] }
      else
        { success: false, error: data['message'] || '로그인 실패' }
      end
    else
      { success: false, error: '로그인 중 오류가 발생했습니다' }
    end
  rescue => e
    debug_log("로그인 API 연결 실패: #{e.message}")
    { success: false, error: "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." }
  end
end

# 로그인 페이지 HTML
def login_html(error_msg = nil, username = nil)
  <<~HTML
    <!DOCTYPE html>
    <html lang="ko">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>DSHI Dashboard - 로그인</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: linear-gradient(135deg, #2196F3 0%, #21CBF3 100%);
                min-height: 100vh; display: flex; align-items: center; justify-content: center;
            }
            .login-container {
                background: white; border-radius: 12px; box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
                padding: 40px; width: 100%; max-width: 420px; position: relative;
            }
            .debug-indicator {
                position: absolute; top: -10px; right: -10px; background: #4CAF50; color: white;
                padding: 5px 10px; border-radius: 15px; font-size: 12px; font-weight: bold;
            }
            .logo { text-align: center; margin-bottom: 30px; }
            .logo h1 { color: #333; font-size: 28px; margin-bottom: 10px; font-weight: 500; }
            .logo p { color: #666; font-size: 14px; }
            .form-group { margin-bottom: 20px; }
            .form-group label { display: block; margin-bottom: 8px; color: #333; font-weight: 500; font-size: 14px; }
            .form-group input {
                width: 100%; padding: 12px 16px; border: 2px solid #e1e5e9; border-radius: 8px;
                font-size: 16px; transition: all 0.3s; background: #fafafa;
            }
            .form-group input:focus {
                outline: none; border-color: #2196F3; background: white;
                box-shadow: 0 0 0 3px rgba(33, 150, 243, 0.1);
            }
            .btn-login {
                width: 100%; padding: 14px; background: linear-gradient(135deg, #2196F3 0%, #21CBF3 100%);
                color: white; border: none; border-radius: 8px; font-size: 16px; font-weight: 600;
                cursor: pointer; transition: all 0.3s; text-transform: uppercase; letter-spacing: 0.5px;
            }
            .btn-login:hover { transform: translateY(-2px); box-shadow: 0 8px 16px rgba(33, 150, 243, 0.3); }
            .error-message {
                background: #FFEBEE; border: 1px solid #FFCDD2; border-left: 4px solid #F44336;
                color: #C62828; padding: 12px 16px; border-radius: 4px; margin-bottom: 20px; font-size: 14px;
            }
            .debug-info {
                background: #E8F5E8; border: 1px solid #4CAF50; border-left: 4px solid #4CAF50;
                color: #2E7D32; padding: 10px; border-radius: 4px; margin-bottom: 20px; font-size: 12px;
            }
        </style>
    </head>
    <body>
        <div class="login-container">
            <div class="debug-indicator">✅ COMPLETE</div>
            <div class="logo">
                <h1>🏭 DSHI Dashboard</h1>
                <p>현장 관리 시스템 - Complete Version</p>
            </div>
            
            <div class="debug-info">
                <strong>✅ Complete Mode</strong><br>
                포트: 5007 | Flask API: #{FLASK_API_URL}<br>
                Full Flow: Login → Search → Multi-select
            </div>

            #{error_msg ? "<div class=\"error-message\">#{error_msg}</div>" : ""}

            <form method="post" action="/login">
                <div class="form-group">
                    <label for="username">사용자 ID</label>
                    <input type="text" id="username" name="username" value="#{username || ''}" 
                           required placeholder="사용자 ID를 입력하세요" autocomplete="username">
                </div>

                <div class="form-group">
                    <label for="password">비밀번호</label>
                    <input type="password" id="password" name="password" 
                           required placeholder="비밀번호를 입력하세요" autocomplete="current-password">
                </div>

                <button type="submit" class="btn-login">로그인</button>
            </form>
        </div>
        
        <script>
            document.addEventListener('DOMContentLoaded', function() {
                const usernameField = document.getElementById('username');
                const passwordField = document.getElementById('password');
                
                if (!usernameField.value) {
                    usernameField.focus();
                } else {
                    passwordField.focus();
                }
            });
        </script>
    </body>
    </html>
  HTML
end

# 검색 페이지 HTML
def search_html(user_info)
  <<~HTML
    <!DOCTYPE html>
    <html lang="ko">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>DSHI Dashboard - 조립품 검색</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: #f5f5f5; min-height: 100vh;
            }
            .header {
                background: linear-gradient(135deg, #2196F3 0%, #21CBF3 100%);
                color: white; padding: 15px 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            .header-content {
                max-width: 1200px; margin: 0 auto; display: flex; justify-content: space-between; align-items: center;
            }
            .header h1 { font-size: 24px; font-weight: 500; }
            .user-info { font-size: 14px; }
            .logout-btn {
                background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.3);
                color: white; padding: 8px 16px; border-radius: 6px; text-decoration: none;
                transition: all 0.3s; margin-left: 15px;
            }
            .logout-btn:hover { background: rgba(255,255,255,0.3); }
            .container { max-width: 1200px; margin: 20px auto; padding: 0 20px; }
            .card {
                background: white; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                margin-bottom: 20px; overflow: hidden;
            }
            .card-header {
                background: #f8f9fa; padding: 20px; border-bottom: 1px solid #e9ecef;
                font-size: 18px; font-weight: 600; color: #333;
            }
            .card-body { padding: 20px; }
            .btn {
                padding: 10px 20px; border: none; border-radius: 6px; cursor: pointer;
                font-size: 14px; font-weight: 500; transition: all 0.3s; text-decoration: none;
                display: inline-block; text-align: center;
            }
            .btn-primary { background: #2196F3; color: white; }
            .btn-secondary { background: #6c757d; color: white; }
            .btn:hover { transform: translateY(-1px); box-shadow: 0 4px 8px rgba(0,0,0,0.15); }
            .btn:disabled { opacity: 0.6; cursor: not-allowed; transform: none; }
            table { width: 100%; border-collapse: collapse; border: 1px solid #ddd; }
            th, td { padding: 12px; border: 1px solid #ddd; text-align: left; }
            th { background: #f8f9fa; font-weight: 600; }
            tr:hover { background-color: #f8f9fa; }
            .status-box { padding: 15px; border-radius: 6px; margin-bottom: 20px; display: none; }
            .status-success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
            .status-error { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
            .status-loading { background: #fff3cd; color: #856404; border: 1px solid #ffeaa7; }
            input[type="text"] {
                padding: 12px; border: 2px solid #e1e5e9; border-radius: 6px;
                font-size: 16px; transition: all 0.3s; width: 200px;
            }
            input[type="text"]:focus {
                outline: none; border-color: #2196F3; box-shadow: 0 0 0 3px rgba(33, 150, 243, 0.1);
            }
            .checkbox-cell { text-align: center; width: 50px; }
            .item-checkbox, #selectAllCheckbox { transform: scale(1.2); cursor: pointer; }
            .selection-info {
                margin-top: 15px; padding: 15px; background: #e3f2fd; border-radius: 6px;
                border-left: 4px solid #2196F3; display: none;
            }
        </style>
    </head>
    <body>
        <div class="header">
            <div class="header-content">
                <h1>🏭 DSHI Dashboard</h1>
                <div class="user-info">
                    👤 #{user_info['username']}님 (Level #{user_info['permission_level']})
                    <a href="/saved-list" class="logout-btn">📋 저장된 리스트</a>
                    <a href="/inspection-requests" class="logout-btn">📊 검사신청 조회</a>
                    <a href="/logout" class="logout-btn">로그아웃</a>
                </div>
            </div>
        </div>

        <div class="container">
            <div class="card">
                <div class="card-header">
                    🔍 조립품 검색
                </div>
                <div class="card-body">
                    <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
                        <form id="searchForm" style="display: flex; gap: 10px; align-items: center;">
                            <div style="flex: 1;">
                                <label style="display: block; margin-bottom: 5px; font-weight: 500;">검색어 (끝 3자리)</label>
                                <input type="text" id="searchInput" placeholder="예: 001, 123, 420" 
                                       maxlength="3" pattern="[0-9]{1,3}" required>
                            </div>
                            <div>
                                <button type="submit" class="btn btn-primary" id="searchBtn" style="margin-top: 25px;">검색</button>
                            </div>
                        </form>
                    </div>

                    <div id="searchStatus" class="status-box">
                        <span id="statusMessage"></span>
                    </div>

                    <div id="searchResults" style="display: none;">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px;">
                            <h3 id="resultsTitle">검색 결과</h3>
                            <div>
                                <button id="selectAllBtn" class="btn btn-secondary" style="margin-right: 10px;">전체선택</button>
                                <button id="addToListBtn" class="btn btn-primary" disabled>선택항목 저장</button>
                            </div>
                        </div>

                        <div style="overflow-x: auto;">
                            <table id="resultsTable">
                                <thead>
                                    <tr>
                                        <th class="checkbox-cell">
                                            <input type="checkbox" id="selectAllCheckbox">
                                        </th>
                                        <th>조립품 코드</th>
                                        <th>Zone</th>
                                        <th>Item</th>
                                        <th>Weight(NET)</th>
                                        <th>Status</th>
                                        <th>Last Process</th>
                                    </tr>
                                </thead>
                                <tbody id="resultsBody"></tbody>
                            </table>
                        </div>

                        <div id="selectionInfo" class="selection-info">
                            <strong>선택된 항목:</strong> <span id="selectedCount">0</span>개 
                            | <strong>총 중량:</strong> <span id="totalWeight">0</span> kg
                        </div>
                    </div>
                </div>
            </div>

            <div class="card" style="background: #f8f9fa;">
                <div class="card-header">🐛 Debug 정보</div>
                <div class="card-body">
                    <div style="font-family: monospace; font-size: 12px; color: #666;">
                        <strong>사용자:</strong> #{user_info['username']} (Level #{user_info['permission_level']})<br>
                        <strong>Flask API:</strong> #{FLASK_API_URL}<br>
                        <strong>현재 시간:</strong> <span id="currentTime"></span><br>
                        <strong>검색 로그:</strong><br>
                        <div id="searchLog" style="max-height: 200px; overflow-y: auto; background: white; padding: 10px; margin-top: 5px; border: 1px solid #ddd;">
                            - 검색 준비 완료<br>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <script>
            function debugLog(message) {
                console.log('🐛 DEBUG:', message);
                const logElement = document.getElementById('searchLog');
                const timestamp = new Date().toLocaleTimeString();
                logElement.innerHTML += `[${timestamp}] ${message}<br>`;
                logElement.scrollTop = logElement.scrollHeight;
            }
            
            function showStatus(message, type = 'info') {
                const statusElement = document.getElementById('searchStatus');
                const messageElement = document.getElementById('statusMessage');
                
                messageElement.textContent = message;
                statusElement.style.display = 'block';
                statusElement.className = 'status-box status-' + type;
            }
            
            function displayResults(assemblies) {
                const tbody = document.getElementById('resultsBody');
                const resultsDiv = document.getElementById('searchResults');
                const titleElement = document.getElementById('resultsTitle');
                
                tbody.innerHTML = '';
                
                if (assemblies.length === 0) {
                    showStatus('검색 결과가 없습니다.', 'error');
                    resultsDiv.style.display = 'none';
                    return;
                }
                
                titleElement.textContent = `검색 결과 (${assemblies.length}개)`;
                resultsDiv.style.display = 'block';
                
                debugLog(`첫 번째 항목: ${JSON.stringify(assemblies[0], null, 2)}`);
                
                assemblies.forEach((assembly, index) => {
                    const row = document.createElement('tr');
                    row.innerHTML = `
                        <td class="checkbox-cell">
                            <input type="checkbox" class="item-checkbox" data-index="${index}" data-assembly='${JSON.stringify(assembly)}'>
                        </td>
                        <td>${assembly.name || 'N/A'}</td>
                        <td>${assembly.location || 'N/A'}</td>
                        <td>${assembly.drawing_number || 'N/A'}</td>
                        <td style="text-align: right;">${assembly.weight_net || '0'}</td>
                        <td>${assembly.status || '-'}</td>
                        <td>${assembly.lastProcess || '-'}</td>
                    `;
                    tbody.appendChild(row);
                });
                
                updateSelectionHandlers();
                updateSelectionInfo();
                showStatus(`${assemblies.length}개의 조립품을 찾았습니다.`, 'success');
                debugLog(`검색 결과 표시 완료: ${assemblies.length}개`);
            }
            
            function updateSelectionHandlers() {
                document.querySelectorAll('.item-checkbox').forEach(checkbox => {
                    checkbox.addEventListener('change', updateSelectionInfo);
                });
                
                document.getElementById('selectAllCheckbox').addEventListener('change', function() {
                    const isChecked = this.checked;
                    document.querySelectorAll('.item-checkbox').forEach(checkbox => {
                        checkbox.checked = isChecked;
                    });
                    updateSelectionInfo();
                });
            }
            
            function updateSelectionInfo() {
                const checkboxes = document.querySelectorAll('.item-checkbox:checked');
                const count = checkboxes.length;
                let totalWeight = 0;
                
                checkboxes.forEach(checkbox => {
                    const assembly = JSON.parse(checkbox.dataset.assembly);
                    totalWeight += parseFloat(assembly.weight_net || 0);
                });
                
                document.getElementById('selectedCount').textContent = count;
                document.getElementById('totalWeight').textContent = totalWeight.toFixed(2);
                document.getElementById('selectionInfo').style.display = count > 0 ? 'block' : 'none';
                document.getElementById('addToListBtn').disabled = count === 0;
                
                debugLog(`선택 업데이트: ${count}개, 총 중량: ${totalWeight.toFixed(2)}kg`);
            }
            
            async function performSearch(searchTerm) {
                debugLog(`검색 시작: "${searchTerm}"`);
                showStatus('검색 중...', 'loading');
                
                try {
                    const response = await fetch('/api/search', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                        body: `search_term=${encodeURIComponent(searchTerm)}`
                    });
                    
                    debugLog(`API 응답: ${response.status}`);
                    
                    if (!response.ok) {
                        throw new Error(`HTTP ${response.status}`);
                    }
                    
                    const data = await response.json();
                    debugLog(`응답 데이터 수신: ${data.assemblies ? data.assemblies.length : 0}개`);
                    
                    if (data.error) {
                        throw new Error(data.error);
                    }
                    
                    displayResults(data.assemblies || []);
                    
                } catch (error) {
                    debugLog(`검색 오류: ${error.message}`);
                    showStatus(`검색 오류: ${error.message}`, 'error');
                    document.getElementById('searchResults').style.display = 'none';
                }
            }
            
            document.addEventListener('DOMContentLoaded', function() {
                debugLog('조립품 검색 페이지 로드 완료');
                
                function updateTime() {
                    document.getElementById('currentTime').textContent = new Date().toLocaleString();
                }
                updateTime();
                setInterval(updateTime, 1000);
                
                const searchForm = document.getElementById('searchForm');
                const searchInput = document.getElementById('searchInput');
                const searchBtn = document.getElementById('searchBtn');
                
                searchForm.addEventListener('submit', function(e) {
                    e.preventDefault();
                    
                    const searchTerm = searchInput.value.trim();
                    if (searchTerm.length === 0) {
                        alert('검색어를 입력해주세요.');
                        return;
                    }
                    
                    if (!/^[0-9]{1,3}$/.test(searchTerm)) {
                        alert('숫자 1-3자리만 입력 가능합니다.');
                        return;
                    }
                    
                    searchBtn.textContent = '검색 중...';
                    searchBtn.disabled = true;
                    
                    performSearch(searchTerm).finally(() => {
                        searchBtn.textContent = '검색';
                        searchBtn.disabled = false;
                    });
                });
                
                searchInput.addEventListener('input', function(e) {
                    this.value = this.value.replace(/[^0-9]/g, '');
                });
                
                document.getElementById('selectAllBtn').addEventListener('click', function() {
                    const allCheckboxes = document.querySelectorAll('.item-checkbox');
                    const selectAllCheckbox = document.getElementById('selectAllCheckbox');
                    const isAllSelected = Array.from(allCheckboxes).every(cb => cb.checked);
                    
                    allCheckboxes.forEach(checkbox => {
                        checkbox.checked = !isAllSelected;
                    });
                    selectAllCheckbox.checked = !isAllSelected;
                    
                    updateSelectionInfo();
                });
                
                document.getElementById('addToListBtn').addEventListener('click', async function() {
                    const selected = document.querySelectorAll('.item-checkbox:checked');
                    const selectedData = Array.from(selected).map(cb => JSON.parse(cb.dataset.assembly));
                    
                    let totalWeight = 0;
                    selectedData.forEach(item => totalWeight += parseFloat(item.weight_net || 0));
                    
                    debugLog(`저장 리스트 추가 시도: ${selected.length}개, ${totalWeight.toFixed(2)}kg`);
                    
                    try {
                        const response = await fetch('/api/save-list', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ assemblies: selectedData })
                        });
                        
                        const result = await response.json();
                        
                        if (result.success) {
                            alert(`✅ ${selected.length}개 항목을 저장 리스트에 추가했습니다!\\n\\n📊 총 중량: ${totalWeight.toFixed(2)} kg\\n🔗 저장된 리스트: ${result.total_count}개`);
                            debugLog(`저장 완료: 총 ${result.total_count}개 항목`);
                        } else {
                            alert(`❌ 저장 실패: ${result.error}`);
                            debugLog(`저장 실패: ${result.error}`);
                        }
                    } catch (error) {
                        alert(`❌ 저장 오류: ${error.message}`);
                        debugLog(`저장 오류: ${error.message}`);
                    }
                });
                
                searchInput.focus();
                debugLog('모든 이벤트 리스너 설정 완료');
            });
        </script>
    </body>
    </html>
  HTML
end

# 검사신청 조회 페이지 HTML (간소화 버전)
def inspection_requests_html(user_info)
  "검사신청 조회 페이지입니다."
end

# 저장된 리스트 페이지 HTML
def saved_list_html(user_info, saved_list)
  total_weight = saved_list.sum { |item| (item['weight_net'] || 0).to_f }
  
  html_content = <<-HTML
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DSHI Dashboard - 저장된 리스트</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #f5f5f5; min-height: 100vh;
        }
        .header {
            background: linear-gradient(135deg, #2196F3 0%, #21CBF3 100%);
            color: white; padding: 15px 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .header-content {
            max-width: 1200px; margin: 0 auto; display: flex; justify-content: space-between; align-items: center;
        }
        .header h1 { font-size: 24px; font-weight: 500; }
        .user-info { font-size: 14px; }
        .nav-btn, .logout-btn {
            background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.3);
            color: white; padding: 8px 16px; border-radius: 6px; text-decoration: none;
            transition: all 0.3s; margin-left: 10px;
        }
        .nav-btn:hover, .logout-btn:hover { background: rgba(255,255,255,0.3); }
        .container { max-width: 1200px; margin: 20px auto; padding: 0 20px; }
        .card {
            background: white; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 20px; overflow: hidden;
        }
        .card-header {
            background: #f8f9fa; padding: 20px; border-bottom: 1px solid #e9ecef;
            font-size: 18px; font-weight: 600; color: #333;
        }
        .card-body { padding: 20px; }
        .btn {
            padding: 10px 20px; border: none; border-radius: 6px; cursor: pointer;
            font-size: 14px; font-weight: 500; transition: all 0.3s; text-decoration: none;
            display: inline-block; text-align: center; margin-right: 10px;
        }
        .btn-primary { background: #2196F3; color: white; }
        .btn-success { background: #28a745; color: white; }
        .btn-danger { background: #dc3545; color: white; }
        .btn:hover { transform: translateY(-1px); box-shadow: 0 4px 8px rgba(0,0,0,0.15); }
        .btn:disabled { opacity: 0.6; cursor: not-allowed; transform: none; }
        table { width: 100%; border-collapse: collapse; border: 1px solid #ddd; }
        th, td { padding: 12px; border: 1px solid #ddd; text-align: left; }
        th { background: #f8f9fa; font-weight: 600; }
        tr:hover { background-color: #f8f9fa; }
        .summary-info {
            background: #e3f2fd; padding: 20px; border-radius: 8px; margin-bottom: 20px;
            border-left: 4px solid #2196F3;
        }
        .checkbox-cell { text-align: center; width: 50px; }
        .item-checkbox { transform: scale(1.2); cursor: pointer; }
        .empty-state {
            text-align: center; padding: 60px 20px; color: #666;
        }
        .empty-state h3 { margin-bottom: 10px; color: #333; }
    </style>
</head>
<body>
    <div class="header">
        <div class="header-content">
            <h1>🏭 DSHI Dashboard</h1>
            <div class="user-info">
                👤 #{user_info['username']}님 (Level #{user_info['permission_level']})
                <a href="/" class="nav-btn">🔍 조립품 검색</a>
                <a href="/inspection-requests" class="nav-btn">📊 검사신청 조회</a>
                <a href="/logout" class="logout-btn">로그아웃</a>
            </div>
        </div>
    </div>

    <div class="container">
        <div class="card">
            <div class="card-header">
                📋 저장된 리스트
            </div>
            <div class="card-body">
HTML

  if saved_list.empty?
    html_content += <<-HTML
                <div class="empty-state">
                    <h3>📭 저장된 항목이 없습니다</h3>
                    <p>조립품 검색에서 항목을 선택하고 저장해보세요.</p>
                    <a href="/" class="btn btn-primary" style="margin-top: 20px;">🔍 조립품 검색하기</a>
                </div>
HTML
  else
    html_content += <<-HTML
                <div class="summary-info" id="summaryInfo">
                    <strong>📊 요약 정보:</strong> 총 #{saved_list.size}개 항목 | 총 중량: #{total_weight.round(2)} kg
                </div>
                
                <div style="background: #e3f2fd; padding: 20px; border-radius: 8px; margin-bottom: 20px; border-left: 4px solid #2196F3;">
                    <h4 style="margin-bottom: 15px;">🔍 검사신청</h4>
                    <div style="display: flex; gap: 15px; align-items: end;">
                        <div>
                            <label style="display: block; margin-bottom: 8px; font-weight: 500;">검사신청일</label>
                            <input type="date" id="inspectionDate" 
                                   style="padding: 10px; border: 2px solid #e1e5e9; border-radius: 6px; font-size: 14px;"
                                   min="#{Date.today.strftime("%Y-%m-%d")}"
                                   value="#{(Date.today + 1).strftime("%Y-%m-%d")}">
                        </div>
                        <div>
                            <button id="createInspectionBtn" class="btn btn-success" disabled>검사신청</button>
                        </div>
                        <div>
                            <button id="removeSelectedBtn" class="btn btn-danger" disabled>선택항목 삭제</button>
                        </div>
                    </div>
                    <div id="selectedInfo" style="margin-top: 15px; font-size: 14px; color: #666;">
                        선택된 항목: 0개
                    </div>
                </div>

                <div style="overflow-x: auto;">
                    <table id="savedListTable">
                        <thead>
                            <tr>
                                <th class="checkbox-cell">
                                    <input type="checkbox" id="selectAllCheckbox">
                                </th>
                                <th>조립품 코드</th>
                                <th>Zone</th>
                                <th>Item</th>
                                <th>Weight(NET)</th>
                                <th>Status</th>
                                <th>Last Process</th>
                            </tr>
                        </thead>
                        <tbody id="savedListBody">
HTML
    
    saved_list.each_with_index do |assembly, index|
      html_content += <<-HTML
                            <tr>
                                <td class="checkbox-cell">
                                    <input type="checkbox" class="item-checkbox" data-index="#{index}" data-assembly='#{assembly.to_json}'>
                                </td>
                                <td>#{assembly['name'] || 'N/A'}</td>
                                <td>#{assembly['location'] || 'N/A'}</td>
                                <td>#{assembly['drawing_number'] || 'N/A'}</td>
                                <td style="text-align: right;">#{assembly['weight_net'] || '0'}</td>
                                <td>#{assembly['status'] || '-'}</td>
                                <td>#{assembly['lastProcess'] || '-'}</td>
                            </tr>
HTML
    end
    
    html_content += <<-HTML
                        </tbody>
                    </table>
                </div>
HTML
  end

  html_content += <<-HTML
            </div>
        </div>
    </div>

    <script>
        function updateSelectionButtons() {
            const selected = document.querySelectorAll('.item-checkbox:checked');
            const removeBtn = document.getElementById('removeSelectedBtn');
            const inspectionBtn = document.getElementById('createInspectionBtn');
            const selectedInfo = document.getElementById('selectedInfo');
            const summaryInfo = document.getElementById('summaryInfo');
            
            if (removeBtn) removeBtn.disabled = selected.length === 0;
            if (inspectionBtn) inspectionBtn.disabled = selected.length === 0;
            if (selectedInfo) selectedInfo.textContent = `선택된 항목: ${selected.length}개`;
            
            // 요약 정보 동적 업데이트
            if (summaryInfo && selected.length > 0) {
                let selectedWeight = 0;
                Array.from(selected).forEach(checkbox => {
                    const assembly = JSON.parse(checkbox.dataset.assembly);
                    selectedWeight += parseFloat(assembly.weight_net || 0);
                });
                summaryInfo.innerHTML = `<strong>📊 요약 정보:</strong> 선택된 ${selected.length}개 항목 | 선택된 중량: ${selectedWeight.toFixed(2)} kg`;
            } else if (summaryInfo) {
                summaryInfo.innerHTML = `<strong>📊 요약 정보:</strong> 총 #{saved_list.size}개 항목 | 총 중량: #{total_weight.round(2)} kg`;
            }
        }

        document.addEventListener('DOMContentLoaded', function() {
            const selectAllCheckbox = document.getElementById('selectAllCheckbox');
            
            if (selectAllCheckbox) {
                selectAllCheckbox.addEventListener('change', function() {
                    const isChecked = this.checked;
                    document.querySelectorAll('.item-checkbox').forEach(checkbox => {
                        checkbox.checked = isChecked;
                    });
                    updateSelectionButtons();
                });
            }

            document.querySelectorAll('.item-checkbox').forEach(checkbox => {
                checkbox.addEventListener('change', updateSelectionButtons);
            });

            const removeSelectedBtn = document.getElementById('removeSelectedBtn');
            if (removeSelectedBtn) {
                removeSelectedBtn.addEventListener('click', function() {
                    const selected = document.querySelectorAll('.item-checkbox:checked');
                    if (selected.length > 0 && confirm(`선택된 ${selected.length}개 항목을 삭제하시겠습니까?`)) {
                        const indices = Array.from(selected).map(cb => parseInt(cb.dataset.index));
                        location.href = '/api/remove-from-saved-list?indices=' + indices.join(',');
                    }
                });
            }

            const createInspectionBtn = document.getElementById('createInspectionBtn');
            if (createInspectionBtn) {
                createInspectionBtn.addEventListener('click', async function() {
                    const selected = document.querySelectorAll('.item-checkbox:checked');
                    const inspectionDate = document.getElementById('inspectionDate').value;
                    
                    if (selected.length === 0) {
                        alert('검사신청할 항목을 선택해주세요.');
                        return;
                    }
                    
                    if (!inspectionDate) {
                        alert('검사신청일을 선택해주세요.');
                        return;
                    }
                    
                    const selectedData = Array.from(selected).map(cb => JSON.parse(cb.dataset.assembly));
                    
                    // 같은 공정인지 검증 - 다음 공정 계산
                    const nextProcesses = selectedData.map(assembly => {
                        // 공정 순서: Weld → Level-1 → Level-2 → Level-3 → Level-4 → Final → Fit-up
                        const processOrder = ['Weld', 'Level-1', 'Level-2', 'Level-3', 'Level-4', 'Final', 'Fit-up'];
                        
                        // 각 공정의 완료 상태 확인 (1900-01-01은 미완료로 처리)
                        const weldDate = assembly.weld_completion_date || '';
                        const level1Date = assembly.level1_completion_date || '';
                        const level2Date = assembly.level2_completion_date || '';
                        const level3Date = assembly.level3_completion_date || '';
                        const level4Date = assembly.level4_completion_date || '';
                        const finalDate = assembly.final_completion_date || '';
                        const fitupDate = assembly.fitup_completion_date || '';
                        
                        const isCompleted = (date) => date && date !== '1900-01-01' && date !== '';
                        
                        // 다음에 해야 할 공정 찾기
                        if (!isCompleted(weldDate)) return 'Weld';
                        if (!isCompleted(level1Date)) return 'Level-1';  
                        if (!isCompleted(level2Date)) return 'Level-2';
                        if (!isCompleted(level3Date)) return 'Level-3';
                        if (!isCompleted(level4Date)) return 'Level-4';
                        if (!isCompleted(finalDate)) return 'Final';
                        if (!isCompleted(fitupDate)) return 'Fit-up';
                        
                        return null; // 모든 공정 완료
                    });
                    
                    const uniqueProcesses = [...new Set(nextProcesses.filter(p => p !== null))];
                    
                    if (uniqueProcesses.length > 1) {
                        const processNames = uniqueProcesses.map(p => {
                            switch(p) {
                                case 'Level-1': return 'Level 1 검사';
                                case 'Level-2': return 'Level 2 검사';  
                                case 'Level-3': return 'Level 3 검사';
                                case 'Level-4': return 'Level 4 검사';
                                case 'Final': return 'Final 검사';
                                case 'Fit-up': return 'Fit-up 검사';
                                case 'Weld': return '용접';
                                default: return p;
                            }
                        }).join(', ');
                        
                        alert(`❌ 검사신청 오류\\n\\n선택된 조립품들의 다음 공정이 다릅니다.\\n동일한 공정의 조립품만 선택해주세요.\\n\\n다음 공정들: ${processNames}\\n\\n같은 공정의 조립품만 다시 선택해주세요.`);
                        return;
                    }
                    
                    // 다음 공정명을 한글로 변환
                    const commonProcess = uniqueProcesses[0];
                    let processKoreanName = '';
                    switch(commonProcess) {
                        case 'Weld': processKoreanName = '용접'; break;
                        case 'Level-1': processKoreanName = 'Level 1 검사'; break;
                        case 'Level-2': processKoreanName = 'Level 2 검사'; break;
                        case 'Level-3': processKoreanName = 'Level 3 검사'; break;
                        case 'Level-4': processKoreanName = 'Level 4 검사'; break;
                        case 'Final': processKoreanName = 'Final 검사'; break;
                        case 'Fit-up': processKoreanName = 'Fit-up 검사'; break;
                        default: processKoreanName = commonProcess;
                    }
                    
                    if (!confirm(`${selected.length}개 항목을 ${processKoreanName} ${inspectionDate} 검사신청하시겠습니까?`)) {
                        return;
                    }
                    
                    try {
                        const response = await fetch('/api/create-inspection-request', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({
                                assemblies: selectedData,
                                inspection_date: inspectionDate
                            })
                        });
                        
                        const result = await response.json();
                        
                        if (result.success) {
                            alert(`✅ 검사신청이 성공적으로 생성되었습니다!\\n\\n📋 신청 항목: ${selectedData.length}개\\n📅 검사일: ${inspectionDate}`);
                            location.reload();
                        } else {
                            alert(`❌ 검사신청 실패: ${result.error}`);
                        }
                    } catch (error) {
                        alert(`❌ 검사신청 오류: ${error.message}`);
                    }
                });
            }
        });
    </script>
</body>
</html>
HTML

  return html_content
end

# 라우트들
get '/' do
  debug_log("메인 페이지 접근")
  if session[:logged_in]
    user = session[:user_info] || {}
    debug_log("인증된 사용자: #{user['username']}")
    search_html(user)
  else
    debug_log("미인증 사용자 - 로그인 페이지로 리다이렉트")
    redirect '/login'
  end
end

get '/login' do
  debug_log("로그인 페이지 접근")
  login_html
end

post '/login' do
  username = params[:username]
  password = params[:password]
  debug_log("로그인 요청: #{username}")
  
  result = flask_login(username, password)
  
  if result[:success]
    session[:logged_in] = true
    session[:jwt_token] = result[:token]
    session[:user_info] = result[:user]
    debug_log("로그인 성공: #{username}")
    redirect '/'
  else
    debug_log("로그인 실패: #{result[:error]}")
    login_html(result[:error], username)
  end
end

get '/logout' do
  debug_log("로그아웃: #{session[:user_info]&.[]('username')}")
  session.clear
  redirect '/login'
end

post '/api/search' do
  debug_log("검색 API 호출")
  
  unless session[:logged_in]
    debug_log("미인증 사용자")
    content_type :json
    return { error: '로그인이 필요합니다' }.to_json
  end
  
  search_term = params[:search_term]
  debug_log("검색어: #{search_term}")
  
  if search_term.nil? || search_term.strip.empty?
    debug_log("검색어 없음")
    content_type :json
    return { error: '검색어를 입력해주세요' }.to_json
  end
  
  unless search_term.match?(/^\d{1,3}$/)
    debug_log("잘못된 검색어 형식: #{search_term}")
    content_type :json
    return { error: '숫자 1-3자리만 입력 가능합니다' }.to_json
  end
  
  begin
    uri = URI("#{FLASK_API_URL}/api/assemblies")
    uri.query = URI.encode_www_form(search: search_term)
    debug_log("Flask API 요청: #{uri}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 15
    http.read_timeout = 15
    
    request = Net::HTTP::Get.new(uri)
    if session[:jwt_token]
      request['Authorization'] = "Bearer #{session[:jwt_token]}"
    end
    
    response = http.request(request)
    debug_log("Flask API 응답: #{response.code}")
    
    content_type :json
    if response.code == '200'
      data = JSON.parse(response.body)
      assemblies = data['assemblies'] || []
      debug_log("조립품 개수: #{assemblies.size}")
      
      {
        success: true,
        assemblies: assemblies,
        count: assemblies.size,
        search_term: search_term
      }.to_json
    else
      debug_log("Flask API 오류: #{response.code}")
      { error: "Flask API 오류 (#{response.code})" }.to_json
    end
    
  rescue => e
    debug_log("Flask API 연결 실패: #{e.message}")
    content_type :json
    { error: "서버 연결 실패: #{e.message}" }.to_json
  end
end

# 저장 리스트 API
post '/api/save-list' do
  debug_log("저장 리스트 API 호출")
  
  unless session[:logged_in]
    content_type :json
    return { error: '로그인이 필요합니다' }.to_json
  end
  
  begin
    body = request.body.read
    data = JSON.parse(body)
    assemblies = data['assemblies'] || []
    
    debug_log("저장할 항목 수: #{assemblies.size}")
    
    session[:saved_list] ||= []
    
    assemblies.each do |assembly|
      unless session[:saved_list].any? { |item| item['name'] == assembly['name'] }
        session[:saved_list] << assembly
      end
    end
    
    debug_log("총 저장된 항목 수: #{session[:saved_list].size}")
    
    content_type :json
    { 
      success: true, 
      added_count: assemblies.size,
      total_count: session[:saved_list].size
    }.to_json
    
  rescue => e
    debug_log("저장 리스트 오류: #{e.message}")
    content_type :json
    { error: "저장 실패: #{e.message}" }.to_json
  end
end

# 검사신청 조회 페이지
get '/inspection-requests' do
  debug_log("검사신청 조회 페이지 접근")
  
  unless session[:logged_in]
    debug_log("미인증 사용자 - 로그인 페이지로 리다이렉트")
    redirect '/login'
  end
  
  user = session[:user_info] || {}
  debug_log("검사신청 조회: #{user['username']} (Level #{user['permission_level']})")
  
  inspection_requests_html(user)
end

# 저장된 리스트 조회 페이지
get '/saved-list' do
  debug_log("저장된 리스트 페이지 접근")
  
  unless session[:logged_in]
    debug_log("미인증 사용자 - 로그인 페이지로 리다이렉트")
    redirect '/login'
  end
  
  user = session[:user_info] || {}
  saved_list = session[:saved_list] || []
  
  # 검사신청 가능한 항목만 필터링 (다음 공정이 있는 항목만)
  filtered_list = saved_list.select do |assembly|
    next_process = get_next_process(assembly)
    next_process != nil  # 다음 공정이 있는 항목만 표시
  end
  
  debug_log("저장된 리스트 조회: 전체 #{saved_list.size}개, 검사신청 가능 #{filtered_list.size}개")
  saved_list_html(user, filtered_list)
end

# 저장된 리스트 전체 삭제
get '/api/clear-saved-list' do
  debug_log("저장된 리스트 전체 삭제")
  
  unless session[:logged_in]
    redirect '/login'
  end
  
  session[:saved_list] = []
  debug_log("저장된 리스트 전체 삭제 완료")
  redirect '/saved-list'
end

# 저장된 리스트에서 선택 항목 삭제
get '/api/remove-from-saved-list' do
  debug_log("저장된 리스트 선택 삭제")
  
  unless session[:logged_in]
    redirect '/login'
  end
  
  indices = params[:indices]&.split(',')&.map(&:to_i) || []
  saved_list = session[:saved_list] || []
  
  indices.sort.reverse.each do |index|
    saved_list.delete_at(index) if index >= 0 && index < saved_list.size
  end
  
  session[:saved_list] = saved_list
  debug_log("선택 항목 삭제 완료: #{indices.size}개")
  redirect '/saved-list'
end

# 검사신청 목록 조회 API
post '/api/get-inspection-requests' do
  debug_log("검사신청 목록 조회 API 호출")
  
  unless session[:logged_in]
    content_type :json
    return { error: '로그인이 필요합니다' }.to_json
  end
  
  begin
    body = request.body.read
    data = JSON.parse(body)
    
    user_level = data['user_level'] || session[:user_info]['permission_level']
    username = data['username'] || session[:user_info]['username']
    
    debug_log("검사신청 목록 조회: #{username} (Level #{user_level})")
    
    # Flask API로 검사신청 목록 요청
    uri = URI("#{FLASK_API_URL}/api/inspection-requests")
    
    # 권한별 필터링 파라미터 설정
    params = {}
    if user_level <= 2
      # Level 1-2: 본인 신청만 조회
      params[:requester] = username
    end
    # Level 3+: 전체 조회 (파라미터 없음)
    
    if params.any?
      uri.query = URI.encode_www_form(params)
    end
    
    debug_log("Flask API 요청: #{uri}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 15
    http.read_timeout = 15
    
    request = Net::HTTP::Get.new(uri)
    if session[:jwt_token]
      request['Authorization'] = "Bearer #{session[:jwt_token]}"
    end
    
    response = http.request(request)
    debug_log("Flask API 응답: #{response.code}")
    
    content_type :json
    if response.code == '200'
      data = JSON.parse(response.body)
      requests = data['requests'] || []
      debug_log("검사신청 목록: #{requests.size}건")
      
      # 응답 데이터 정규화
      normalized_requests = requests.map do |req|
        {
          id: req['id'],
          requester: req['requester'],
          assemblies: req['assemblies'] || [],
          assembly_count: req['assembly_count'] || (req['assemblies'] ? req['assemblies'].length : 0),
          inspection_type: req['inspection_type'],
          inspection_date: req['inspection_date'],
          status: req['status'] || 'pending',
          created_at: req['created_at'] || req['request_date'] || Time.now.strftime('%Y-%m-%d')
        }
      end
      
      {
        success: true,
        requests: normalized_requests,
        count: normalized_requests.size,
        user_level: user_level
      }.to_json
    else
      debug_log("Flask API 오류: #{response.code}")
      { 
        success: false, 
        error: "검사신청 목록을 불러올 수 없습니다 (#{response.code})" 
      }.to_json
    end
    
  rescue JSON::ParserError => e
    debug_log("JSON 파싱 오류: #{e.message}")
    content_type :json
    { success: false, error: "요청 데이터 형식 오류" }.to_json
  rescue => e
    debug_log("검사신청 목록 조회 실패: #{e.message}")
    content_type :json
    { 
      success: false, 
      error: "검사신청 목록 조회 중 오류가 발생했습니다: #{e.message}" 
    }.to_json
  end
end

# 검사신청 상태 업데이트 API
post '/api/update-inspection-status' do
  debug_log("검사신청 상태 업데이트 API 호출")
  
  unless session[:logged_in]
    content_type :json
    return { error: '로그인이 필요합니다' }.to_json
  end
  
  user_level = session[:user_info]['permission_level']
  if user_level < 3
    content_type :json
    return { error: '권한이 부족합니다. Level 3 이상만 가능합니다.' }.to_json
  end
  
  begin
    body = request.body.read
    data = JSON.parse(body)
    
    request_id = data['request_id']
    new_status = data['status']
    
    debug_log("상태 업데이트: ID=#{request_id}, Status=#{new_status}")
    
    unless ['approved', 'confirmed', 'cancelled'].include?(new_status)
      content_type :json
      return { error: '유효하지 않은 상태입니다' }.to_json
    end
    
    # Flask API로 상태 업데이트 요청
    uri = URI("#{FLASK_API_URL}/api/inspection-requests/#{request_id}/status")
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 15
    http.read_timeout = 15
    
    request = Net::HTTP::Put.new(uri)
    request['Content-Type'] = 'application/json'
    if session[:jwt_token]
      request['Authorization'] = "Bearer #{session[:jwt_token]}"
    end
    request.body = {
      status: new_status,
      updated_by: session[:user_info]['username']
    }.to_json
    
    response = http.request(request)
    debug_log("Flask API 상태 업데이트 응답: #{response.code}")
    
    content_type :json
    if response.code == '200'
      result_data = JSON.parse(response.body)
      if result_data['success']
        debug_log("상태 업데이트 성공: #{request_id} -> #{new_status}")
        { 
          success: true, 
          message: '상태가 성공적으로 업데이트되었습니다',
          request_id: request_id,
          new_status: new_status
        }.to_json
      else
        debug_log("상태 업데이트 실패: #{result_data['error']}")
        { error: result_data['error'] || '상태 업데이트에 실패했습니다' }.to_json
      end
    else
      debug_log("Flask API 오류: #{response.code}")
      { error: "상태 업데이트 서버 오류 (#{response.code})" }.to_json
    end
    
  rescue JSON::ParserError => e
    debug_log("JSON 파싱 오류: #{e.message}")
    content_type :json
    { error: "요청 데이터 형식 오류" }.to_json
  rescue => e
    debug_log("상태 업데이트 API 오류: #{e.message}")
    content_type :json
    { error: "상태 업데이트 처리 중 오류가 발생했습니다: #{e.message}" }.to_json
  end
end

# 검사신청 생성 API
post '/api/create-inspection-request' do
  debug_log("검사신청 생성 API 호출")
  
  unless session[:logged_in]
    content_type :json
    return { error: '로그인이 필요합니다' }.to_json
  end
  
  begin
    body = request.body.read
    data = JSON.parse(body)
    
    assemblies = data['assemblies'] || []
    inspection_date = data['inspection_date']
    
    debug_log("검사신청 생성 요청: #{assemblies.size}개 항목, 검사일: #{inspection_date}")
    
    # 각 조립품의 다음 공정 계산 및 검증
    next_processes = []
    assemblies.each do |assembly|
      next_process = get_next_process(assembly)
      if next_process.nil?
        content_type :json
        return { error: "조립품 '#{assembly['name']}'은 모든 공정이 완료되어 검사신청이 불가능합니다." }.to_json
      end
      next_processes << next_process
    end
    
    # 동일 공정 검증
    unique_processes = next_processes.uniq
    if unique_processes.length > 1
      content_type :json
      process_info = unique_processes.map { |p| process_to_korean(p) }.join(', ')
      return { error: "선택된 조립품들의 다음 공정이 다릅니다. 동일한 공정의 조립품만 선택해주세요.\n다음 공정들: #{process_info}" }.to_json
    end
    
    # 공통 다음 공정
    common_next_process = unique_processes.first
    debug_log("공통 다음 공정: #{common_next_process}")
    
    # 검사신청 데이터 준비 (Flask API 형식에 맞춤)
    request_data = {
      assembly_codes: assemblies.map { |assembly| assembly['name'] },
      inspection_type: common_next_process,
      request_date: inspection_date
    }
    
    debug_log("Flask API로 전송할 데이터: #{request_data.to_json}")
    
    # Flask API로 검사신청 전송
    uri = URI("#{FLASK_API_URL}/api/inspection-requests")
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 15
    http.read_timeout = 15
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    if session[:jwt_token]
      request['Authorization'] = "Bearer #{session[:jwt_token]}"
      debug_log("JWT 토큰 설정됨: Bearer #{session[:jwt_token][0..20]}...")
    else
      debug_log("JWT 토큰 없음!")
    end
    request.body = request_data.to_json
    
    response = http.request(request)
    debug_log("Flask API 검사신청 응답: #{response.code}")
    debug_log("Flask API 검사신청 응답 본문: #{response.body}")
    
    content_type :json
    if response.code == '200' || response.code == '201'
      result_data = JSON.parse(response.body)
      debug_log("Flask API 파싱된 응답: #{result_data}")
      if result_data['success']
        debug_log("검사신청 성공: #{assemblies.size}개")
        
        # 검사신청 성공한 항목들을 저장된 리스트에서 제거
        saved_list = session[:saved_list] || []
        assembly_names = assemblies.map { |assembly| assembly['name'] }
        
        # 검사신청된 항목들을 저장된 리스트에서 제거
        session[:saved_list] = saved_list.reject do |item|
          assembly_names.include?(item['name'])
        end
        
        debug_log("저장된 리스트에서 #{assembly_names.join(', ')} 제거 완료")
        debug_log("남은 저장된 리스트: #{session[:saved_list].size}개")
        
        { 
          success: true, 
          message: '검사신청이 성공적으로 생성되었습니다',
          request_id: result_data['request_id'],
          count: assemblies.size
        }.to_json
      else
        debug_log("검사신청 실패: #{result_data['message']}")
        
        # 중복 항목이 있는 경우 상세 메시지 생성 (삭제하지 않고 경고만 표시)
        if result_data['duplicate_items'] && result_data['duplicate_items'].any?
          duplicate_info = result_data['duplicate_items'].map do |item|
            "• #{item['assembly_code']}\n  → 신청자: #{item['existing_requester']}\n  → 신청일: #{item['existing_date']}"
          end.join("\n\n")
          
          debug_log("중복 검사신청 시도: #{result_data['duplicate_items'].map { |item| item['assembly_code'] }.join(', ')}")
          
          error_message = "⚠️ 검사신청 불가\n\n#{result_data['message']}\n\n이미 검사신청된 항목들:\n\n#{duplicate_info}\n\n다른 업체에서 이미 검사신청을 완료한 항목들입니다.\n중복 검사신청은 불가능합니다."
        else
          error_message = result_data['message'] || result_data['error'] || '검사신청 생성에 실패했습니다'
        end
        
        { error: error_message }.to_json
      end
    else
      debug_log("Flask API 오류: #{response.code}, 응답: #{response.body}")
      { error: "검사신청 서버 오류 (#{response.code})" }.to_json
    end
    
  rescue JSON::ParserError => e
    debug_log("JSON 파싱 오류: #{e.message}")
    content_type :json
    { error: "요청 데이터 형식 오류" }.to_json
  rescue => e
    debug_log("검사신청 API 오류: #{e.message}")
    content_type :json
    { error: "검사신청 처리 중 오류가 발생했습니다: #{e.message}" }.to_json
  end
end

# Test endpoint
get '/test' do
  debug_log("Test 엔드포인트 호출")
  content_type :json
  { 
    status: "OK", 
    time: Time.now.to_s, 
    message: "Complete DSHI Dashboard",
    port: 5007,
    logged_in: session[:logged_in] || false,
    user: session[:user_info]&.[]('username') || 'none',
    saved_list_count: (session[:saved_list] || []).size
  }.to_json
end

if __FILE__ == $0
  puts ""
  puts "=" * 60
  puts "🏭 Complete DSHI Dashboard"
  puts "=" * 60
  puts "📍 URL: http://localhost:5007"
  puts "🔄 Full Flow: Login → Search → Multi-select"
  puts "✅ Complete Implementation"
  puts "=" * 60
  puts ""
end