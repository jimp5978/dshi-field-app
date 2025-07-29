#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'sinatra'
require 'net/http'
require 'json'
require 'uri'

# Sinatra 설정
set :port, 3000
set :bind, '0.0.0.0'

class DSHIDashboard
  def initialize
    @python_api_url = "http://localhost:5000"  # Python API 서버 URL (dashboard_api.py)
  end

  def get_dashboard_data
    begin
      # Python API 호출 시도
      uri = URI("#{@python_api_url}/stats")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 5
      http.read_timeout = 10
      
      request = Net::HTTP::Get.new(uri)
      request['Content-Type'] = 'application/json'
      
      response = http.request(request)
      
      if response.code == '200'
        JSON.parse(response.body)
      else
        get_mock_data
      end
    rescue => e
      puts "Python API 연결 실패: #{e.message}"
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

# 라우트 정의
get '/' do
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

# 기본 HTML 템플릿
__END__

@@index
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DSHI RPA 대시보드</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background-color: #f5f5f5;
            color: #333;
        }
        
        .header {
            background: linear-gradient(135deg, #2c3e50, #3498db);
            color: white;
            padding: 2rem 0;
            text-align: center;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        
        .header h1 {
            font-size: 2.5rem;
            margin-bottom: 0.5rem;
        }
        
        .header p {
            font-size: 1.1rem;
            opacity: 0.9;
        }
        
        .container {
            max-width: 1200px;
            margin: 2rem auto;
            padding: 0 1rem;
        }
        
        .dashboard-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 2rem;
            margin-bottom: 2rem;
        }
        
        .card {
            background: white;
            border-radius: 12px;
            padding: 1.5rem;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            transition: transform 0.2s ease;
        }
        
        .card:hover {
            transform: translateY(-2px);
        }
        
        .card h3 {
            color: #2c3e50;
            margin-bottom: 1rem;
            font-size: 1.3rem;
        }
        
        .metric {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 0.75rem 0;
            border-bottom: 1px solid #eee;
        }
        
        .metric:last-child {
            border-bottom: none;
        }
        
        .metric-name {
            font-weight: 500;
            color: #555;
        }
        
        .metric-value {
            font-weight: 700;
            font-size: 1.1rem;
            color: #2c3e50;
        }
        
        .progress-bar {
            width: 100%;
            height: 8px;
            background-color: #ecf0f1;
            border-radius: 4px;
            overflow: hidden;
            margin-top: 0.5rem;
        }
        
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #3498db, #2ecc71);
            border-radius: 4px;
            transition: width 0.3s ease;
        }
        
        .status-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 0.5rem 0;
        }
        
        .status-badge {
            padding: 0.25rem 0.75rem;
            border-radius: 20px;
            font-size: 0.9rem;
            font-weight: 600;
        }
        
        .status-완료 { background-color: #d5f4e6; color: #27ae60; }
        .status-진행중 { background-color: #daeaf6; color: #3498db; }
        .status-대기 { background-color: #fef9e7; color: #f39c12; }
        .status-지연 { background-color: #fadbd8; color: #e74c3c; }
        
        .issue-item {
            padding: 1rem;
            margin-bottom: 1rem;
            border-left: 4px solid #3498db;
            background-color: #f8f9fa;
            border-radius: 0 8px 8px 0;
        }
        
        .issue-high {
            border-left-color: #e74c3c;
        }
        
        .issue-medium {
            border-left-color: #f39c12;
        }
        
        .issue-title {
            font-weight: 600;
            margin-bottom: 0.5rem;
            color: #2c3e50;
        }
        
        .issue-description {
            color: #666;
            font-size: 0.9rem;
            margin-bottom: 0.5rem;
        }
        
        .issue-time {
            font-size: 0.8rem;
            color: #999;
        }
        
        .summary-card {
            grid-column: 1 / -1;
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
        }
        
        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
        }
        
        .summary-item {
            text-align: center;
            padding: 1rem;
        }
        
        .summary-number {
            font-size: 2.5rem;
            font-weight: 700;
            margin-bottom: 0.5rem;
        }
        
        .summary-label {
            opacity: 0.9;
            font-size: 1rem;
        }
        
        .footer {
            text-align: center;
            padding: 2rem;
            color: #666;
            border-top: 1px solid #eee;
            margin-top: 3rem;
        }
        
        @media (max-width: 768px) {
            .header h1 {
                font-size: 2rem;
            }
            
            .container {
                margin: 1rem auto;
                padding: 0 0.5rem;
            }
            
            .dashboard-grid {
                grid-template-columns: 1fr;
                gap: 1rem;
            }
            
            .summary-grid {
                grid-template-columns: repeat(2, 1fr);
            }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🏭 DSHI RPA 대시보드</h1>
        <p>동성중공업 현장 관리 시스템 - 실시간 모니터링</p>
    </div>

    <div class="container">
        <!-- 전체 요약 -->
        <div class="dashboard-grid">
            <div class="card summary-card">
                <h3>📊 전체 현황</h3>
                <div class="summary-grid">
                    <div class="summary-item">
                        <div class="summary-number"><%= @data['total_assemblies'] %></div>
                        <div class="summary-label">총 조립품</div>
                    </div>
                    <div class="summary-item">
                        <div class="summary-number"><%= @data['monthly_progress']['completed'] %></div>
                        <div class="summary-label">완료</div>
                    </div>
                    <div class="summary-item">
                        <div class="summary-number"><%= @data['monthly_progress']['remaining'] %></div>
                        <div class="summary-label">잔여</div>
                    </div>
                    <div class="summary-item">
                        <div class="summary-number"><%= sprintf("%.1f", @data['monthly_progress']['percentage']) %>%</div>
                        <div class="summary-label">전체 진행률</div>
                    </div>
                </div>
            </div>
        </div>

        <div class="dashboard-grid">
            <!-- 공정별 완료율 -->
            <div class="card">
                <h3>🔧 7단계 공정 완료율</h3>
                <% @data['process_completion'].each do |process, rate| %>
                <div class="metric">
                    <span class="metric-name"><%= process %></span>
                    <span class="metric-value"><%= sprintf("%.1f", rate) %>%</span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: <%= rate %>%"></div>
                </div>
                <% end %>
            </div>

            <!-- 상태별 분포 -->
            <div class="card">
                <h3>📈 상태별 분포</h3>
                <% @data['status_distribution'].each do |status, count| %>
                <div class="status-item">
                    <span class="metric-name"><%= status %></span>
                    <span class="status-badge status-<%= status %>"><%= count %>개</span>
                </div>
                <% end %>
            </div>
        </div>

        <!-- 이슈 및 알림 -->
        <div class="card">
            <h3>⚠️ 주요 이슈 및 알림 (<%= @data['issues'].length %>건)</h3>
            <% @data['issues'].each do |issue| %>
            <div class="issue-item issue-<%= issue['priority'] %>">
                <div class="issue-title"><%= issue['title'] %></div>
                <div class="issue-description"><%= issue['description'] %></div>
                <div class="issue-time">📅 <%= issue['time'] %></div>
            </div>
            <% end %>
        </div>
    </div>

    <div class="footer">
        <p>DSHI RPA 시스템 | 마지막 업데이트: <%= Time.now.strftime("%Y-%m-%d %H:%M:%S") %></p>
        <p>포트 3000 (Sinatra) ↔ Python API 연동</p>
    </div>

    <script>
        // 5분마다 자동 새로고침
        setTimeout(function() {
            location.reload();
        }, 300000);
        
        // 페이지 로드시 실시간 시간 업데이트
        setInterval(function() {
            document.querySelector('.footer p').innerHTML = 
                'DSHI RPA 시스템 | 마지막 업데이트: ' + new Date().toLocaleString('ko-KR');
        }, 1000);
    </script>
</body>
</html>