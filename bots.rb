require 'twitter_ebooks'
require_relative 'picture_settings'
require_relative 'replying_bot'

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




#A bot that posts pics
class Picbot < Ebooks::Bot 

  attr_accessor :settings

  # Configuration here applies to all Picbots
  def configure
    self.consumer_key = ENV["PICBOT_CONSUMER_KEY"] # Your app consumer key
    self.consumer_secret = ENV["PICBOT_CONSUMER_SECRET"] # Your app consumer secret
    @settings = PictureSettingsContainer.new()
  end

  #SCHEDULER

  def on_startup
    scheduler.cron '*/30 * * * *' do
      sleep(5)
      picture_settings = settings.get_picture_settings
      tweet_a_picture(picture_settings)
    end
  end

  #TWEETING

  def tweet_a_picture(picture_settings)
    if rand<picture_settings.chance  
      tweet_a_picture_internal(picture_settings)
    else
      log "Not tweeting this time"
    end
  end

  def tweet_a_picture_internal(picture_settings)
    pictures = picture_settings.get_directory  
    begin
      retries ||= 0
      pic = select_a_picture(pictures)
      text = get_text(picture_settings.message, pic)
      pictweet(text,pic)
    rescue
      log "Couldn't tweet #{pic} for some reason"   
      retry if (retries += 1) < 5
    end
  end
  
  #HELPERS
  
  def select_a_picture(pictures)
    pic = pictures.sample
      while !verify_size(pic)
        log "file #{pic} too large, trying another"
        pic = pictures.sample
      end
    return pic
  end

  def get_text(message, pic)
    text = message + "\n" + get_url(pic)
    return text
  end

  def get_url(pic)
    if pic.include? "Pixiv"
      return get_pixiv_url(pic) 
    elsif pic.include? "Danbooru"
      return get_danbooru_url(pic) 
    else
      return ""
    end
  end

  def get_pixiv_url(pic)
    pixiv_id = pic.split('/').last.split('_').first
    return "" unless pixiv_id.length <= 8 && pixiv_id.scan(/\D/).empty?
    return "https://www.pixiv.net/member_illust.php?mode=medium&illust_id=" + pixiv_id
  end

  def get_danbooru_url(pic)
    danbooru_id = pic.split('_').last.split('.').first
    return "" unless danbooru_id.length <= 8 && danbooru_id.scan(/\D/).empty?
    return "http://www.danbooru.donmai.us/posts/" + danbooru_id
  end

  #Verify that the selected picture is small enough to upload to Twitter
  def verify_size(pic)
    file_size_in_mb = File.size(pic).to_f / 2**20
    if (pic.end_with? ".gif") || (pic.end_with? ".mp4")
      return file_size_in_mb<5
    else
      return file_size_in_mb<3
    end
  end

  # Logs info to stdout in the context of this bot
  def log(*args)
    timestamp = "[" + Time.now.inspect + "] "
    STDOUT.print timestamp + "@#{@username}: " + args.map(&:to_s).join(' ') + "\n"
    STDOUT.flush
  end
  
  
  #EVENTS - unused

  # Reply to a DM
  def on_message(dm)
    #do nothing
  end

  # Follow a user back
  def on_follow(user)
    #do nothing
  end

  # Reply to a mention
  def on_mention(tweet)
    #do nothing
  end

  # Reply to a tweet in the bot's timeline
  def on_timeline(tweet)
    #do nothing
  end

  def on_favorite(user, tweet)
    #don't do anything
  end

  def on_retweet(tweet)
    #don't do anything
  end
end

# Make bot
Picbot.new(ENV["PICBOT_NAME"]) do |bot|
  bot.access_token = ENV["PICBOT_ACCESS_TOKEN"] # Token connecting the app to this account
  bot.access_token_secret = ENV["PICBOT_ACCESS_TOKEN_SECRET"] # Secret connecting the app to this account
end
