# main.rb
require 'dotenv/load'
require 'google_drive'
require_relative 'mastodon_client'
require_relative 'command_parser'
require_relative 'sheet_manager'

# Google Sheets 인증 및 세션
unless MastodonClient.validate_environment
  puts "환경 설정이 올바르지 않습니다. .env 파일을 확인해주세요."
  exit
end

begin
  session = GoogleDrive::Session.from_config("config.json")
  spreadsheet = session.spreadsheet_by_key(ENV["GOOGLE_SHEET_ID"])
rescue => e
  puts "Google Sheets 연결 실패: #{e.message}"
  exit
end

# 시트 관리자 객체
sheet_manager = SheetManager.new(spreadsheet)

# 마스토돈 클라이언트
client = MastodonClient.client

# 스트리밍 시작
client.stream_user do |event|
  if event.is_a?(Mastodon::Notification) && event.type == 'mention'
    CommandParser.parse(client, sheet_manager, event)
  end
end
