# Information about a particular Bot we know
class BotInfo
  MAX_REPLIES = 10
  
  attr_reader :username
  attr_accessor :replies_left

  def initialize(username)
    @username = username
    reset()
  end

  def reset()
    @replies_left = MAX_REPLIES
  end

  def should_reply_to()
    return rand<(@replies_left.to_f/MAX_REPLIES)
  end
end
