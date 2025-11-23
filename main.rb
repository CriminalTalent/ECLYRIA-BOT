#!/usr/bin/env ruby
# encoding: UTF-8
require 'json'
require 'net/http'
require 'uri'
require 'google/apis/sheets_v4'
require 'dotenv/load'
require_relative 'mastodon_client'
require_relative 'sheet_manager'
require_relative 'command_parser'

MASTODON_BASE_URL = ENV["MASTODON_BASE_URL"]
ACCESS_TOKEN      = ENV["MASTODON_TOKEN"]
SHEET_ID          = ENV["GOOGLE_SHEET_ID"]

if MASTODON_BASE_URL.nil? || ACCESS_TOKEN.nil? || SHEET_ID.nil?
  puts "[환경변수 오류] .env 파일을 읽지 못했습니다."
  puts "MASTODON_BASE_URL: #{MASTODON_BASE_URL.inspect}"
  puts "ACCESS_TOKEN: #{ACCESS_TOKEN.inspect}"
  puts "SHEET_ID: #{SHEET_ID.inspect}"
  exit
end

# ---------------------------
# Google Sheets
# ---------------------------
service = Google::Apis::SheetsV4::SheetsService.new
service.client_options.application_name = "FortunaeFons Shop Bot"
service.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
  json_key_io: File.open(ENV["GOOGLE_APPLICATION_CREDENTIALS"]),
  scope: ["https://www.googleapis.com/auth/spreadsheets"]
)

sheet_manager = SheetManager.new(service, SHEET_ID)

mastodon = MastodonClient.new(
  base_url: MASTODON_BASE_URL,
  token: ACCESS_TOKEN
)

puts "[ShopBot] 실행 준비 완료!"
puts "Mastodon: #{MASTODON_BASE_URL}"
puts "Sheet ID:  #{SHEET_ID}"

# ---------------------------
# Main polling loop (수정 버전)
# ---------------------------
processed_ids = Set.new  # 처리한 알림 ID 저장
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
      
      puts "[MENTION] @#{account}: #{text}"
      
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
