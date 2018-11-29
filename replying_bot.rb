require 'twitter_ebooks'
require_relative 'bot_info'
require_relative 'user_info'

#based on the bot example found at https://github.com/mispy/ebooks_example

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
      ENV["BOT_NAME_1"] => BotInfo.new(ENV["BOT_NAME_1"]),
      ENV["BOT_NAME_2"] => BotInfo.new(ENV["BOT_NAME_2"])
    }
  end  

  def top100; @top100 ||= model.keywords.take(100); end
  def top20;  @top20  ||= model.keywords.take(20); end

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

      text = rand < 0.05 ? "me irl" : ""
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
