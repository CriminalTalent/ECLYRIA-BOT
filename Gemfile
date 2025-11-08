# Gemfile for Mastodon Bots (Shop / Professor / Rumor)
# ============================================
source 'https://rubygems.org'
ruby '3.2.3'

# --- Core dependencies ---
gem 'dotenv', '~> 3.1'                    # .env 환경변수 로더
gem 'json', '~> 2.7'                      # JSON 파서
gem 'activesupport', '~> 7.2', require: 'active_support/all'  # 시간/유틸 보조

# --- HTTP / Network Layer ---
gem 'http', '~> 5.2'                      # HTTP 클라이언트 (mastodon-api 대체)
gem 'faraday', '~> 2.14'                  # Google API 의존
gem 'nokogiri', '~> 1.18'                 # HTML/XML 파서

# --- Google Sheets API ---
gem 'googleauth', '~> 1.15'               # OAuth 인증
gem 'google-apis-sheets_v4', '~> 0.45'    # 최신 Sheets API (0.26 → 0.45로 업데이트)

# --- Utility (권장) ---
gem 'time', '~> 0.4'                      # Ruby 3.x에서 시간 포맷 안정성 개선
