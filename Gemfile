# 호그와트 마법용품점 봇 - Gemfile (휘핑마스토돈 버전)
source 'https://rubygems.org'

# Ruby 버전 명시
ruby '3.0.0'

# 휘핑마스토돈 API 클라이언트
gem 'mastodon-api', '~> 1.1'

# 환경변수 관리
gem 'dotenv', '~> 2.8'

# 구글 시트/드라이브 연동
gem 'google_drive', '~> 3.0'
gem 'googleauth', '~> 1.8'
gem 'google-apis-sheets_v4', '~> 0.28'
gem 'google-apis-drive_v3', '~> 0.39'

# JSON 처리 (Ruby 3.0+ 호환성)
gem 'json', '~> 2.6'

# HTTP 요청 처리
gem 'http', '~> 5.1'
gem 'faraday', '~> 2.7'

# 유틸리티
gem 'nokogiri', '~> 1.15'

# 개발/디버깅용
group :development do
  gem 'pry', '~> 0.14'
  gem 'irb', '~> 1.4'
  gem 'byebug', '~> 11.1'
end

# 테스트용 (선택사항)
group :test do
  gem 'rspec', '~> 3.12'
  gem 'webmock', '~> 3.18'
  gem 'vcr', '~> 6.1'
end
