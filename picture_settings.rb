require 'date_easter'
require 'date'
require 'time'

class PictureSettings

  FILE_FORMATS = "{jpg,png,jpeg,gif,mp4}"
  DEFAULT_CHANCE = 0.8

  attr_reader :picture_folder, :message
  attr_accessor :chance, :new_season
  
  def initialize(picture_folder, message, chance)
    @picture_folder = picture_folder
    @message = message
    @chance = chance
    @new_season = true
  end
  
  def get_directory 
    return Dir.glob(ENV["LEWD_IMAGE_DIR"] + "/" + @picture_folder + "/**/*.{#{FILE_FORMATS}}")
  end
  
  def reset
    @chance = DEFAULT_CHANCE
    @new_season = false
  end
   
  def get_message_if_new
    return @new_season ? @message : ""
  end
end

class PictureSettingsContainer
  
  DEFAULT_SETTINGS = PictureSettings.new("Bot","", PictureSettings::DEFAULT_CHANCE)

  attr_accessor :special_settings
  
  def get_picture_settings(reset: true)
    update_special_settings(reset)
    return @special_settings || DEFAULT_SETTINGS
  end
  
  def update_special_settings(reset)
    if reset then @special_settings&.reset end
  
    today = Date.today
    easter = Date::easter(today.year)

    if(today.month == 2 && today.day == 14)
      @special_settings ||= PictureSettings.new("Seasonal/ValentinesDay","Happy Valentine's Day",1)

    elsif(today.month == easter.month && today.day == easter.day)
      @special_settings ||= PictureSettings.new("Seasonal/Easter","Happy Easter",1)

    elsif(today.month == 10  && today.day == 31)
      @special_settings ||= PictureSettings.new("Seasonal/Halloween", "Happy Halloween",1)

    elsif(today.month == 11 && today.day == 7)
      @special_settings ||= PictureSettings.new("Seasonal/Navel", "Happy #いいおなかの日!",1)
      
    elsif(today.month == 12 && today.day.between?(25,26))
      @special_settings ||= PictureSettings.new("Seasonal/Christmas", "Merry Christmas",1)
    
    elsif(Time.now.between?(Time.parse("7:59"),Time.parse("8:01")))
      @special_settings ||= PictureSettings.new("Seasonal/Morning", "Good morning",1)

    else
      @special_settings = nil
    end
  end
end
