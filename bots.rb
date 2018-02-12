require 'twitter_ebooks'

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

def top100; @top100 ||= model.keywords.take(100); end
def top20;  @top20  ||= model.keywords.take(20); end

#Standard replying ebooks bot
class ReplyingBot < Ebooks::Bot
  
  FILE_FORMATS = "{jpg,png,jpeg}"

  #The originating user
  attr_accessor :original, :model, :model_path

  # Configuration here applies to all ReplyingBots
  def configure
    # Consumer details come from registering an app at https://dev.twitter.com/
    # Once you have consumer details, use "ebooks auth" for new access tokens
    self.consumer_key = ENV["CONSUMER_KEY"] # Your app consumer key
    self.consumer_secret = ENV["CONSUMER_SECRET"] # Your app consumer secret

    # Users to block instead of interacting with
    self.blacklist = []

    # Range in seconds to randomize delay when bot.delay is called
    self.delay_range = 1..6

    @userinfo = {}
  end

  def on_startup
    load_model!

    # Tweet every hour with an 80% chance
    scheduler.cron '0 * * * *' do      
      if rand < 0.05
        tweet_a_picture()
      elsif rand < 0.8
        tweet(model.make_statement)
      else
        log "Not tweeting this time"
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
    # Become more inclined to pester a user when they talk to us
    userinfo(tweet.user.screen_name).pesters_left += 1
    delay do
      if rand < 0.25
        reply_with_image(tweet)
      else
        reply(tweet, model.make_response(meta(tweet).mentionless, meta(tweet).limit))
      end
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
        if rand < 0.01
          userinfo(tweet.user.screen_name).pesters_left -= 1
          reply(tweet, model.make_response(meta(tweet).mentionless, meta(tweet).limit))
        end
      elsif interesting
        favorite(tweet) if rand < 0.05
        if rand < 0.001
          userinfo(tweet.user.screen_name).pesters_left -= 1
          reply(tweet, model.make_response(meta(tweet).mentionless, meta(tweet).limit))
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

  def reply_with_image(ev, opts={})
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
      pic = images.sample

      log "Replying to @#{ev.user.screen_name} with:  #{text.inspect} - #{pic}"
      tweet = twitter.update_with_media(text, File.new(pic), opts.merge(in_reply_to_status_id: ev.id))
      conversation(tweet).add(tweet)
      tweet
    else
      log "Don't know how to reply to a #{ev.class}"
    end
  end

  def tweet_a_picture
    images = Dir.glob(ENV["RANDOM_IMAGE_DIR"] + "**/*.{#{FILE_FORMATS}}")
    pic = images.sample  
    pictweet("",pic)
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

# Make bot
ReplyingBot.new(ENV["BOT_NAME"]) do |bot|
  bot.access_token = ENV["ACCESS_TOKEN"] # Token connecting the app to this account
  bot.access_token_secret = ENV["ACCESS_TOKEN_SECRET"] # Secret connecting the app to this account
  bot.original = ENV["BOT_ORIGINAL_USER"]
end
