#!/usr/bin/env ruby
# encoding: UTF-8
# require 'bundler/setup'  ← 이 줄 주석 처리
require 'dotenv'
require 'time'
require 'json'
require 'ostruct'
require 'nokogiri'
require 'set'
require 'google/apis/sheets_v4'
require 'googleauth'

require_relative 'mastodon_client'
require_relative 'streaming_client'
require_relative 'sheet_manager'
require_relative 'command_parser'

Dotenv.load('.env')

required_envs = %w[MASTODON_BASE_URL ACCESS_TOKEN SHEET_ID GOOGLE_APPLICATION_CREDENTIALS]
missing = required_envs.select { |v| ENV[v].nil? || ENV[v].strip.empty? }

if missing.any?
  missing.each { |v| puts "[환경변수 누락] #{v}" }
  exit 1
end

BASE_URL        = ENV['MASTODON_BASE_URL']
TOKEN           = ENV['ACCESS_TOKEN']
SHEET_ID        = ENV['SHEET_ID']
CREDENTIAL_PATH = ENV['GOOGLE_APPLICATION_CREDENTIALS']

puts "[상점봇 Streaming] 실행 시작 (#{Time.now.strftime('%H:%M:%S')})"

# -----------------------------
# Google Sheets 연결
# -----------------------------
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

# -----------------------------
# Mastodon 클라이언트 (REST + Streaming)
# -----------------------------
rest_client      = MastodonClient.new(base_url: BASE_URL, token: TOKEN)
streaming_client = MastodonStreamingClient.new(base_url: BASE_URL, token: TOKEN)

puts "----------------------------------------"
puts "상점봇 준비 완료. Streaming으로 멘션 감시 시작"
puts "----------------------------------------"

loop_count = 0

begin
  loop do
    loop_count += 1
    puts "[STREAM 루프 #{loop_count}] notification 스트림 연결..."

    streaming_client.stream_notifications do |notif|
      next unless notif["type"] == "mention"
      next unless notif["status"]

      status  = notif["status"]
      account = notif["account"]

      created_at = Time.parse(status["created_at"].to_s).getlocal.strftime('%H:%M:%S')
      sender     = account["acct"]
      content    = status["content"].to_s.encode('UTF-8')

      puts "[MENTION] #{created_at} - @#{sender}"
      puts "  ↳ #{content}"

      begin
        n = {
          "id"      => notif["id"].to_s,
          "type"    => notif["type"],
          "status"  => status,
          "account" => account
        }

        CommandParser.parse(rest_client, sheet_manager, n)
      rescue => e
        puts "[에러] 명령어 실행 중 문제 발생: #{e.class} - #{e.message}"
        puts e.backtrace.first(5)
      end
    end

    puts "[STREAM] 연결 종료됨. 10초 후 재연결"
    sleep 10
  end
rescue Interrupt
  puts "\n[종료] Ctrl+C 로 상점봇 Streaming 종료"
rescue => e
  puts "[치명적 오류] #{e.class} - #{e.message}"
  puts e.backtrace.first(10)
end
