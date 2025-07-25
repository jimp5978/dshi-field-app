# config.ru - Sinatra 애플리케이션 설정
require_relative 'app'

# 정적 파일 서빙 설정
use Rack::Static, :urls => ["/css", "/js", "/images"], :root => "public"

# CORS 설정 (개발 환경용)
use Rack::Cors do
  allow do
    origins '*'
    resource '*', headers: :any, methods: [:get, :post, :put, :delete, :options]
  end
end if defined?(Rack::Cors)

# 애플리케이션 실행
run Sinatra::Application