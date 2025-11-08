# ============================================
# main.rb (Shop Bot - HTTP 기반 안정 버전, since_id 완전 대응 + 429 보호)
# ============================================
# encoding: UTF-8
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

Dotenv.load('.env')

# =============================
# 환경 변수 검증
# =============================
required_envs = %w[MASTODON_BASE_URL MASTODON_TOKEN GOOGLE_SHEET_ID GOOGLE_APPLICATION_CREDENTIALS]
missing = required_envs.select { |v| ENV[v].nil? || ENV[v].strip.empty? }

if missing.any?
  missing.each { |v| puts "[환경변수 누락] #{v}" }
  puts "[오류] 환경 변수가 올바르지 않습니다. .env 파일을 확인하세요."
  exit 1
end

BASE_URL        = ENV['MASTODON_BASE_URL']
TOKEN           = ENV['MASTODON_TOKEN']
SHEET_ID        = ENV['GOOGLE_SHEET_ID']
CREDENTIAL_PATH = ENV['GOOGLE_APPLICATION_CREDENTIALS']
LAST_ID_FILE    = 'last_mention_id.txt'

puts "[상점봇] 실행 시작 (#{Time.now.strftime('%H:%M:%S')})"

# =============================
# Google Sheets API 연결
# =============================
begin
  scopes = ['https://www.googleapis.com/auth/spreadsheets']
  authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
    json_key_io: File.open(CREDENTIAL_PATH),
    scope: scopes
  )
  authorizer.fetch_access_token!

  service = Google::Apis::SheetsV4::SheetsService.new
  service.client_options.open_timeout_sec = 10
  service.client_options.read_timeout_sec = 30
  service.authorization = authorizer

  sheet_manager = SheetManager.new(service, SHEET_ID)
  puts "[Google Sheets] 연결 성공: #{SHEET_ID}"
rescue => e
  puts "[에러] Google Sheets 연결 실패: #{e.message}"
  puts e.backtrace.first(3)
  exit 1
end

# =============================
# Mastodon 클라이언트 연결
# =============================
begin
  mastodon_client = MastodonClient.new(base_url: BASE_URL, token: TOKEN)
  puts "[Mastodon] 연결 성공: #{BASE_URL}"
rescue => e
  puts "[에러] Mastodon 클라이언트 초기화 실패: #{e.message}"
  puts e.backtrace.first(3)
  exit 1
end

puts "[상점봇] 시스템 준비 완료"
puts "----------------------------------------"
puts "Mentions 폴링 시작 (30초 간격)"
puts "----------------------------------------"

# =============================
# Mentions 폴링 루프
# =============================
last_checked_id = File.exist?(LAST_ID_FILE) ? File.read(LAST_ID_FILE).strip : nil
sleep_interval  = 30   # ✅ 안정 주기 (429 방지)
error_cooldown  = 60   # ✅ 429 발생 시 1분 대기

loop do
  begin
    mentions = mastodon_client.get_mentions(limit: 20, since_id: last_checked_id)
    if mentions.is_a?(Hash) && mentions["error"]
      puts "[HTTP 오류] #{mentions["error"]}"
      sleep error_cooldown
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
        puts "  ↳ #{e.backtrace.first(3).join("\n  ↳ ")}"
      end

      last_checked_id = n["id"]
      File.write(LAST_ID_FILE, last_checked_id)
    end

  rescue StandardError => e
    # ✅ API 한도 초과 (429) 포함 예외 처리
    if e.message.include?('429') || e.message.include?('Too Many Requests')
      puts "[경고] API 호출 한도 초과 → 1분 대기 후 재시도"
      sleep error_cooldown
      retry
    else
      puts "[에러] 폴링 중 예외 발생: #{e.class} - #{e.message}"
      puts "  ↳ #{e.backtrace.first(3).join("\n  ↳ ")}"
      sleep 10
      retry
    end
  end

  sleep sleep_interval
end
