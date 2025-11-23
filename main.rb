#!/usr/bin/env ruby
# encoding: UTF-8

require 'dotenv'
require 'time'
require 'json'
require 'set'
require 'google/apis/sheets_v4'
require 'googleauth'

require_relative 'mastodon_client'
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

puts "[상점봇 Polling] 실행 시작 (#{Time.now.strftime('%H:%M:%S')})"

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
# Mastodon 클라이언트
# -----------------------------
mastodon = MastodonClient.new(base_url: BASE_URL, token: TOKEN)

puts "----------------------------------------"
puts "상점봇 준비 완료. Polling으로 멘션 감시 시작"
puts "----------------------------------------"

# -----------------------------
# Main polling loop (개선 버전)
# -----------------------------
processed_ids = Set.new
last_check_time = Time.now

loop do
  begin
    notifications, rate = mastodon.notifications
    
    notifications.each do |note|
      next unless note["type"] == "mention"
      
      nid = note["id"].to_s
      
      # 이미 처리한 알림은 스킵
      next if processed_ids.include?(nid)
      
      # 처리 목록에 추가
      processed_ids.add(nid)
      
      # 메모리 관리: 1000개 넘으면 오래된 것 삭제
      if processed_ids.size > 1000
        processed_ids = processed_ids.to_a.last(500).to_set
      end
      
      account = note["account"]["acct"]
      content_raw = note.dig("status", "content") || ""
      text = content_raw.gsub(/<[^>]+>/, "").strip
      
      puts "[MENTION] @#{account}: #{text[0..50]}..."
      
      # CommandParser가 내부적으로 응답 처리
      CommandParser.parse(mastodon, sheet_manager, note)
    end
    
  rescue => e
    puts "[오류] #{e.class} - #{e.message}"
    puts "  ↳ #{e.backtrace.first(3).join("\n  ↳ ")}"
    sleep 3
  end
  
  sleep 3
end
