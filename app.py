"""
DSHI Field Pad Flask Server - Flask CLI 지원 버전
"""
import datetime
import logging
from flask import Flask, jsonify
from flask_cors import CORS

# Utils 모듈 임포트
from utils.common import CustomJSONEncoder
from config_env import get_server_config

# Blueprint 모듈 임포트
from blueprints import register_blueprints

def create_app():
    """Flask 애플리케이션 팩토리"""
    # Flask 앱 생성 및 설정
    app = Flask(__name__)
    CORS(app)

    # JSON 직렬화 설정
    app.json_encoder = CustomJSONEncoder

    # JWT 설정
    app.config['SECRET_KEY'] = 'dshi-field-pad-secret-key-2025'

    # 디버그 로깅 설정
    logging.basicConfig(
        level=logging.DEBUG,
        format='🐛 DEBUG [%(asctime)s]: %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S',
        handlers=[
            logging.FileHandler('flask_debug.log', encoding='utf-8'),
            logging.StreamHandler()
        ]
    )

    # 모든 블루프린트 등록
    register_blueprints(app)

    # 기본 라우트들
    @app.route('/')
    def home():
        """루트 경로 - 서버 상태 확인"""
        return jsonify({
            'status': 'ok',
            'message': 'DSHI Field Pad Server is running (Blueprint Structure)',
            'timestamp': datetime.datetime.now().isoformat(),
            'structure': 'blueprints',
            'version': '2.0'
        })

    @app.route('/api/health', methods=['GET'])
    def health_check():
        """서버 상태 확인"""
        return jsonify({
            'status': 'ok',
            'message': 'DSHI Field Pad Server is running (Blueprint Structure)',
            'timestamp': datetime.datetime.now().isoformat(),
            'structure': 'blueprints',
            'version': '2.0'
        })

    return app

# Flask CLI와 직접 실행 모두 지원
app = create_app()

if __name__ == '__main__':
    SERVER_CONFIG = get_server_config()
    print("DSHI Field Pad Server (Blueprint Structure) starting...")
    print(f"Server URL: http://{SERVER_CONFIG['host']}:{SERVER_CONFIG['port']}")
    print("Blueprint Structure:")
    print("  - Auth: /api/login")
    print("  - Assembly: /api/assemblies, /api/assemblies/search")
    print("  - Inspection: /api/inspection-requests, /api/inspection-management")
    print("  - Admin: /api/admin/users")
    print("  - Dashboard: /api/dashboard-data")
    print("  - Upload: /api/upload-excel, /api/upload-assembly-codes")
    print("  - Saved List: /api/saved-list")
    app.run(**SERVER_CONFIG)