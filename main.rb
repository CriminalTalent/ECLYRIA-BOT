# main.rb
require 'dotenv/load'
require 'google/apis/sheets_v4'
require 'googleauth'
require_relative 'mastodon_client'
require_relative 'command_parser'
require_relative 'sheet_manager'

unless MastodonClient.validate_environment
  puts "환경 설정 오류: .env를 확인하세요."
  exit
end

begin
  sheets_service = Google::Apis::SheetsV4::SheetsService.new
  
  credentials = Google::Auth::ServiceAccountCredentials.make_creds(
    json_key_io: File.open('credentials.json'),
    scope: 'https://www.googleapis.com/auth/spreadsheets'
  )
  credentials.fetch_access_token!
  sheets_service.authorization = credentials
  
  spreadsheet = sheets_service.get_spreadsheet(ENV["GOOGLE_SHEET_ID"])
  puts "Google Sheets 연결 성공: #{spreadsheet.properties.title}"
  
rescue => e
  puts "Google Sheets 연결 실패: #{e.message}"
  exit
end

sheet_manager = SheetManager.new(sheets_service, ENV["GOOGLE_SHEET_ID"])
client = MastodonClient.client

client.stream_user do |event|
  if event.is_a?(Mastodon::Notification) && event.type == 'mention'
    CommandParser.parse(client, sheet_manager, event)
  end
end
