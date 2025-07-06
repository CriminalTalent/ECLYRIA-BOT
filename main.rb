# main.rb
require 'dotenv'
Dotenv.load('.env')
require_relative 'mastodon_client'
require_relative 'command_parser'
require_relative 'player_sheet'
require_relative 'shop_logic'

puts "\n[시작] 마법용품점 봇 기동 중..."
puts "BASE_URL: #{ENV['MASTODON_BASE_URL']}"
puts "TOKEN 시작: #{ENV['MASTODON_TOKEN'][0..10]}..."

unless MastodonClient.test_connection
  puts "[오류] 마스토돈 연결 실패"
  exit 1
end

puts "[연결] 마스토돈 연결 성공"
puts "[대기] 멘션 감지 시작..."

client = MastodonClient.client
last_checked_id = nil

loop do
  mentions = client.notifications.select { |n| n.type == 'mention' }
  mentions.each do |mention|
    next if last_checked_id && mention.id <= last_checked_id
    last_checked_id = mention.id

    CommandParser.handle_mention(mention)
    sleep 1
  end
  sleep 15
end
