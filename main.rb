# ============================================
# main.rb (Shop Bot - RateLimit 완전 안정화 버전)
# ============================================
require 'bundler/setup'
require 'dotenv'
require 'time'
require 'json'
require 'ostruct'
require 'google/apis/sheets_v4'
require 'googleauth'
require_relative 'mastodon_client'
require_relative 'sheet_manager'
require_relative 'command_parser'
require 'net/http'

Dotenv.load('.env')

# 환경 변수 검증
required_envs = %w[MASTODON_BASE_URL MASTODON_TOKEN GOOGLE_SHEET_ID GOOGLE_APPLICATION_CREDENTIALS]
missing = required_envs.select { |v| ENV[v].nil? || ENV[v].strip.empty? }
if missing.any?
  missing.each { |v| puts "[환경변수 누락] #{v}" }
  puts "[오류] .env 파일 확인 필요"
  exit 1
end

BASE_URL        = ENV['MASTODON_BASE_URL']
TOKEN           = ENV['MASTODON_TOKEN']
SHEET_ID        = ENV['GOOGLE_SHEET_ID']
CREDENTIAL_PATH = ENV['GOOGLE_APPLICATION_CREDENTIALS']
LAST_ID_FILE    = 'last_mention_id.txt'

puts "[상점봇] 실행 시작 (#{Time.now.strftime('%H:%M:%S')})"

# Google Sheets 연결
begin
  scopes = ['https://www.googleapis.com/auth/spreadsheets']
  creds = Google::Auth::ServiceAccountCredentials.make_creds(
    json_key_io: File.open(CREDENTIAL_PATH),
    scope: scopes
  )
  creds.fetch_access_token!
  service = Google::Apis::SheetsV4::SheetsService.new
  service.authorization = creds
  sheet_manager = SheetManager.new(service, SHEET_ID)
  puts "[Google Sheets] 연결 성공: #{SHEET_ID}"
rescue => e
  puts "[에러] Google Sheets 연결 실패: #{e.message}"
  exit 1
end

# Mastodon 연결
begin
  mastodon_client = MastodonClient.new(base_url: BASE_URL, token: TOKEN)
  puts "[Mastodon] 연결 성공: #{BASE_URL}"
rescue => e
  puts "[에러] Mastodon 초기화 실패: #{e.message}"
  exit 1
end

puts "[상점봇] 시스템 준비 완료"
puts "----------------------------------------"
puts "Mentions 폴링 시작 (60초 간격 + rate-limit 보호)"
puts "----------------------------------------"

# 멘션 추적
last_checked_id = File.exist?(LAST_ID_FILE) ? File.read(LAST_ID_FILE).strip : nil
base_interval = 60
cooldown_on_429 = 300  # 5분 대기
loop_count = 0

loop do
  begin
    loop_count += 1
    delay = base_interval + rand(-10..10) # ±10초 무작위 딜레이
    puts "[루프 #{loop_count}] 폴링 요청 시작 (지연 #{delay}s)"
    mentions, headers = mastodon_client.get_mentions_with_headers(limit: 20, since_id: last_checked_id)

    # Rate-limit 헤더 검사
    if headers['x-ratelimit-remaining'] && headers['x-ratelimit-remaining'].to_i < 1
      reset_after = headers['x-ratelimit-reset'] ? headers['x-ratelimit-reset'].to_i : cooldown_on_429
      puts "[경고] Rate limit 도달 → #{reset_after}초 대기"
      sleep(reset_after)
      next
    end

    if mentions.is_a?(Hash) && mentions["error"]
      puts "[HTTP 오류] #{mentions["error"]} → 5분 대기"
      sleep(cooldown_on_429)
      next
    end

    mentions.sort_by! { |n| n["id"].to_i }
    next if mentions.empty?

    mentions.each do |n|
      next unless n["type"] == "mention"
      next unless n["status"]

      status = n["status"]
      created_at = Time.parse(status["created_at"].to_s).getlocal.strftime('%H:%M:%S')
      sender     = n["account"]["acct"]
      content    = status["content"].to_s.force_encoding('UTF-8')

      puts "[MENTION] #{created_at} - @#{sender}"
      puts "  ↳ #{content}"

      begin
        n["status"]  = OpenStruct.new(status)
        n["account"] = OpenStruct.new(n["account"])
        CommandParser.parse(mastodon_client, sheet_manager, n)
      rescue => e
        puts "[에러] 명령어 실행 중 문제 발생: #{e.message}"
      end

      last_checked_id = n["id"]
      File.write(LAST_ID_FILE, last_checked_id)
    end

  rescue StandardError => e
    if e.message.include?('429')
      puts "[경고] API 호출 한도 초과 (429) → 5분 대기"
      sleep(cooldown_on_429)
      retry
    else
      puts "[에러] 예외 발생: #{e.class} - #{e.message}"
      sleep(15)
      retry
    end
  end

  sleep(base_interval + rand(-10..10))
end
