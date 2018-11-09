require 'date'

SeasonStruct = Struct.new(:folder, :message, :initial_chance)

class Season

  attr_reader :seasons

  def initialize
    @seasons = {
      "ValentinesDay" => SeasonStruct.new("Seasonal/ValentinesDay","Happy Valentine's Day",1),
      "Easter" => SeasonStruct.new("Seasonal/Easter","Happy Easter",1),
      "Halloween" => SeasonStruct.new("Seasonal/Halloween","Happy Halloween",1),
      "Navel" => SeasonStruct.new("Seasonal/Navel","Happy #いいおなかの日",1),
      "ChristmasCountdownMessage" => SeasonStruct.new("Seasonal/Christmas",christmas_timer_message,1),
      "ChristmasCountdownImages" => SeasonStruct.new(christmas_folder_chance,"",0.8),
      "ChristmasEver" => SeasonStruct.new("Seasonal/Christmas","It's Almost Christmas!",1),
      "Christmas" => SeasonStruct.new("Seasonal/Christmas","Merry Christmas",1),
      "Morning" => SeasonStruct.new("Seasonal/Morning","Good morning",1),
      "Default" => SeasonStruct.new("Bot","",DEFAULT_CHANCE)
    } 
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
  
  def get(season_name)
    @seasons[season_name]
  end 
end
