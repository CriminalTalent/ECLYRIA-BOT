require_relative 'mastodon_client'
require_relative 'command_parser'
require_relative 'sheet_manager'
require 'google_drive'
require 'dotenv/load'

# Google Sheet 세션 설정
session = GoogleDrive::Session.from_config("config.json")
spreadsheet = session.spreadsheet_by_key(ENV["SHEET_KEY"])
sheet_manager = SheetManager.new(spreadsheet)

# Mastodon 클라이언트 생성
client = MastodonClient.build

# 멘션 수신 스트리밍
client.stream_user do |event|
  if event.is_a?(Mastodon::Notification) && event.type == 'mention'
    CommandParser.parse(client, sheet_manager, event)
  end
end
