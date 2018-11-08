class PictureSettings

  FILE_FORMATS = "{jpg,png,jpeg,gif,mp4}"

  attr_reader :picture_folder, :message, :chance
  
  def initialize(picture_folder, message, chance)
    @picture_folder = picture_folder
    @message = message
    @chance = chance
  end
  
  def get_directory 
    return Dir.glob(ENV["LEWD_IMAGE_DIR"] + "/" + @picture_folder + "/**/*.{#{FILE_FORMATS}}")
  end
end
