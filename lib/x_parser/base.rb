require 'zip'

class XParser::Base
  extend XParser::Methods

  attr_reader :errors

  Struct.new('Value', :text)

  def import files, importer
    [ files ].flatten.each do |file|
      Rails.logger.info("File to unpack #{file}")
      touch_file(file) do |xml|
        binding.pry
        attrs = parse(xml)

        if errors.blank?
          importer.import(attrs)
        else
          Rails.logger.error(errors.inspect)
        end
      end
    end
  end

  def parse xml
    filtered = xml.gsub(/[\r\u{feff}]/,"")
    doc = Nokogiri::XML.parse(filtered)
    binding.pry
    each_field_for(self.class.schemes[nil], doc)
  end

  protected

  def touch_file file
    if file =~ /\.zip$/i
      Dir.mktmpdir do |dir|
        unzip(dir, file).each do |xml|
          Rails.logger.info("Xml file to proceed #{xml}")

          yield(IO.read(xml))
        end
      end
    else
      yield(IO.read(file))
    end
  end

  def unzip dir, file
    Zip::File.open(file) do |zip_file|
      zip_file.map do |entry|
        tname = File.join(dir, file, entry.name)
        FileUtils.mkdir_p(File.dirname(tname))
        entry.extract(tname)
        tname
      end
    end
  end

  def each_field_for schema, context
    schema.map do |name, options|
      real_name = options[:multiple] && name.pluralize || name
      value = type_value(name, options, context)
      is_assing = [Array, Hash].any? { |x| x === value }
      key = is_assing && "#{real_name}_attributes" || real_name
      [ key, value ]
    end.select {|_, v| v }.to_h
  end

  def type_value name, options, context
    case options[:type]
    when :field
      select_value(name, context, options).text

    when :scheme
      scheme_name = self.class.scheme_name(options[:as] || name)
      value = select_value(name, context, options)
      if options[:multiple]
        value.map { |v| each_field_for(self.class.schemes[scheme_name], v) }
      else
        each_field_for(self.class.schemes[scheme_name], value)
      end if value

    when :reference
      in_context = value(name, context, options)
      if in_context.text
        find_for(name, select_value(options[:by], in_context, {context: ""}).text,
          options)
      end
    end
  end

  def model_for name, options
    (options[:as] || name).to_s.singularize.camelize.constantize
  end

  def find_for name, value, options
    field = options[:field] || options[:by]
    model_for(name, options).where(field => value).first
  end

  def search_in context, path, options
    res = /\w+:/ =~ path && context.xpath(path) || context.css(to_css(path))

    options[:multiple] && res || res.first
  end

  def to_css path
    ">" + path.split('//').map { |x| x.sub(/.*:/,'') }.join(' ')
  end

  # +select_value+ выборка общего обработчика контекста для заданного атрибута.
  # Осуществляет выбор между обработчиками встроенным и заданным пользователем в
  # подробностях (options).
  #
   def select_value name, context, options
    if options[:handler]
      value = case options[:handler]
      when Proc, Method
        options[:handler][ name, context, options ]
      else
        send(options[:handler], name, context, options)
      end

      Struct::Value.new(value)
    else
      value(name, context, options)
    end
  end

  def value name, context, options
#    binding.pry if name == 'description'
    paths = paths(name, options)
    new_context = paths.reduce(nil) do |new_context, path|
      new_context.blank? && search_in(context, path, options) || new_context
    end
#      binding.pry if ! new_context # TODO

    if options[:required] && ! new_context
      @errors[name] =
      "has invalid new context for paths: #{paths.join(', ')}"
    end

    if new_context.respond_to?(:text)
      new_context
    else
      Struct::Value.new(new_context)
    end
  end

  # [1,2].map { |x| [3,4].map { |y| [x, y] } }.flatten(1)
  #=> [[1, 3], [1, 4], [2, 3], [2, 4]]
  def integrate ary1, ary2
    ary1.map { |x| ary2.map { |y| [x, y] } }.flatten(1)
  end

  # +join_context+ объединяет переданные строки контекста в единую строку в
  # формате xpath.
  #
  # Пример 1:
  #   args: "ns2:documentationDelivery", "deliveryEndDateTime"
  #   out: "ns2:documentationDelivery//:deliveryEndDateTime"]
  #
  # Пример 2:
  #   args: "", "ns2:contact"
  #   out: "ns2:contact"
  #
  # Пример 3:
  #   args: nil, "contact", nil
  #   out: ":contact"
  #
  def paths name, options
    froms = [ options[:from] || name ].flatten.compact
    ctxs = [ options[:reset_context] || options[:context] ].flatten.compact
#    binding.pry
    integrate(ctxs, froms).map do |from|
      from.map { |a| a.split('/') }.flatten.map { |a| /:/ =~ a && a || ":#{a}" }.unshift("").join("//")
    end
  end

  def initialize
    @errors = {}
  end
end
