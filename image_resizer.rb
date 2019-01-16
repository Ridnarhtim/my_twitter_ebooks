require "mini_magick"
require 'rake/pathmap'

class ImageResizer

  SUPPORTED_FORMATS = [".jpg",".png",".jpeg"]

  def self.resize(image_path)
    return unless SUPPORTED_FORMATS.include? File.extname(image_path)

    image = MiniMagick::Image.open(image_path)
    image.resize "1024"
    output_file = image_path.pathmap "%X-resized%x"
    image.write output_file

    if image.valid? then return output_file end
  end
end
