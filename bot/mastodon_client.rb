# bot/mastodon_client.rb
require 'mastodon'

module MastodonClient
  @client = Mastodon::REST::Client.new(
    base_url: ENV['MASTODON_BASE_URL'],
    bearer_token: ENV['MASTODON_TOKEN']
  )

  def self.listen_mentions
    # 예시: mentions 받아오기
    mentions = @client.notifications.select { |n| n.type == 'mention' }
    mentions.each { |mention| yield mention }
  end
end
