require 'dotenv'
Dotenv.load(File.expand_path('../.env', __dir__))

require_relative 'mastodon_client'
require_relative 'command_parser'

puts "✅ ECLYRIA봇 기동 완료!"
puts "📡 BASE_URL: #{ENV['MASTODON_BASE_URL']}"
puts "🔐 TOKEN 시작: #{ENV['MASTODON_TOKEN'][0..10]}..." if ENV['MASTODON_TOKEN']

loop do
  MastodonClient.listen_mentions do |mention|
    CommandParser.handle(mention)
  end
  sleep 15
end
