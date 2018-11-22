require 'date'

SeasonStruct = Struct.new(:folder, :message, :initial_chance, :include_in_replies)

class Seasons

  attr_reader :seasons

  def initialize
    @seasons = {
      "ValentinesDay" => SeasonStruct.new("Seasonal/ValentinesDay","Happy Valentine's Day",1,true),
      "Easter" => SeasonStruct.new("Seasonal/Easter","Happy Easter",1,true),
      "Halloween" => SeasonStruct.new("Seasonal/Halloween","Happy Halloween",1,true),
      "Navel" => SeasonStruct.new("Seasonal/Navel","Happy #いいおなかの日",1,true),
      "ChristmasCountdownMessage" => SeasonStruct.new("Seasonal/Christmas",christmas_timer_message,1,false),
      "ChristmasCountdownImages" => SeasonStruct.new(christmas_folder_chance,"",0.8,true),
      "ChristmasEver" => SeasonStruct.new("Seasonal/Christmas","It's Almost Christmas!",1,false),
      "Christmas" => SeasonStruct.new("Seasonal/Christmas","Merry Christmas",1,true),
      "Morning" => SeasonStruct.new("Seasonal/Morning","Good morning degenerates",1,true),
      "Default" => SeasonStruct.new("Bot","",0.8,false)
    }
  end

  def get(season_name)
    @seasons[season_name]
  end 

  def days_to_christmas
    (Date.parse("2018-12-24") - Date.today).to_i
  end

  def christmas_timer_message
    days_to_christmas.to_s + " days until christmas"
  end

  def christmas_folder_chance
    rand < (0.5/Math.sqrt(days_to_christmas)) ? "Seasonal/Christmas" : "Bot"
  end
end
