class Ldap::PersonPhoto < Ldap::Entity

  attr_accessor :uid, :dn, :upload_image, :objectclass

  DN_ATTR = :uid
  CLASSES = []

  validates :upload_image, upload_image: true

  def get(name_size)
    if self.uid and self.dn
      unless File.exist?(default)
        filter = Net::LDAP::Filter.eq(DN_ATTR, uid)
        result = Ldap::Person.search(filter, ['jpegPhoto'])
        save_and_resize(result)
      end
      image(name_size)
    else
      dummy_file(name_to_size(name_size))
    end
  end

  def update(params)
    self.upload_image = params['upload_image']
    if self.valid?
      file =  resize(name_to_size('default'), self.upload_image.path)
      flush
      @@ldap.replace_attribute self.dn, :jpegphoto, File.binread(file)
    end
  end

  def flush
    FileUtils.remove(default) if File.exist?(default)
  end

  protected

  def resize(size, file)
    image = Magick::Image.read(file).first
    main_image = image.change_geometry!("#{size}x#{size}") { |cols, rows, img|
      if cols < size || rows < size
        img.resize!(cols, rows)
        bg = Magick::Image.new(size, size){self.background_color = "white"}
        bg.composite(img, Magick::CenterGravity, Magick::OverCompositeOp)
      else
        img.resize!(cols, rows)
      end
    }
    main_image.write "#{file}-convert.jpg"
    "#{file}-convert.jpg"
  end

  def thumbnails(size)
    image = Magick::Image.read(default).first
    image.change_geometry!("#{size}x#{size}") { |cols, rows, img|
      newimg = img.resize(cols, rows)
      newimg.write(path(size))
    }
  end

  def save_and_resize(result)
    if result.blank? or result.first['jpegPhoto'].blank?
      FileUtils.copy(dummy_file, default)
    else
      f = File.open(default, 'wb')
      f.write(result.first['jpegPhoto'].first)
      f.close
    end

    Settings.photo.each do |size|
      thumbnails(name_to_size(size.first)) if size.first != 'default'
    end
  end

  def default
    path(name_to_size('default'))
  end

  def dummy_file(size='500')
    "#{media_path}/photo/default/photo#{size}.jpg"
  end

  def image(name_size)
    return path(name_to_size(name_size)) if File.exist?(default)
    dummy_file
  end

  def dir_path(size)
    "/#{size}/#{name_image_file[0]}/#{name_image_file[1,2]}"
  end

  def name_image_file
    "#{Digest::MD5::hexdigest(self.dn).downcase}.jpg"
  end

  def path(size)
    dir = "#{media_path}/photo/cache#{dir_path(size)}"
    FileUtils.mkdir_p dir
    "#{dir}/#{name_image_file}"
  end

  def media_path
    return "#{Settings.media_path}" if Settings.media_path
    "#{Rails.root}/media"
  end

  def name_to_size(name_size)
    return Settings.photo[name_size] if Settings.photo.has_key?(name_size)
    Settings.photo['default']
  end
end
