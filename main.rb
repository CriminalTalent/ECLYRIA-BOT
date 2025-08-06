# main.rb
require 'dotenv/load'
require 'google_drive'
require_relative 'mastodon_client'
require_relative 'command_parser'
require_relative 'sheet_manager'

unless MastodonClient.validate_environment
  puts "환경 설정 오류: .env를 확인하세요."
  exit
end

begin
  session = GoogleDrive::Session.from_service_account_key("credentials.json")
  spreadsheet = session.spreadsheet_by_key(ENV["GOOGLE_SHEET_ID"])
rescue => e
  puts "Google Sheets 연결 실패: #{e.message}"
  exit
end

sheet_manager = SheetManager.new(spreadsheet)
client = MastodonClient.client

client.stream_user do |event|
  if event.is_a?(Mastodon::Notification) && event.type == 'mention'
    CommandParser.parse(client, sheet_manager, event)
  end
end
