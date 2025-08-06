"""
공통 유틸리티 함수들
"""
import json
import datetime
import decimal

class CustomJSONEncoder(json.JSONEncoder):
    """JSON 직렬화를 위한 커스텀 인코더"""
    def default(self, obj):
        if isinstance(obj, (datetime.datetime, datetime.date)):
            return obj.isoformat()
        elif isinstance(obj, decimal.Decimal):
            return float(obj)
        elif isinstance(obj, bytes):
            return obj.decode('utf-8')
        return super().default(obj)