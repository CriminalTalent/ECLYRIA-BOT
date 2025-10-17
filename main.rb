# encoding: UTF-8
require 'dotenv'
require 'time'
require_relative 'mastodon_client'
require_relative 'sheet_manager'
require_relative 'command_parser'

Dotenv.load('.env')

# =============================
# 환경 변수 검증
# =============================
unless MastodonClient.validate_environment
  puts "[오류] 환경 변수가 올바르지 않습니다. .env 파일을 확인하세요."
  exit
end

# =============================
# 초기화
# =============================
BASE_URL = ENV['MASTODON_BASE_URL']
TOKEN = ENV['MASTODON_TOKEN']
SHEET_ID = ENV['GOOGLE_SHEET_ID']

puts "[상점봇] 실행 시작 (#{Time.now.strftime('%H:%M:%S')})"

# Google Sheets 연결
sheet_manager = SheetManager.new(SHEET_ID)
puts "Google Sheets 연결 성공: #{sheet_manager.sheet_name}"

# Mastodon 클라이언트 초기화
mastodon_client = MastodonClient.new(base_url: BASE_URL, token: TOKEN)
puts "상점봇 준비 완료"

# =============================
# 알림 폴링 (Mentions 확인)
# =============================
puts "알림 폴링 시작 (10초 간격)..."

last_checked_id = nil

loop do
  begin
    notifications = mastodon_client.instance_variable_get(:@client).notifications(limit: 20)

    notifications.each do |n|
      next unless n.type == 'mention'
      next if last_checked_id && n.id <= last_checked_id

      status = n.status
      next unless status

      created_at = Time.parse(status.created_at.to_s).getlocal.strftime('%H:%M:%S')
      sender = n.account.acct
      content = status.content.force_encoding('UTF-8')

      puts "[처리] 알림 ID #{n.id}: #{created_at} - @#{sender}"
      puts "[내용] #{content}"

      begin
        CommandParser.parse(mastodon_client, sheet_manager, n)
      rescue => e
        puts "[에러] 명령어 실행 중 문제 발생: #{e.message}"
        puts "  ↳ #{e.backtrace.first(3).join("\n  ↳ ")}"
      end

      last_checked_id = n.id
    end

  rescue Mastodon::Error::NotFound => e
    puts "[경고] 대상 게시물이 삭제되어 응답하지 않습니다. (#{e.message})"
  rescue Mastodon::Error::Forbidden => e
    puts "[경고] 접근 권한이 없습니다: #{e.message}"
  rescue => e
    puts "[에러] 폴링 중 오류: #{e.message}"
    puts "  ↳ #{e.backtrace.first(3).join("\n  ↳ ")}"
  end

  sleep 10
end
