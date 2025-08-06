"""
데이터베이스 연결 관련 유틸리티
"""
import mysql.connector
from mysql.connector import Error
from config_env import get_db_config

DB_CONFIG = get_db_config()

def get_db_connection():
    """데이터베이스 연결 함수"""
    try:
        connection = mysql.connector.connect(**DB_CONFIG)
        return connection
    except Error as e:
        print(f"데이터베이스 연결 오류: {e}")
        return None