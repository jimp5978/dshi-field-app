import pymysql.cursors

try:
    conn = pymysql.connect(
        host='localhost',
        user='field_app_user',
        password='F!eldApp_Pa$$w0rd_2025#',
        database='field_app_db',
        cursorclass=pymysql.cursors.DictCursor
    )
    
    cursor = conn.cursor()
    cursor.execute('SELECT username, permission_level FROM users')
    users = cursor.fetchall()
    
    print('현재 사용자:')
    for user in users:
        print(f'{user["username"]} (Level {user["permission_level"]})')
    
    conn.close()
    print('조회 완료')
    
except Exception as e:
    print(f'오류: {e}')
