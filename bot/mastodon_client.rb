# bot/mastodon_client.rb
require 'mastodon'

module MastodonClient
  def self.client
    @client ||= Mastodon::REST::Client.new(
      base_url: ENV['MASTODON_BASE_URL'],
      bearer_token: ENV['MASTODON_TOKEN']
    )
  end

  def self.listen_mentions
    timeline = client.notifications.select { |n| n.type == 'mention' }
    timeline.each do |mention|
      yield mention if block_given?
    end
  end

  def self.reply(mention, message)
    acct = mention.account.acct
    client.create_status("@#{acct} #{message}", in_reply_to_id: mention.status.id)
  end
end
