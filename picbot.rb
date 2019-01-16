require 'twitter_ebooks'
require 'json'
require_relative 'picture_settings'
require_relative 'image_resizer'

#A bot that posts pics
class Picbot < Ebooks::Bot 

  REPEAT_CYCLE_LENGTH = 1500
  
  attr_accessor :settings_container, :recently_tweeted

  # Configuration here applies to all Picbots
  def configure
    self.consumer_key = ENV["PICBOT_CONSUMER_KEY"] # Your app consumer key
    self.consumer_secret = ENV["PICBOT_CONSUMER_SECRET"] # Your app consumer secret
    
    @settings_container = PictureSettingsContainer.new()
    buffer = File.open(ENV["PICBOT_NAME"] + '_tweeted_pics.json', 'r').read
    @recently_tweeted = JSON.parse(buffer)
    
    # Range in seconds to randomize delay when bot.delay is called
    self.delay_range = 2..6
  end

  #SCHEDULER

  def on_startup
    scheduler.cron '*/30 * * * *' do
      sleep(1)
      picture_settings = @settings_container.get_updated_picture_settings
      tweet_a_picture(picture_settings)
    end
  end

  #TWEETING

  def tweet_a_picture(picture_settings)
    if rand < picture_settings.get_chance
      tweet_a_picture_internal(picture_settings)
    else
      log "Not tweeting this time"
    end
  end

  def tweet_a_picture_internal(picture_settings)
    pictures = picture_settings.get_directory
    pic = nil
    begin
      retries ||= 0
      pic = select_a_picture(pictures)
      text = get_text(picture_settings.get_tweet_message, pic)
      pictweet(text,pic)
    rescue => exception
      retry if (retries += 1) < 5
      puts exception
    end
    
    #delete file if it was resized
    if pic.include? "-resized"
      File.delete(pic)
    end
  end
  

  
  #HELPERS
  
  def select_a_picture(pictures)
    pic = nil
    
    #check if anything in New directory that hasn't been tweeted yet
    newpics = pictures.select {|pic| (pic.include? "/New/") && !(@recently_tweeted.include?(pic))}
    
    if(newpics.any?)
      pictures = newpics
    end
    
    loop do
      pic = pictures.sample
      if was_recently_tweeted(pic)
        log "Not tweeting #{pic}: recently tweeted"

      elsif !verify_size(pic)
        #try to resize image
        if resized = ImageResizer.resize(pic)
          log "image resized: " + pic
          @recently_tweeted.push(pic)
          pic = resized
          break
        else
          log "Not tweeting #{pic}: too large"
        end
      
      else
        @recently_tweeted.push(pic)
        break
      end
    end
    
    if @recently_tweeted.size > REPEAT_CYCLE_LENGTH
      @recently_tweeted.drop(1)
    end
    
    File.open(ENV["PICBOT_NAME"] + "_tweeted_pics.json","w") do |f|
      f.write(@recently_tweeted.to_json)
    end
    
    return pic
  end

  def was_recently_tweeted(pic)
    @recently_tweeted.include? pic
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
    return "http://danbooru.donmai.us/posts/" + danbooru_id
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
    
  #EVENTS
  
  # Reply to a mention if it contains "gib lewd"
  def on_mention(tweet)
    return unless (tweet.text =~ /gib lewd/i) != nil
    delay do
      reply_with_image(tweet)
    end
  end

  #Reply with a picture
  def reply_with_image(tweet, opts={})
    opts = opts.clone
    meta = meta(tweet)

    if conversation(tweet).is_bot?(tweet.user.screen_name)
      log "Not replying to suspected bot @#{tweet.user.screen_name}"
      return false
    end
    
    picture_settings = @settings_container.picture_settings
    pictures = picture_settings.get_directory

    begin
      retries ||= 0
      pic = select_a_picture(pictures)
      log "Replying to @#{tweet.user.screen_name} with:  #{pic}"
      
      text = get_text(picture_settings.get_reply_message, pic)
      text = meta.reply_prefix + text unless text.match(/@#{Regexp.escape tweet.user.screen_name}/i)
      
      tweet = twitter.update_with_media(text, File.new(pic), opts.merge(in_reply_to_status_id: tweet.id))
      conversation(tweet).add(tweet)
      tweet
    rescue
      log "Couldn't reply with #{pic} for some reason"
      retry if (retries += 1) < 5
    end
  end

  # Reply to a tweet in the bot's timeline
  def on_timeline(tweet)
    #do nothing
  end
end
