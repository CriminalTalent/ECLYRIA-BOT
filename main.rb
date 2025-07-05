require 'dotenv'
Dotenv.load('.env')
require_relative 'mastodon_client'
require_relative 'command_parser'

puts "ECLYRIA 마법용품점 기동 완료!"
puts "BASE_URL: #{ENV['MASTODON_BASE_URL']}"
puts "TOKEN 시작: #{ENV['MASTODON_TOKEN'][0..10]}..." if ENV['MASTODON_TOKEN']

# 환경변수 디버깅
puts "\n환경변수 확인:"
puts "  MASTODON_BASE_URL: #{ENV['MASTODON_BASE_URL']}"
puts "  MASTODON_TOKEN: #{ENV['MASTODON_TOKEN'] ? '설정됨' : '없음'}"
puts "  GOOGLE_CREDENTIALS_PATH: #{ENV['GOOGLE_CREDENTIALS_PATH']}"
puts "  GOOGLE_SHEET_ID: #{ENV['GOOGLE_SHEET_ID']}"

# 구글 시트 설정 확인
puts "\n구글 시트 설정 확인 중..."
google_credentials = ENV['GOOGLE_CREDENTIALS_PATH']
google_sheet_id = ENV['GOOGLE_SHEET_ID']

if google_credentials && google_sheet_id
  puts "   인증 파일: #{google_credentials}"
  
  if File.exist?(google_credentials)
    puts "   인증 파일 존재 확인"
  else
    puts "   인증 파일 없음: #{google_credentials}"
    puts "      Google Cloud Console에서 서비스 계정 JSON 키를 다운로드하세요"
  end
  
  puts "   시트 ID: #{google_sheet_id[0..10]}..."
else
  puts "   구글 시트 설정이 .env 파일에 없습니다"
  puts "      GOOGLE_CREDENTIALS_PATH와 GOOGLE_SHEET_ID를 설정하세요"
end

# 마스토돈 연결 테스트
puts "\n마스토돈 연결 테스트 중..."
begin
  unless MastodonClient.test_connection
    puts "마스토돈 연결 실패! .env 파일의 설정을 확인하세요"
    exit 1
  end
rescue => e
  puts "마스토돈 연결 오류: #{e.message}"
  puts "Mastodon gem 설치를 확인해주세요: gem install mastodon"
  exit 1
end

puts "\nECLYRIA 마법용품점 개점!"
puts "Ctrl+C로 종료"