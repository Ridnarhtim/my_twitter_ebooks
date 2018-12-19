require "mini_magick"

class ImageResizer

	SUPPORTED_FORMATS = [".jpg",".png",".jpeg"]
	OUTPUT_FILE = "/home/pi/Pictures/Resized/out"

	def self.resize(image_path)
		return false unless SUPPORTED_FORMATS.include? File.extname(image_path)
		
		image = MiniMagick::Image.open(image_path)
		image.resize "1024"
		image.write OUTPUT_FILE
		
		return image.valid?
	end
end
