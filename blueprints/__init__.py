"""
Blueprint 패키지 초기화 모듈
"""

from .auth import auth_bp
from .assembly import assembly_bp  
from .inspection import inspection_bp
from .admin import admin_bp
from .dashboard import dashboard_bp
from .upload import upload_bp
from .saved_list import saved_list_bp

def register_blueprints(app):
    """모든 블루프린트를 앱에 등록"""
    app.register_blueprint(auth_bp, url_prefix='/api')
    app.register_blueprint(assembly_bp, url_prefix='/api')
    app.register_blueprint(inspection_bp, url_prefix='/api')
    app.register_blueprint(admin_bp, url_prefix='/api')
    app.register_blueprint(dashboard_bp, url_prefix='/api')
    app.register_blueprint(upload_bp, url_prefix='/api')
    app.register_blueprint(saved_list_bp, url_prefix='/api')