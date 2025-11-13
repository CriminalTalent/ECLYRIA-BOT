# ============================================
# main.rb (Shop Bot - 안정화 완전판)
# ============================================

require 'bundler/setup'
require 'dotenv'
require 'time'
require 'json'
require 'ostruct'
require 'nokogiri'
require 'google/apis/sheets_v4'
require 'googleauth'
require_relative 'mastodon_client'
require_relative 'sheet_manager'
require_relative 'command_parser'

Dotenv.load('.env')

# 필수 환경 변수 확인
required_envs = %w[MASTODON_BASE_URL MASTODON_TOKEN GOOGLE_SHEET_ID GOOGLE_APPLICATION_CREDENTIALS]
missing = required_envs.select { |v| ENV[v].nil? || ENV[v].strip.empty? }

if missing.any?
  missing.each { |v| puts "[환경변수 누락] #{v}" }
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

  sheet_service = Google::Apis::SheetsV4::SheetsService.new
  sheet_service.authorization = creds

  sheet_manager = SheetManager.new(sheet_service, SHEET_ID)
  puts "[Google Sheets] 연결 성공: #{SHEET_ID}"

rescue => e
  puts "[Google Sheets 오류] #{e.message}"
  exit 1
end

# Mastodon 연결
begin
  mastodon_client = MastodonClient.new(
    base_url: BASE_URL,
    token: TOKEN
  )
  puts "[Mastodon] 연결 성공"

rescue => e
  puts "[Mastodon 초기화 실패] #{e.message}"
  exit 1
end

puts "----------------------------------------"
puts "상점봇 준비 완료. 멘션 폴링 시작"
puts "----------------------------------------"

# 멘션 추적
last_checked_id = File.exist?(LAST_ID_FILE) ? File.read(LAST_ID_FILE).strip : nil
base_interval = 60
cooldown_on_429 = 300
loop_count = 0

loop do
  begin
    loop_count += 1
    interval = base_interval + rand(-10..10)

    puts "[루프 #{loop_count}] 폴링 요청 (지연 #{interval}s)"

    # mention만 가져오기
    mentions, headers = mastodon_client.get_mentions_with_headers(
      limit: 20,
      since_id: last_checked_id,
      types: ["mention"]
    )

    # header nil 보호
    remaining = headers['x-ratelimit-remaining'].to_i rescue nil
    reset_in  = headers['x-ratelimit-reset'].to_i rescue cooldown_on_429

    # Rate-limit 보호
    if remaining && remaining < 1
      puts "[경고] rate-limit 도달 → #{reset_in}초 대기"
      sleep(reset_in)
      next
    end

    # API 오류
    if mentions.is_a?(Hash) && mentions['error']
      puts "[HTTP 오류] #{mentions['error']} → 5분 대기"
      sleep(cooldown_on_429)
      next
    end

    next if mentions.nil? || mentions.empty?

    # ID 정렬은 하지 않음 (Mastodon ID는 시간순 정렬이 아님)
    mentions.each do |n|
      next unless n["type"] == "mention"
      next unless n["status"]

      status = n["status"]
      sender = n["account"]["acct"]

      # HTML 제거
      html = status["content"].to_s
      text = Nokogiri::HTML(html).text.strip

      created_at = Time.parse(status["created_at"]).getlocal.strftime('%H:%M:%S')
      puts "[MENTION] #{created_at} - @#{sender}"
      puts "  ↳ #{text}"

      # OpenStruct 변환 (기존 구조 유지)
      n["status"]  = OpenStruct.new(status.merge("content" => text))
      n["account"] = OpenStruct.new(n["account"])

      begin
        CommandParser.parse(mastodon_client, sheet_manager, n)
      rescue => e
        puts "[에러] 명령어 처리 중 오류: #{e.message}"
      end

      last_checked_id = n["id"]
      File.write(LAST_ID_FILE, last_checked_id)
    end

  rescue => e
    if e.message.include?("429")
      puts "[경고] 429 감지 → 5분 대기"
      sleep(cooldown_on_429)
      retry
    else
      puts "[예외] #{e.class} - #{e.message}"
      sleep(10)
      retry
    end
  end

  sleep(interval)
end
