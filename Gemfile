# ============================================
# Gemfile for Mastodon Bots (Shop / Professor / Rumor)
# ============================================
source 'https://rubygems.org'
ruby '3.2.3'

# --- Core dependencies ---
gem 'dotenv', '~> 3.1'                    # .env 환경변수 로더
gem 'json', '~> 2.7'                      # JSON 파서
gem 'activesupport', '~> 7.1', require: 'active_support/all'  # 시간/유틸 보조

# --- Mastodon API (Streaming + REST) ---
# 1.1.0은 Faraday 2.x 호환 + Streaming 지원 마지막 안정판
gem 'mastodon-api', '~> 1.1', require: 'mastodon'

# --- Google Sheets API ---
gem 'googleauth', '~> 1.9'                # OAuth 인증
gem 'google-apis-sheets_v4', '~> 0.26'    # Google Sheets v4 API

# --- HTTP / Network Layer ---
gem 'faraday', '~> 2.7'                   # HTTP 클라이언트
gem 'nokogiri', '~> 1.15'                 # HTML/XML 파서

# --- Utility (권장) ---
gem 'time', '~> 0.2'                      # Ruby 3.x에서 시간 포맷 안정성 개선
