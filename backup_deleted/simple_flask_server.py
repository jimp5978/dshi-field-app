# -*- coding: utf-8 -*-
import sqlite3
import json
from datetime import datetime
from flask import Flask, jsonify, request

app = Flask(__name__)

# SQLite 데이터베이스 초기화
def init_sqlite():
    conn = sqlite3.connect('dshi_test.db')
    c = conn.cursor()
    
    # 테이블 생성
    c.execute('''CREATE TABLE IF NOT EXISTS assemblies
                 (id INTEGER PRIMARY KEY,
                  assembly_code TEXT UNIQUE,
                  zone TEXT,
                  item TEXT,
                  fit_up_date TEXT,
                  nde_date TEXT,
                  vidi_date TEXT,
                  galv_date TEXT,
                  shot_date TEXT,
                  paint_date TEXT,
                  packing_date TEXT)''')
    
    c.execute('''CREATE TABLE IF NOT EXISTS users
                 (id INTEGER PRIMARY KEY,
                  username TEXT UNIQUE,
                  password_hash TEXT,
                  full_name TEXT,
                  permission_level INTEGER)''')
    
    # 테스트 데이터 삽입
    test_assemblies = [
        ('RF-031-M2-SE-SD589', 'Secondary_Truss', 'RF Beam', '2024-01-15', '2024-01-20', None, None, None, None, None),
        ('TN1-001-B1-SE-SD123', 'Main_Truss', 'TN Beam', '2024-01-10', '2024-01-12', '2024-01-15', None, None, None, None),
        ('CB-045-C3-SE-SD456', 'Cable_Bridge', 'CB Support', '2024-01-05', '2024-01-08', '2024-01-12', '2024-01-18', None, None, None)
    ]
    
    for assembly in test_assemblies:
        try:
            c.execute('INSERT OR IGNORE INTO assemblies (assembly_code, zone, item, fit_up_date, nde_date, vidi_date, galv_date, shot_date, paint_date, packing_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', assembly)
        except:
            pass
    
    test_users = [
        ('admin', 'admin123', '관리자', 5),
        ('test_level1', 'test123', '외부업체1', 1),
        ('test_level3', 'test123', 'DSHI 현장직원', 3)
    ]
    
    for user in test_users:
        try:
            c.execute('INSERT OR IGNORE INTO users (username, password_hash, full_name, permission_level) VALUES (?, ?, ?, ?)', user)
        except:
            pass
    
    conn.commit()
    conn.close()
    print("SQLite 데이터베이스 초기화 완료!")

@app.route('/')
def home():
    return jsonify({
        "message": "DSHI Field Pad API 서버 (SQLite 버전)",
        "version": "1.0.0-test",
        "status": "running"
    })

@app.route('/api/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password_hash = data.get('password_hash')
    
    conn = sqlite3.connect('dshi_test.db')
    c = conn.cursor()
    
    c.execute('SELECT * FROM users WHERE username=? AND password_hash=?', (username, password_hash))
    user = c.fetchone()
    conn.close()
    
    if user:
        return jsonify({
            'success': True,
            'message': '로그인 성공',
            'user': {
                'id': user[0],
                'username': user[1],
                'full_name': user[3],
                'permission_level': user[4]
            }
        })
    else:
        return jsonify({
            'success': False,
            'message': '로그인 실패'
        }), 401

@app.route('/api/search_assembly', methods=['POST'])
def search_assembly():
    data = request.get_json()
    search_query = data.get('search_query', '').upper()
    
    conn = sqlite3.connect('dshi_test.db')
    c = conn.cursor()
    
    c.execute('SELECT * FROM assemblies WHERE UPPER(assembly_code) LIKE ?', (f'%{search_query}%',))
    results = c.fetchall()
    conn.close()
    
    assemblies = []
    for row in results:
        assembly = {
            'assembly_code': row[1],
            'zone': row[2], 
            'item': row[3],
            'fit_up_date': row[4],
            'nde_date': row[5],
            'vidi_date': row[6],
            'galv_date': row[7],
            'shot_date': row[8],
            'paint_date': row[9],
            'packing_date': row[10],
            'next_process': get_next_process(row)
        }
        assemblies.append(assembly)
    
    return jsonify({
        'success': True,
        'results': assemblies,
        'total_count': len(assemblies)
    })

def get_next_process(assembly_row):
    processes = ['fit_up_date', 'nde_date', 'vidi_date', 'galv_date', 'shot_date', 'paint_date', 'packing_date']
    process_names = ['Fit-up', 'NDE', 'VIDI', 'GALV', 'SHOT', 'PAINT', 'PACKING']
    
    for i, date_value in enumerate(assembly_row[4:11]):  # 날짜 컬럼들
        if date_value is None:
            return process_names[i]
    return None

if __name__ == '__main__':
    print("DSHI Field Pad 테스트 서버 (SQLite 버전) 시작...")
    init_sqlite()
    print("서버가 http://localhost:5000 에서 실행됩니다.")
    print("테스트 계정: admin/admin123")
    app.run(host='0.0.0.0', port=5000, debug=True)
