# bot/main.rb
require 'dotenv/load'
require_relative 'mastodon_client'
require_relative 'command_parser'

puts " ECLYRIA봇 기동 완료!"

loop do
  MastodonClient.listen_mentions do |mention|
    CommandParser.handle(mention)
  end
  sleep 15
end
