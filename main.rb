# ============================================
# main.rb (Shop Bot - mastodon-api 1.1.0 완전 호환 버전)
# ============================================
# encoding: UTF-8
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
unless MastodonClient.validate_environment
  puts "[오류] 환경 변수가 올바르지 않습니다. .env 파일을 확인하세요."
  exit 1
end

BASE_URL        = ENV['MASTODON_BASE_URL']
TOKEN           = ENV['MASTODON_TOKEN']
SHEET_ID        = ENV['GOOGLE_SHEET_ID']
CREDENTIAL_PATH = ENV['GOOGLE_APPLICATION_CREDENTIALS'] || 'credentials.json'

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

# =============================
# Notification 래퍼 (mastodon-api 1.1.0 JSON 대응)
# =============================
module Mastodon
  class Notification
    attr_accessor :id, :type, :status, :account
    def initialize(data)
      @id      = data['id']
      @type    = data['type']
      @status  = data['status']
      @account = data['account']
    end
  end
end

puts "[상점봇] 시스템 준비 완료"
puts "----------------------------------------"
puts "Mentions 폴링 시작 (10초 간격)"
puts "----------------------------------------"

# =============================
# Mentions 폴링 루프
# =============================
last_checked_id = nil
client = mastodon_client.instance_variable_get(:@client)

loop do
  begin
    # mastodon-api 1.1.0: 배열(JSON) 직접 반환
    response = client.perform_request(:get, '/api/v1/notifications', { limit: 20 })
    notifications = response.map { |n| Mastodon::Notification.new(n) }

    # 오래된 것부터 처리
    notifications.sort_by! { |n| n.id.to_i }

    notifications.each do |n|
      next unless n.type == 'mention'
      next if last_checked_id && n.id.to_i <= last_checked_id.to_i
      next unless n.status

      created_at = Time.parse(n.status['created_at'].to_s).getlocal.strftime('%H:%M:%S')
      sender     = n.account['acct']
      content    = n.status['content'].to_s.force_encoding('UTF-8')

      puts "[MENTION] #{created_at} - @#{sender}"
      puts "  ↳ #{content}"

      begin
        # Hash → OpenStruct 변환 (파서 호환)
        n.status  = OpenStruct.new(n.status)  if n.status.is_a?(Hash)
        n.account = OpenStruct.new(n.account) if n.account.is_a?(Hash)

        CommandParser.parse(mastodon_client, sheet_manager, n)
      rescue => e
        puts "[에러] 명령어 실행 중 문제 발생: #{e.message}"
        puts "  ↳ #{e.backtrace.first(3).join("\n  ↳ ")}"
      end

      last_checked_id = n.id
    end

  rescue Mastodon::Error => e
    puts "[Mastodon 오류] #{e.class}: #{e.message}"
    sleep 5
    retry
  rescue => e
    puts "[에러] 폴링 중 예외 발생: #{e.message}"
    puts "  ↳ #{e.backtrace.first(3).join("\n  ↳ ")}"
    sleep 5
    retry
  end

  sleep 10
end
