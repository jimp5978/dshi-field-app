#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os

# 환경 감지
def get_environment():
    """현재 환경을 감지합니다 (home/company)"""
    # 환경변수로 설정하거나, 특정 파일 존재 여부로 판단
    if os.getenv('WORK_ENV') == 'home':
        return 'home'
    else:
        return 'company'

# 환경별 DB 설정
def get_db_config():
    env = get_environment()
    
    if env == 'home':
        # 집에서 작업할 때 - 회사 DB에 원격 접속
        return {
            'host': 'company_ip_address',  # 회사 IP로 변경 필요
            'user': 'field_app_user',
            'password': 'dshi2025#',
            'database': 'field_app_db',
            'charset': 'utf8mb4',
            'port': 3306
        }
    else:
        # 회사에서 작업할 때 - 로컬 DB
        return {
            'host': 'localhost',
            'user': 'field_app_user', 
            'password': 'dshi2025#',
            'database': 'field_app_db',
            'charset': 'utf8mb4'
        }

# Flask 서버 설정
def get_server_config():
    env = get_environment()
    
    if env == 'home':
        return {
            'host': '0.0.0.0',
            'port': 5001,
            'debug': True
        }
    else:
        return {
            'host': '0.0.0.0',
            'port': 5001, 
            'debug': True
        }