require 'zip'
require 'nokogiri'

class XParser::Base
  extend XParser::Methods

  attr_reader :errors

  Struct.new('Value', :text)

  def import files, importer
    [ files ].flatten.each do |file|
      Rails.logger.info("File to unpack #{file}")
      touch_file(file) do |xml|
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

  def each_field_for schema, xml_context
    schema.map do |name, options|
      real_name = options[:multiple] && name.pluralize || name
      value = type_value(name, options, xml_context)

      is_assign = [Array, Hash].any? { |x| x === value }
      key = is_assign && "#{real_name}_attributes" || real_name

      value =
      if (!( handler = handler_for(options[:if])) || handler[value])
        value
      else
        nil
      end

      [ key, value ]
    end.compact.select {|_, v| v }.to_h
  end

  def type_value name, options, xml_context
    case options[:type]
    when :field
      value, = select_value(name, xml_context, options[:contexts], options)
      value.text

    when :scheme
      scheme_name = self.class.scheme_name(options[:as] || name)
      value, = select_value(name, xml_context, options[:contexts], options)
      if options[:multiple]
        value.map { |v| each_field_for(self.class.schemes[scheme_name], v) }
      else
        each_field_for(self.class.schemes[scheme_name], value)
      end if value.text.present?

    when :reference
      new_contexts = self.class.filter_hashes(options[:contexts],
        XParser::Methods::PURE_CONTEXT_KEYS)
      inx, index = select_value(name, xml_context, new_contexts, options)

      if inx.text
        inc = options[:contexts][index]
        begin
          value, = select_value(inc[:by], inx, this_contexts(inc), options)
        rescue NoMethodError
          error(name, "field error for '#{inc[:by]}' in context: #{inx.inspect}")
        end

        field = inc[:field] || inc[:by]
        model = model_for(name, options)
        begin
          model.where(field => value.text).first ||
          model.where("? ~* #{field}", value.text).order(code: :desc).first
        rescue Java::JavaLang::NoSuchMethodError
          error(name, "field is unavailable to set via referenced model " +
            " '#{model}' with data: #{inx.text}")
        end
      end
    end
  end

  def error name, error
    @errors[name] ||= []
    @errors[name] << error

    nil
  end

  def this_contexts in_context
    [ in_context.merge({context: [""], from: nil}) ]
  end

  def model_for name, options
    (options[:as] || name).to_s.singularize.camelize.constantize
  end

  def search_in xml_context, path, options
    res = xml_context.xpath(path)

    options[:multiple] && res || res.first
  end

  # +select_value+ выборка общего обработчика контекста для заданного атрибута.
  # Осуществляет выбор между обработчиками встроенным и заданным пользователем в
  # подробностях (options).
  #
  def select_value name, xml_context, contexts, options
    value =
    contexts.map.with_index do |c, i|
      [ c, i ]
    end.reduce([nil, nil]) do |(value, val_index), (context, index)|
      next [value, val_index] if value && value.text

      new =
      if context[:handler]
        handled_value(context[:handler], name, xml_context, context, options)
      else
        value(name, xml_context, context, options)
      end

      [ new, index ]
    end

    if options[:required] && value[0].nil?
      error(name, "field is required")
    end

    value
  end

  def handler_for handler
    case handler
    when Proc, Method
      handler
    when NilClass
      nil
    else
      self.method(handler)
    end
  end

  def handled_value handler, name, xml_context, context, options
    value = value(name, xml_context, context, options)

    method = handler_for(handler)

#    new_value =
#    if context[:by]
#      c = [ this_contexts(context).first.merge(handler: nil) ]
#      select_value(context[:by], value, c, options).first
#    else
#      value
#    end
#
    args = [ value.text, name, xml_context, options ]

    Struct::Value.new(method[ *args[0...method.arity]])
  end

  def value name, xml_context, context, options
    paths = paths(name, context)
    new_context = paths.reduce(nil) do |new_context, path|
      new_context.blank? && search_in(xml_context, path, options) || new_context
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
  #   out: ".//ns2:documentationDelivery//:deliveryEndDateTime"]
  #
  # Пример 2:
  #   args: "", "ns2:contact"
  #   out: ".//ns2:contact"
  #
  # Пример 3:
  #   args: nil, "contact", nil
  #   out: ".//:contact"
  #
  def paths name, context
    froms = [ context[:from] || name ].flatten.compact
    ctxs = [ context[:reset_context] || context[:context] ].flatten.compact
    prefix = context[:reset_context] && "" || "."

    integrate(ctxs, froms).map do |from|
      from.map do |a|
        a.split('/')
      end.flatten.map do |a|
        /:/ =~ a && a || ":#{a}"
      end.unshift(prefix).join("//")
    end
  end

  def initialize
    @errors = {}
  end
end
