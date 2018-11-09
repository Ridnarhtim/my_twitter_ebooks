require 'date_easter'
require 'date'
require 'time'

DEFAULT_CHANCE = 0.8
Season = Struct.new(:folder, :message, :initial_chance)
SEASONS = {
      "ValentinesDay" => Season.new("Seasonal/ValentinesDay","Happy Valentine's Day",1),
      "Easter" => Season.new("Seasonal/Easter","Happy Easter",1),
      "Halloween" => Season.new("Seasonal/Halloween","Happy Halloween",1),
      "Navel" => Season.new("Seasonal/Navel","Happy #いいおなかの日!",1),
      "ChristmasEve" => Season.new("Seasonal/Christmas","It's almost Christmas",1),
      "Christmas" => Season.new("Seasonal/Christmas","Merry Christmas",1),
      "Morning" => Season.new("Seasonal/Morning","Good morning",1),
      "Default" => Season.new("Bot","",DEFAULT_CHANCE)
    }

class PictureSettings

  FILE_FORMATS = "{jpg,png,jpeg,gif,mp4}"

  attr_accessor :current_season, :new_season
  
  def update_season(season)
    if @current_season == season
      @new_season = false
    else
      @current_season = season
      @new_season = true
    end
  end
  
  def get_directory 
    return Dir.glob(ENV["LEWD_IMAGE_DIR"] + "/" + SEASONS[@current_season].folder + "/**/*.{#{FILE_FORMATS}}")
  end
  
  def get_chance
    @new_season ? SEASONS[@current_season].initial_chance : DEFAULT_CHANCE
  end
  
  def get_message
    SEASONS[@current_season].message
  end
   
  def get_message_if_new
    @new_season ? SEASONS[@current_season].message : ""
  end
end

class PictureSettingsContainer
  
  attr_accessor :picture_settings
  
  def initialize
    @picture_settings = PictureSettings.new
  end
  
  def get_updated_picture_settings
    update_season
    return @picture_settings
  end
  
  def update_season
  
    today = Date.today
    now = Time.now
    easter = Date::easter(today.year)

    if(today.month == 2 && today.day == 14)
      @picture_settings.update_season("ValentinesDay")

    elsif(today.month == easter.month && today.day == easter.day)
      @picture_settings.update_season("Easter")

    elsif(today.month == 10  && today.day == 31)
      @picture_settings.update_season("Halloween")

    elsif(today.month == 11 && today.day == 7)
      @picture_settings.update_season("Navel")
    
    elsif(today.month == 12 && today.day.between?(25,26))
      @picture_settings.update_season("Christmas")
    
    elsif(now.between?(Time.parse("8:00"),Time.parse("8:01")))
      @picture_settings.update_season("Morning")

    else
      @picture_settings.update_season("Default")
    end
  end
end
