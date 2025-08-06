source 'https://rubygems.org'

ruby '3.0.0'

# Mastodon API
gem 'mastodon-api', '~> 1.1'

# 환경변수
gem 'dotenv', '~> 2.8'

# Google Sheets 연동
gem 'google_drive', '~> 3.0'
gem 'googleauth', '~> 1.8'
gem 'google-apis-sheets_v4', '~> 0.28'
gem 'google-apis-drive_v3', '~> 0.39'

# HTTP 요청 (하나만 사용해도 충분)
gem 'faraday', '~> 2.7'

# HTML 파싱 (멘션 본문 정리용)
gem 'nokogiri', '~> 1.15'

group :development do
  gem 'pry', '~> 0.14'
  gem 'irb', '~> 1.4'
  gem 'byebug', '~> 11.1'
end

group :test do
  gem 'rspec', '~> 3.12'
  gem 'webmock', '~> 3.18'
  gem 'vcr', '~> 6.1'
end
