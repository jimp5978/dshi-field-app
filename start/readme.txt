  1. start_flask_server.bat - Flask API 서버 시작 (포트 5001)
  2. start_ruby_server.bat - Sinatra 웹 서버 시작 (포트 5008)
  3. start_both_servers.bat - 두 서버를 별도 창에서 동시 실행
  4. check_servers.bat - 서버 상태 및 포트 사용 확인
  5. stop_all_servers.bat - 모든 Python/Ruby 프로세스 종료
  6. view_logs.bat - 로그 파일 보기 (Flask/Ruby 디버그 로그)
  7. cleanup_logs - 로그 정리


로그 정리 메뉴 옵션

  1번: Clear all logs (모든 로그 삭제)

  - Flask 디버그 로그 (flask_debug.log) 완전 삭제
  - Ruby 디버그 로그 (test_app\debug.log) 완전 삭제
  - 결과: 로그 파일이 비워짐 (용량 0KB)

  2번: Archive logs (백업 후 삭제)

  - 현재 로그를 날짜시간 이름으로 백업 저장
  - 예: flask_debug_20250802_143015.log
  - 백업 후 원본 로그 파일 비우기
  - 결과: 기존 로그는 보관, 새 로그는 깨끗하게 시작

  3번: Clear old logs (최근 1000줄만 유지)

  - 각 로그 파일에서 마지막 1000줄만 남기고 삭제
  - 결과: 최신 로그만 유지하면서 파일 크기 줄임

  4번: View log sizes (로그 크기 확인)

  - 현재 로그 파일들의 용량 표시
  - 예: Flask debug log: 2048576 bytes

  5번: Exit (종료)

  💡 추천 사용법

  - 개발 중: 3번 (최근 1000줄 유지) - 디버깅에 필요한 최신 로그 유지
  - 정기 정리: 2번 (백업 후 삭제) - 중요한 로그는 보관하면서 정리
  - 긴급 정리: 1번 (완전 삭제) - 용량 부족 시 즉시 정리