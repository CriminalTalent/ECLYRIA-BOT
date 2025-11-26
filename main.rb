#!/usr/bin/env ruby
# encoding: UTF-8

require 'mastodon'
require 'dotenv/load'
require_relative 'mastodon_client'

LAST_FILE = 'last_mention_id.txt'

base_url = ENV["MASTODON_BASE_URL"]
token    = ENV["MASTODON_TOKEN"]

client = MastodonClient.new(base_url: base_url, token: token)

# last_id 읽기
last_id =
  if File.exist?(LAST_FILE)
    File.read(LAST_FILE).to_i
  else
    0
  end

puts "----------------------------------------"
puts "상점봇 Polling 시작 (최종 처리 ID: #{last_id})"
puts "----------------------------------------"

def clean_html(text)
  text
    .gsub(/<[^>]+>/, "")
    .gsub(/&[a-z]+;/i, "")
    .strip
end

def extract_command(content)
  c = clean_html(content)

  return :wallet if c =~ /\[(주머니|지갑|가방|wallet)\]/i
  return :luck   if c =~ /\[(운세|fortune)\]/i
  return :dice   if c =~ /\[(주사위|dice)\]/i
  return :random if c =~ /\[(랜덤박스|랜덤상자|random)\]/i

  nil
end

# 응답 공통
def reply(mastodon_client, notification, text)
  return if text.to_s.strip.empty?
  status_id = notification["status"]["id"]
  mastodon_client.post_status(text, reply_to_id: status_id, visibility: "unlisted")
end

# 기능 예시: 지갑 확인
def reply_wallet(mastodon_client, notification)
  acct = notification["account"]["acct"]
  text = "@#{acct} 갈레온 확인 기능!"
  reply(mastodon_client, notification, text)
  puts "[REPLY] wallet -> #{acct}"
end

loop do
  begin
    notifications = client.notifications(types: ["mention"])
    notifications.reverse_each do |n|
      nid = n["id"].to_i
      next unless nid > last_id

      acct = n["account"]["acct"]
      content = clean_html(n.dig("status", "content") || "")

      cmd = extract_command(content)

      # 🔹 처리 전 last_id 즉시 갱신
      last_id = nid
      File.write(LAST_FILE, last_id.to_s)

      if cmd == :wallet
        reply_wallet(client, n)
      elsif cmd == :luck
        reply(client, n, "@#{acct} 오늘의 운세 기능!")
      elsif cmd == :dice
        roll = rand(1..20)
        reply(client, n, "@#{acct} 🎲 주사위 결과: #{roll}")
      elsif cmd == :random
        reply(client, n, "@#{acct} 랜덤박스 기능!")
      else
        puts "[SKIP] 명령 아님: #{content}"
      end

      sleep 2
    end

  rescue => e
    puts "[ERROR] #{e.class} - #{e.message}"
  end

  sleep 7
end
