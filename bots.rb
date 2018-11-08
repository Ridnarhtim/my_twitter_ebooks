require 'twitter_ebooks'
require_relative 'replying_bot'
require_relative 'picbot'

# Make bots
ReplyingBot.new(ENV["BOT_NAME_1"]) do |bot|
  bot.access_token = ENV["ACCESS_TOKEN_1"] # Token connecting the app to this account
  bot.access_token_secret = ENV["ACCESS_TOKEN_SECRET_1"] # Secret connecting the app to this account
  bot.consumer_key = ENV["CONSUMER_KEY_1"] # Your app consumer key
  bot.consumer_secret = ENV["CONSUMER_SECRET_1"] # Your app consumer secret
  bot.original = ENV["BOT_ORIGINAL_USER_1"]
  bot.tweet_pics = true
end

ReplyingBot.new(ENV["BOT_NAME_2"]) do |bot|
  bot.access_token = ENV["ACCESS_TOKEN_2"] # Token connecting the app to this account
  bot.access_token_secret = ENV["ACCESS_TOKEN_SECRET_2"] # Secret connecting the app to this account
  bot.consumer_key = ENV["CONSUMER_KEY_2"] # Your app consumer key
  bot.consumer_secret = ENV["CONSUMER_SECRET_2"] # Your app consumer secret
  bot.original = ENV["BOT_ORIGINAL_USER_2"]
  bot.tweet_pics = false
end

Picbot.new(ENV["PICBOT_NAME"]) do |bot|
  bot.access_token = ENV["PICBOT_ACCESS_TOKEN"] # Token connecting the app to this account
  bot.access_token_secret = ENV["PICBOT_ACCESS_TOKEN_SECRET"] # Secret connecting the app to this account
end
