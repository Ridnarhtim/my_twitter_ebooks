require 'date_easter'
require 'date'
require 'time'
require_relative 'seasons'

DEFAULT_CHANCE = 1

class PictureSettings

  FILE_FORMATS = "{jpg,png,jpeg,gif,mp4}"

  attr_accessor :seasons, :current_season, :new_season
  
  def initialize
    @seasons = Seasons.new
  end
  
  def update_season(season)
    if @current_season == season
      @new_season = false
    else
      @current_season = season
      @new_season = true
    end
  end
  
  def reset_season
    @new_season = true
  end
  
  def get_directory
    return Dir.glob(ENV["LEWD_IMAGE_DIR"] + "/" + @seasons.get(@current_season).folder + "/**/*.{#{FILE_FORMATS}}")
  end
  
  def get_chance
    @new_season ? @seasons.get(@current_season).initial_chance : DEFAULT_CHANCE
  end
  
  def get_reply_message
    season_details = @seasons.get(@current_season)
    season_details.include_in_replies ? season_details.get(@current_season).message : ""
  end
   
  def get_tweet_message
    @new_season ? @seasons.get(@current_season).message : ""
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

    now = Time.now
    today = Date.today
    easter = Date::easter(today.year)

    #Special days
    if today.month == 2 && today.day == 14
      @picture_settings.update_season("ValentinesDay")

    elsif today.month == easter.month && today.day == easter.day
      @picture_settings.update_season("Easter")

    elsif today.month == 10  && today.day == 31
      @picture_settings.update_season("Halloween")

    elsif today.month == 11 && today.day == 7
      @picture_settings.update_season("Navel")
      
    elsif today.month == 11 && today.day == 30
      @picture_settings.update_season("Ass")

    #Christmas
    elsif today.month == 12 && today.day.between?(25,26)
      @picture_settings.update_season("Christmas")

    elsif today.month == 12 && today.day == 24 && now >= Time.parse("8:00")
      @picture_settings.update_season("ChristmasEve")

    elsif today.month == 12 && today.day.between?(1,23) && it_is_morning
      @picture_settings.update_season("ChristmasCountdownMessage")

    elsif now.between?(Time.new(today.year,12,1,8,0,0),Time.new(today.year,12,24,8,00,00))
      @picture_settings.update_season("ChristmasCountdownImages")

    #Daily
    elsif it_is_morning
      @picture_settings.update_season("Morning")

    else
      @picture_settings.update_season("Default")
    end
  end

  def it_is_morning
    now = Time.now.between?(Time.parse("8:00"),Time.parse("8:01"))
  end
end
