require 'jwt'
require 'net/http'
require 'json'
require 'uri'

class AuthHelper
  def self.flask_api_url
    'http://203.251.108.199:5001'  # Flask API 서버 URL (실제 운영 서버)
  end

  # Flask API의 /api/login 엔드포인트를 통한 로그인
  def self.login(username, password)
    begin
      uri = URI("#{flask_api_url}/api/login")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 10
      http.read_timeout = 10
      
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = {
        username: username,
        password_hash: password  # Flask API에서는 이미 해시된 패스워드를 기대
      }.to_json
      
      response = http.request(request)
      
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
        error: '서버 연결 실패'
      }
    end
  end

  # JWT 토큰 검증 (로컬에서 검증)
  def self.verify_token(token)
    begin
      # JWT 시크릿키는 Flask API와 동일해야 함 (실제로는 환경변수에서 가져와야 함)
      secret_key = 'your-super-secret-key-change-this-in-production'
      
      decoded_token = JWT.decode(token, secret_key, true, { algorithm: 'HS256' })
      payload = decoded_token[0]
      
      # 토큰 만료 시간 확인
      if payload['exp'] && Time.now.to_i > payload['exp']
        {
          success: false,
          error: '토큰이 만료되었습니다'
        }
      else
        {
          success: true,
          user: {
            'user_id' => payload['user_id'],
            'username' => payload['username'],
            'permission_level' => payload['permission_level']
          }
        }
      end
    rescue JWT::DecodeError => e
      {
        success: false,
        error: '유효하지 않은 토큰'
      }
    rescue => e
      {
        success: false,
        error: '토큰 검증 실패'
      }
    end
  end

  # 세션에서 사용자 정보 가져오기
  def self.current_user(session)
    return nil unless session[:jwt_token]
    
    result = verify_token(session[:jwt_token])
    return result[:user] if result[:success]
    
    nil
  end

  # 권한 레벨 확인
  def self.has_permission?(session, required_level)
    user = current_user(session)
    return false unless user
    
    user['permission_level'].to_i >= required_level.to_i
  end

  # 세션에서 로그아웃
  def self.logout(session)
    session.delete(:jwt_token)
    session.delete(:user_info)
  end

  # Flask API 호출을 위한 인증된 HTTP 요청
  def self.authenticated_request(method, endpoint, session, params = {})
    token = session[:jwt_token]
    return { success: false, error: '인증되지 않은 요청' } unless token

    begin
      uri = URI("#{flask_api_url}#{endpoint}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 10
      http.read_timeout = 30

      case method.to_s.upcase
      when 'GET'
        uri.query = URI.encode_www_form(params) if params.any?
        request = Net::HTTP::Get.new(uri)
      when 'POST'
        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request.body = params.to_json
      when 'PUT'
        request = Net::HTTP::Put.new(uri)
        request['Content-Type'] = 'application/json'
        request.body = params.to_json
      when 'DELETE'
        request = Net::HTTP::Delete.new(uri)
      else
        return { success: false, error: '지원하지 않는 HTTP 메서드' }
      end

      request['Authorization'] = "Bearer #{token}"
      
      response = http.request(request)
      
      if response.code == '200'
        {
          success: true,
          data: JSON.parse(response.body)
        }
      else
        {
          success: false,
          error: "HTTP 에러: #{response.code}",
          response_body: response.body
        }
      end
    rescue => e
      puts "API 요청 실패: #{e.message}"
      {
        success: false,
        error: 'API 서버 연결 실패'
      }
    end
  end
end