require_relative 'mastodon_client'
require_relative 'command_parser'
require_relative 'sheet_manager'
require 'google_drive'
require 'dotenv/load'

session = GoogleDrive::Session.from_config("config.json")
spreadsheet = session.spreadsheet_by_key(ENV["GOOGLE_SHEET_ID"])
sheet_manager = SheetManager.new(spreadsheet)

client = MastodonClient.client

client.stream_user do |event|
  if event.is_a?(Mastodon::Notification) && event.type == 'mention'
    CommandParser.parse(client, sheet_manager, event)
  end
end
