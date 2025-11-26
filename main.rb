#!/usr/bin/env ruby
# encoding: UTF-8

require 'mastodon'
require 'dotenv/load'
require 'google/apis/sheets_v4'
require 'googleauth'

require_relative 'mastodon_client'

# ============================================
# 환경 변수
# ============================================
LAST_FILE  = 'last_mention_id.txt'
BASE_URL   = ENV["MASTODON_BASE_URL"]
TOKEN      = ENV["MASTODON_TOKEN"]
SHEET_ID   = ENV["GOOGLE_SHEET_ID"]
CRED_PATH  = ENV["GOOGLE_APPLICATION_CREDENTIALS"]

if BASE_URL.nil? || TOKEN.nil? || SHEET_ID.nil? || CRED_PATH.nil?
  puts "[ERROR] 환경 변수가 빠졌습니다. (MASTODON_BASE_URL / MASTODON_TOKEN / GOOGLE_SHEET_ID / GOOGLE_APPLICATION_CREDENTIALS)"
  exit 1
end

# ============================================
# Mastodon 클라이언트
# ============================================
client = MastodonClient.new(base_url: BASE_URL, token: TOKEN)

# ============================================
# Google Sheets 클라이언트
# ============================================
Sheets = Google::Apis::SheetsV4
service = Sheets::SheetsService.new
service.client_options.application_name = "FortunaeFons ShopBot"

service.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
  json_key_io: File.open(CRED_PATH),
  scope: ['https://www.googleapis.com/auth/spreadsheets']
)

SPREADSHEET_ID = SHEET_ID
USER_SHEET  = '사용자'
ITEM_SHEET  = '아이템'

# ============================================
# last_id 읽기
# ============================================
last_id =
  if File.exist?(LAST_FILE)
    File.read(LAST_FILE).to_i
  else
    0
  end

puts "----------------------------------------"
puts "상점봇 Polling 시작 (최종 처리 ID: #{last_id})"
puts "----------------------------------------"

# ============================================
# 유틸 함수
# ============================================

def clean_html(text)
  text
    .gsub(/<[^>]+>/, "")    # 태그 제거
    .gsub(/&[a-z]+;/i, "")  # HTML 엔티티 대략 제거
    .strip
end

def normalize_item_name(name)
  name.to_s.gsub(/\s+/, "").downcase
end

def truthy?(v)
  case v
  when true then true
  else
    s = v.to_s.strip.upcase
    %w[TRUE 1 Y YES].include?(s)
  end
end

# 인벤토리 파싱/문자열화
def parse_inventory(str)
  inv = Hash.new(0)
  str.to_s.split(/[,\/\n]/).each do |token|
    t = token.strip
    next if t.empty?

    if t =~ /(.*?)[x×*](\d+)/
      name  = Regexp.last_match(1).strip
      count = Regexp.last_match(2).to_i
    else
      name  = t
      count = 1
    end
    inv[name] += count
  end
  inv
end

def inventory_to_string(inv)
  return "" if inv.nil? || inv.empty?
  inv.map { |name, count| "#{name}x#{count}" }.join(", ")
end

# ============================================
# 아이템 관련: 캐시 + 조회
# ============================================
$items_cache = []
$items_cache_time = Time.at(0)

def load_items(service)
  range = "#{ITEM_SHEET}!A2:F200"
  res   = service.get_spreadsheet_values(SPREADSHEET_ID, range)
  rows  = res.values || []

  rows.map do |row|
    {
      name:        row[0].to_s.strip,
      key:         normalize_item_name(row[0]),
      description: row[1].to_s.strip,
      price:       row[2].to_i,
      on_sale:     truthy?(row[3]),
      usable:      truthy?(row[4])
    }
  end
end

def find_item(service, name)
  key = normalize_item_name(name)

  if Time.now - $items_cache_time > 60
    $items_cache      = load_items(service)
    $items_cache_time = Time.now
    puts "[ITEM] 캐시 갱신 (#{ $items_cache.size }개)"
  end

  $items_cache.find { |it| it[:key] == key }
end

# ============================================
# 사용자(지갑/인벤토리) 관련
# ============================================
def load_user(service, acct)
  range = "#{USER_SHEET}!A1:Z"
  res   = service.get_spreadsheet_values(SPREADSHEET_ID, range)
  all   = res.values || []

  header = all[0] || []
  rows   = all[1..] || []

  id_col    = header.index('사용자 ID') || 0
  g_col     = header.index('갈레온')    || 2
  items_col = header.index('아이템')    || 3

  rows.each_with_index do |row, idx|
    next unless row[id_col].to_s == acct

    row_index = idx + 2 # 헤더가 1행
    galleons  = row[g_col].to_i
    inv_str   = row[items_col].to_s

    return {
      id:         acct,
      row_index:  row_index,
      g_col:      g_col,
      items_col:  items_col,
      galleons:   galleons,
      inventory:  parse_inventory(inv_str)
    }
  end

  nil
end

def save_user(service, user)
  r = user[:row_index]

  g_col_letter     = ('A'.ord + user[:g_col]).chr
  items_col_letter = ('A'.ord + user[:items_col]).chr

  g_range     = "#{USER_SHEET}!#{g_col_letter}#{r}"
  items_range = "#{USER_SHEET}!#{items_col_letter}#{r}"

  # 갈레온 업데이트
  body_g = Sheets::ValueRange.new(values: [[user[:galleons]]])
  service.update_spreadsheet_value(
    SPREADSHEET_ID,
    g_range,
    body_g,
    value_input_option: 'USER_ENTERED'
  )

  # 인벤토리 업데이트
  inv_str = inventory_to_string(user[:inventory])
  body_i  = Sheets::ValueRange.new(values: [[inv_str]])
  service.update_spreadsheet_value(
    SPREADSHEET_ID,
    items_range,
    body_i,
    value_input_option: 'USER_ENTERED'
  )

  puts "[USER] 업데이트: #{user[:id]} g=#{user[:galleons]} inv=#{inv_str.inspect}"
end

# ============================================
# 명령 파서
# ============================================
def parse_command(raw_content)
  c = clean_html(raw_content)

  # 우선 고정 명령
  return [:wallet, nil] if c =~ /\[(주머니|지갑|가방|wallet)\]/i
  return [:luck,   nil] if c =~ /\[(운세|fortune)\]/i
  return [:dice,   nil] if c =~ /\[(주사위|dice)\]/i
  return [:random, nil] if c =~ /\[(랜덤박스|랜덤상자|random)\]/i

  # 구매 / 사용 / 설명
  if c =~ /\[(구매|buy)\/([^\]]+)\]/i
    return [:buy, Regexp.last_match(2).strip]
  end

  if c =~ /\[(사용|use)\/([^\]]+)\]/i
    return [:use, Regexp.last_match(2).strip]
  end

  # 그냥 [아이템명] → 설명 보기
  if c =~ /\[([^\]\/]+)\]/
    return [:describe, Regexp.last_match(1).strip]
  end

  [:none, nil]
end

# ============================================
# Mastodon 답글 유틸
# ============================================
def reply(mastodon_client, notification, text)
  return if text.to_s.strip.empty?

  status = notification["status"] || {}
  status_id = status["id"] || notification["id"]

  mastodon_client.post_status(text, reply_to_id: status_id, visibility: "unlisted")
end

def reply_wallet(mastodon_client, notification)
  acct = notification["account"]["acct"]
  text = "@#{acct} 갈레온 확인 기능!"
  reply(mastodon_client, notification, text)
  puts "[REPLY] wallet -> #{acct}"
end

def reply_luck(mastodon_client, notification)
  acct = notification["account"]["acct"]
  msgs = [
    "오늘은 작은 행운이 따라붙을 것 같아요.",
    "조용히 준비해 두면 좋은 날이에요.",
    "조금은 모험해도 괜찮은 하루일지도요.",
    "컨디션 관리에 신경 쓰면 도움이 될 거예요."
  ]
  text = "@#{acct} 오늘의 운세: #{msgs.sample}"
  reply(mastodon_client, notification, text)
end

def reply_dice(mastodon_client, notification)
  acct = notification["account"]["acct"]
  roll = rand(1..20)
  text = "@#{acct} 🎲 주사위 결과: #{roll}"
  reply(mastodon_client, notification, text)
end

def reply_random_box(mastodon_client, notification)
  acct = notification["account"]["acct"]
  text = "@#{acct} 랜덤상자 기능! (아직 효과는 준비 중이에요)"
  reply(mastodon_client, notification, text)
end

# 아이템 설명 출력
def reply_item_description(service, mastodon_client, notification, item_name, as_use: false)
  acct = notification["account"]["acct"]
  item = find_item(service, item_name)

  if item.nil?
    reply(mastodon_client, notification,
          "@#{acct} '#{item_name}'라는 아이템을 찾지 못했어요.")
    return
  end

  parts = item[:description].to_s.split("/").map { |s| s.strip }.reject(&:empty?)
  desc  = parts.sample || item[:description].to_s

  if as_use
    unless item[:usable]
      reply(mastodon_client, notification,
            "@#{acct} #{item[:name]}은(는) 지금 사용할 수 없는 물건이에요.")
      return
    end
    text = "@#{acct} #{item[:name]}을(를) 사용합니다.\n#{desc}"
  else
    text = "@#{acct} #{item[:name]} — #{desc}"
  end

  reply(mastodon_client, notification, text)
end

# 구매 처리
def handle_buy(service, mastodon_client, notification, item_name)
  acct = notification["account"]["acct"]
  item = find_item(service, item_name)

  if item.nil?
    reply(mastodon_client, notification,
          "@#{acct} '#{item_name}'라는 아이템을 찾지 못했어요.")
    return
  end

  unless item[:on_sale]
    reply(mastodon_client, notification,
          "@#{acct} #{item[:name]}은(는) 지금은 판매하지 않는 물건이에요.")
    return
  end

  user = load_user(service, acct)
  if user.nil?
    reply(mastodon_client, notification,
          "@#{acct} 아직 상점에 등록되지 않은 사용자예요. 교수봇 출석 등으로 등록 후 이용해 주세요.")
    return
  end

  price = item[:price].to_i
  if user[:galleons] < price
    reply(mastodon_client, notification,
          "@#{acct} 갈레온이 부족해서 #{item[:name]}을(를) 살 수 없어요.\n가격: #{price} G / 현재: #{user[:galleons]} G")
    return
  end

  # 결제 + 인벤토리 추가
  user[:galleons] -= price
  user[:inventory][item[:name]] += 1
  save_user(service, user)

  reply(mastodon_client, notification,
        "@#{acct} #{item[:name]}을(를) #{price} G에 구매했어요!\n현재 잔액: #{user[:galleons]} G")
end

# ============================================
# 메인 루프
# ============================================
loop do
  begin
    notifications = client.notifications(types: ["mention"])
    notifications.reverse_each do |n|
      nid = n["id"].to_i
      next unless nid > last_id

      acct    = n["account"]["acct"]
      content = clean_html(n.dig("status", "content") || "")

      cmd, arg = parse_command(content)

      # 처리 전 last_id 저장 (중복 응답 방지)
      last_id = nid
      File.write(LAST_FILE, last_id.to_s)

      case cmd
      when :wallet
        reply_wallet(client, n)
      when :luck
        reply_luck(client, n)
      when :dice
        reply_dice(client, n)
      when :random
        reply_random_box(client, n)
      when :buy
        handle_buy(service, client, n, arg)
      when :use
        reply_item_description(service, client, n, arg, as_use: true)
      when :describe
        reply_item_description(service, client, n, arg, as_use: false)
      else
        puts "[SKIP] 명령 아님: #{content}"
      end

      sleep 2
    end

  rescue => e
    puts "[ERROR] #{e.class} - #{e.message}"
    puts e.backtrace.first(5).join("\n  ↳ ")
  end

  sleep 7
end
