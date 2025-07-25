# Sinatra 웹 애플리케이션 컨테이너
FROM ruby:3.1-slim

# 작업 디렉토리 설정
WORKDIR /app

# 시스템 패키지 업데이트 및 필요한 패키지 설치
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Gemfile과 Gemfile.lock 복사
COPY Gemfile ./
COPY Gemfile.lock ./

# Ruby 의존성 설치
RUN bundle install

# 소스코드 복사
COPY . .

# 환경변수 설정
ENV RACK_ENV=development
ENV SINATRA_HOST=0.0.0.0
ENV SINATRA_PORT=5007

# 포트 노출
EXPOSE 5007

# 헬스체크 추가
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5007/health || exit 1

# 실행 명령
CMD ["bundle", "exec", "puma", "-p", "5007", "-e", "development", "config.ru"]