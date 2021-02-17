require 'date'

SeasonStruct = Struct.new(:folder, :message, :initial_chance, :include_in_replies)

class Seasons

  def get(season_name)
    case season_name
    when "ValentinesDay"
      SeasonStruct.new("Seasonal/ValentinesDay","Happy Valentine's Day",1,true)
    when "Easter"
      SeasonStruct.new("Seasonal/Easter","Happy Easter",1,true)
    when "Halloween"
      SeasonStruct.new("Seasonal/Halloween","Happy Halloween",1,true)
    when "Ass"
      SeasonStruct.new("Bot/Ass","It's #いいおしりの日 - Ass pics all day!",1,true)
    when "Navel"
      SeasonStruct.new("Bot/Navel","It's #いいおなかの日 - Nice tummies all day!",1,true)
    when "Tits"
      SeasonStruct.new("Bot/Tits","It's #いいおっぱいの日 - Titty pics all day!",1,true)
    when "ChristmasCountdownMessage"
      SeasonStruct.new("Seasonal/Christmas",christmas_timer_message,1,false)
    when "ChristmasCountdownImages"
      SeasonStruct.new(christmas_folder_chance,"",1,true)
    when "ChristmasEve"
      SeasonStruct.new("Seasonal/Christmas","It's Almost Christmas!",1,false)
    when "Christmas"
      SeasonStruct.new("Seasonal/Christmas","Merry Christmas",1,true)
    when "Morning"
      SeasonStruct.new("Seasonal/Morning",morning_message,1,true)
    when "Default"
      SeasonStruct.new("Bot","",1,false)
    end
  end 

  def morning_message
    rand < 0.05 ? "Good morning degenerates" : "Good morning"
  end  

  def days_to_christmas
    (Date.new(Date.today.year,12,25) - Date.today).to_i
  end

  def christmas_timer_message
    days_to_christmas.to_s + " days until christmas"
  end

  def christmas_folder_chance
    rand < (0.5/Math.sqrt(days_to_christmas)) ? "Seasonal/Christmas" : "Bot"
  end
end
