# -*- coding: utf-8 -*-

# 라이브러리 의존성
require 'sinatra'
require 'webrick'
require 'json'
require 'net/http'
require 'uri'
require 'digest'
require 'rubyXL'

# Flask API 설정
FLASK_API_URL = 'http://203.251.108.199:5001'

# 공정 순서 정의 (FIT_UP → FINAL → ARUP_FINAL → GALV → ARUP_GALV → SHOT → PAINT → ARUP_PAINT)
PROCESS_ORDER = [
  'FIT_UP',
  'FINAL',
  'ARUP_FINAL', 
  'GALV',
  'ARUP_GALV',
  'SHOT',
  'PAINT',
  'ARUP_PAINT'
].freeze

# 세션 시크릿 키
SESSION_SECRET = 'complete-app-session-secret-key-must-be-at-least-64-characters-long-for-security-purposes'