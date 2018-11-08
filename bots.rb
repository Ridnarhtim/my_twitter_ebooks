require 'twitter_ebooks'
require 'date'
require 'date_easter'
require 'time'

#based on the bot example found at https://github.com/mispy/ebooks_example

# Information about a particular Twitter user we know
class UserInfo
  attr_reader :username

  # @return [Integer] how many times we can pester this user unprompted
  attr_accessor :pesters_left

  # @param username [String]
  def initialize(username)
    @username = username
    @pesters_left = 2
  end
end

# Information about a particular Bot we know
class BotInfo
  MAX_REPLIES = 10
  attr_accessor :replies_left

  def initialize()
    reset()
  end

  def reset()
    @replies_left = MAX_REPLIES
  end

  def should_reply_to()
    return rand<(@replies_left.to_f/MAX_REPLIES)
  end
end

def top100; @top100 ||= model.keywords.take(100); end
def top20;  @top20  ||= model.keywords.take(20); end

#Standard replying ebooks bot
class ReplyingBot < Ebooks::Bot
  
  FILE_FORMATS = "{jpg,png,jpeg,gif,mp4}"

  attr_accessor :original, :model, :model_path, :tweet_pics

  # Configuration here applies to all ReplyingBots
  def configure
    # Users to block instead of interacting with
    self.blacklist = ['mcamargo1997']

    # Range in seconds to randomize delay when bot.delay is called
    self.delay_range = 1..6

    @userinfo = {}
    @botinfo = {
      ENV["BOT_NAME_1"] => BotInfo.new(),
      ENV["BOT_NAME_2"] => BotInfo.new()
    }
  end

  def on_startup
    load_model!

    # Tweet every half hour with a 75% chance
    scheduler.cron '*/30 * * * *' do
      if rand < 0.05
        unless tweet_a_picture()
          tweet(make_statement_wrapper)
        end
      elsif rand < 0.75
        tweet(make_statement_wrapper)
      else
        log "Not tweeting this time"
      end

      #also reset bot-reply-counters
      @botinfo.each do |botname, bot|
        bot.reset()
      end
    end

    # Reload model every 24h (at 5 minutes past 2am)
    scheduler.cron '5 2 * * *' do  
      load_model!
    end
  end


  #EVENTS

  # Reply to a DM
  def on_message(dm)
    delay do
      reply(dm, model.make_response(dm.text))
    end
  end

  # Follow a user back
  def on_follow(user)
    if can_follow?(user.screen_name)
      follow(user.screen_name)
    else
      log "Not following @#{user.screen_name}"
    end
    # follow(user.screen_name)
  end

  # Reply to a mention
  def on_mention(tweet)

    #this is a bot we know
    if @botinfo.key?(tweet.user.screen_name)
      bot = @botinfo[tweet.user.screen_name]
      if bot.should_reply_to()
        #reply to the bot
        bot.replies_left -= 1
        sleep(rand(5..30))
        do_reply(tweet)
      else
        log "not replying to bot"
      end
	  
    else
      # Become more inclined to pester a user when they talk to us
      userinfo(tweet.user.screen_name).pesters_left += 1
      delay do
        do_reply(tweet)
      end
    end
  end

  def do_reply(tweet)
    if rand < 0.2
      unless reply_with_image(tweet)
        reply(tweet, make_response_wrapper(tweet))
      end
    else
      reply(tweet, make_response_wrapper(tweet))
    end
  end

  # Reply to a tweet in the bot's timeline
  def on_timeline(tweet)
    #don't reply to retweets
    return if tweet.retweeted_status?
    #check if bot can "pester" this user
    return unless can_pester?(tweet.user.screen_name)

    #see if bot finds the tweet interesting (based off top 100 / top 20 model words)
    tokens = Ebooks::NLP.tokenize(tweet.text)
    interesting = tokens.find { |t| top100.include?(t.downcase) }
    very_interesting = tokens.find_all { |t| top20.include?(t.downcase) }.length > 2

    #do various actions depending on how interesting the tweet is
    delay do
      if very_interesting
        favorite(tweet) if rand < 0.5
        retweet(tweet) if rand < 0.1
        if rand < 0.05 #0.01
          userinfo(tweet.user.screen_name).pesters_left -= 1
          reply(tweet, make_response_wrapper(tweet))
        end
      elsif interesting
        favorite(tweet) if rand < 0.05
        if rand < 0.01 #0.001
          userinfo(tweet.user.screen_name).pesters_left -= 1
          reply(tweet, make_response_wrapper(tweet))
        end
      end
    end
  end

  def on_favorite(user, tweet)
    #don't do anything
  end

  def on_retweet(tweet)
    #don't do anything
  end


  #HELPERS

  #make a response that doesn't end with ...
  def make_response_wrapper(tweet)
    response = model.make_response(meta(tweet).mentionless, meta(tweet).limit)
    retries ||= 0
    while response.end_with? "..." and retries < 5
      log "Not tweeting #{response}"
      response = model.make_response(meta(tweet).mentionless, meta(tweet).limit)
      retries += 1 
    end
    return response
  end

  #make a statement that doesn't end with ...
  def make_statement_wrapper
    statement = model.make_statement
    retries ||= 0
    while (statement.end_with? "..." or statement.empty?) and retries < 5
      log "Not tweeting #{statement}"
      statement = model.make_statement
      retries += 1
    end
    if rand < 0.025
      statement = tag_other_bot(statement)
    end
    return statement
  end

  def tag_other_bot(statement)
    if @username == ENV["BOT_NAME_1"]
      other_bot = ENV["BOT_NAME_2"]
    elsif @username == ENV["BOT_NAME_2"]
      other_bot = ENV["BOT_NAME_1"]
    end

    if other_bot != nil
      statement = "@" + other_bot + " " + statement
    end

    return statement
  end

  #Reply with a picture
  def reply_with_image(ev, opts={})
    return false unless tweet_pics
    opts = opts.clone

    if ev.is_a? Twitter::Tweet
      meta = meta(ev)

      if conversation(ev).is_bot?(ev.user.screen_name)
        log "Not replying to suspected bot @#{ev.user.screen_name}"
        return false
      end

      text = ""
      text = meta.reply_prefix + text unless text.match(/@#{Regexp.escape ev.user.screen_name}/i)

      images = Dir.glob(ENV["REACTION_IMAGE_DIR"] + "/**/*.{#{FILE_FORMATS}}")

      begin
        retries ||= 0        
        pic = images.sample
        while !verify_size(pic)
          log "file #{pic} too large, trying another"
          pic = images.sample
        end

        log "Replying to @#{ev.user.screen_name} with:  #{text.inspect} - #{pic}"
        tweet = twitter.update_with_media(text, File.new(pic), opts.merge(in_reply_to_status_id: ev.id))
        conversation(tweet).add(tweet)
        tweet
        return true
      rescue       
        log "Couldn't tweet #{pic} for some reason"
        retry if (retries += 1) < 5
      end
    else
      log "Don't know how to reply to a #{ev.class}"
    end
    return false
  end

  #Tweet out a picture
  def tweet_a_picture
    return false unless tweet_pics
    images = Dir.glob(ENV["RANDOM_IMAGE_DIR"] + "/**/*.{#{FILE_FORMATS}}")
    begin
      retries ||= 0
      pic = images.sample
      while !verify_size(pic)
        log "file #{pic} too large, trying another"
        pic = images.sample
      end
      pictweet("",pic)
      return true
    rescue
      log "Couldn't tweet #{pic} for some reason"   
      retry if (retries += 1) < 5
    end
    return false
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
  # Find information we've collected about a user
  # @param username [String]
  # @return [Ebooks::UserInfo]
  def userinfo(username)
    @userinfo[username] ||= UserInfo.new(username)
  end

  # Check if we're allowed to send unprompted tweets to a user
  # @param username [String]
  # @return [Boolean]
  def can_pester?(username)
    userinfo(username).pesters_left > 0
  end

  # Only follow our original user or people who are following our original user
  # @param user [Twitter::User]
  def can_follow?(username)
    @original.nil? || username.casecmp(@original) == 0 || twitter.friendship?(username, @original)
  end

  #favourite a tweet
  def favorite(tweet)
    if can_follow?(tweet.user.screen_name)
      super(tweet)
    else
      log "Unfollowing @#{tweet.user.screen_name}"
      twitter.unfollow(tweet.user.screen_name)
    end
  end

  # Logs info to stdout in the context of this bot
  def log(*args)
    timestamp = "[" + Time.now.inspect + "] "
    STDOUT.print timestamp + "@#{@username}: " + args.map(&:to_s).join(' ') + "\n"
    STDOUT.flush
  end

  #load the model from file
  private
  def load_model!
    @model_path ||= "model/#{original}.model"

    log "Loading model #{model_path}"
    @model = Ebooks::Model.load(model_path)
  end

end


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
  
  FILE_FORMATS = "{jpg,png,jpeg,gif,mp4}"

  # Configuration here applies to all Picbots
  def configure
    self.consumer_key = ENV["PICBOT_CONSUMER_KEY"] # Your app consumer key
    self.consumer_secret = ENV["PICBOT_CONSUMER_SECRET"] # Your app consumer secret
  end

  def on_startup
    # Tweet every half hour with a 80% chance
    scheduler.cron '*/30 * * * *' do
      if Time.now.between?(Time.parse("7:59"),Time.parse("8:01"))
        tweet_a_picture("Good morning")
      elsif rand < 0.8
        tweet_a_picture("")
      else
        log "Not tweeting this time"
      end
    end
  end


  #EVENTS

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


  #HELPERS

  #Tweet out a picture
  def tweet_a_picture(message)
    images = pick_image_folder
    begin
      retries ||= 0
      pic = images.sample
      while !verify_size(pic)
        log "file #{pic} too large, trying another"
        pic = images.sample
      end
      text = get_text(message, pic)
      pictweet(text,pic)
      return true
    rescue
      log "Couldn't tweet #{pic} for some reason"   
      retry if (retries += 1) < 5
    end
    return false
  end

  def pick_image_folder
    today = Date.today
    easter = Date::easter(today.year)    

    if(today.month == 2 && today.day == 14)
      folder = "/Seasonal/ValentinesDay"

    elsif(today.month == easter.month && today.day == easter.day)
      folder = "/Seasonal/Easter"

    elsif(today.month == 10  && today.day == 31)
      folder = "/Seasonal/Halloween"

    elsif(today.month == 11 && today.day == 7)
      folder = "/Seasonal/Navel"
 
    elsif(today.month == 12 && today.day.between?(24,26))
      folder = "/Seasonal/Christmas"

    else
      folder = "/Bot"      
    end

    base_path = ENV["LEWD_IMAGE_DIR"]
    images = Dir.glob(base_path + folder + "/**/*.{#{FILE_FORMATS}}")
    return images
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
end

# Make bot
Picbot.new(ENV["PICBOT_NAME"]) do |bot|
  bot.access_token = ENV["PICBOT_ACCESS_TOKEN"] # Token connecting the app to this account
  bot.access_token_secret = ENV["PICBOT_ACCESS_TOKEN_SECRET"] # Secret connecting the app to this account
end
