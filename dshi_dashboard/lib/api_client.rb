require_relative 'auth_helper'

class ApiClient
  def self.flask_api_url
    AuthHelper.flask_api_url
  end

  # 조립품 검색 (끝 3자리 검색)
  def self.search_assemblies(session, search_term)
    AuthHelper.authenticated_request(:get, '/api/assemblies', session, { 
      search: search_term,
      limit: 100  # 검색 결과 제한
    })
  end

  # 특정 조립품 상세 정보 조회
  def self.get_assembly(session, assembly_id)
    AuthHelper.authenticated_request(:get, "/api/assembly/#{assembly_id}", session)
  end

  # 모든 조립품 목록 조회 (페이징)
  def self.list_assemblies(session, page = 1, per_page = 50)
    AuthHelper.authenticated_request(:get, '/api/assemblies', session, {
      page: page,
      per_page: per_page
    })
  end

  # 검사신청 생성
  def self.create_inspection_request(session, params)
    # params 예시:
    # {
    #   assemblies: ['RF-EX1-M2-SE-SA201', 'RF-EX1-M2-SE-SA202'],
    #   inspection_type: 'GALV',
    #   request_date: '2025-07-22'
    # }
    AuthHelper.authenticated_request(:post, '/api/inspection_requests', session, params)
  end

  # 검사신청 목록 조회
  def self.list_inspection_requests(session, filters = {})
    AuthHelper.authenticated_request(:get, '/api/inspection_requests', session, filters)
  end

  # 검사신청 상태 변경 (승인, 확정, 취소)
  def self.update_inspection_request(session, request_id, action, data = {})
    # action: 'approve', 'confirm', 'cancel'
    AuthHelper.authenticated_request(:put, "/api/inspection_requests/#{request_id}/#{action}", session, data)
  end

  # 사용자 관리 (Level 5+ 전용)
  def self.list_users(session)
    AuthHelper.authenticated_request(:get, '/api/admin/users', session)
  end

  def self.create_user(session, user_data)
    AuthHelper.authenticated_request(:post, '/api/admin/users', session, user_data)
  end

  def self.update_user(session, user_id, user_data)
    AuthHelper.authenticated_request(:put, "/api/admin/users/#{user_id}", session, user_data)
  end

  def self.delete_user(session, user_id)
    AuthHelper.authenticated_request(:delete, "/api/admin/users/#{user_id}", session)
  end

  # 통계 데이터 조회
  def self.get_dashboard_stats(session)
    AuthHelper.authenticated_request(:get, '/api/dashboard/stats', session)
  end

  # 공정별 진행률 조회
  def self.get_process_progress(session)
    AuthHelper.authenticated_request(:get, '/api/dashboard/process_progress', session)
  end

  # 회사별 통계 조회
  def self.get_company_stats(session)
    AuthHelper.authenticated_request(:get, '/api/dashboard/company_stats', session)
  end

  # 조립품 공정 상태 업데이트
  def self.update_assembly_process(session, assembly_id, process_data)
    # process_data 예시:
    # {
    #   fit_up_date: '2025-07-20',
    #   final_date: '2025-07-21',
    #   arup_final_date: '2025-07-22'
    # }
    AuthHelper.authenticated_request(:put, "/api/assembly/#{assembly_id}/process", session, process_data)
  end

  # 대량 조립품 공정 업데이트 (Excel 업로드용)
  def self.bulk_update_assemblies(session, updates_array)
    # updates_array 예시:
    # [
    #   {
    #     assembly: 'RF-EX1-M2-SE-SA201',
    #     fit_up_date: '2025-07-20',
    #     final_date: '2025-07-21'
    #   },
    #   ...
    # ]
    AuthHelper.authenticated_request(:post, '/api/assemblies/bulk_update', session, {
      updates: updates_array
    })
  end

  # 대량 검사신청 (Excel 업로드용)
  def self.bulk_create_inspection_requests(session, requests_array)
    # requests_array 예시:
    # [
    #   {
    #     assembly: 'RF-EX1-M2-SE-SA201',
    #     inspection_type: 'GALV',
    #     request_date: '2025-07-22'
    #   },
    #   ...
    # ]
    AuthHelper.authenticated_request(:post, '/api/inspection_requests/bulk_create', session, {
      requests: requests_array
    })
  end

  # Excel 다운로드용 데이터 조회
  def self.export_assemblies(session, filters = {})
    AuthHelper.authenticated_request(:get, '/api/export/assemblies', session, filters)
  end

  def self.export_inspection_requests(session, filters = {})
    AuthHelper.authenticated_request(:get, '/api/export/inspection_requests', session, filters)
  end

  # 사용자별 검사신청 내역 조회 (Level 1용)
  def self.get_my_inspection_requests(session)
    AuthHelper.authenticated_request(:get, '/api/my/inspection_requests', session)
  end

  # 시스템 헬스 체크
  def self.health_check
    begin
      uri = URI("#{flask_api_url}/health")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 5
      http.read_timeout = 5
      
      response = http.request(Net::HTTP::Get.new(uri))
      
      if response.code == '200'
        data = JSON.parse(response.body)
        {
          success: true,
          status: data['status'],
          timestamp: data['timestamp']
        }
      else
        {
          success: false,
          error: "HTTP 에러: #{response.code}"
        }
      end
    rescue => e
      {
        success: false,
        error: "서버 연결 실패: #{e.message}"
      }
    end
  end

  # 에러 처리를 위한 헬퍼 메서드
  def self.handle_api_response(result)
    if result[:success]
      result[:data]
    else
      puts "API 에러: #{result[:error]}"
      nil
    end
  end

  # 페이징 정보 추출
  def self.extract_pagination_info(response_data)
    if response_data && response_data['pagination']
      {
        current_page: response_data['pagination']['page'],
        per_page: response_data['pagination']['per_page'],
        total_pages: response_data['pagination']['total_pages'],
        total_items: response_data['pagination']['total']
      }
    else
      nil
    end
  end
end