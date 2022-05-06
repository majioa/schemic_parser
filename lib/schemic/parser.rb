require 'nokogiri'

require "schemic/parser/version"
require "schemic/parser/methods"

class Schemic::Parser
   attr_reader :errors

   class ParameterError < StandardError;end
   class InvalidSchemeError < StandardError;end

   def initialize scheme
      raise InvalidSchemeError unless scheme

      @scheme = scheme
   end

   def parse xml
      clean_errors

      filtered = readflow(xml)
      doc = filtered.kind_of?(Nokogiri::XML::Element) && filtered || Nokogiri::XML.parse(filtered)
      #binding.pry
      each_field_for(root_scheme, doc)
   end

   def root_scheme
      @scheme.schemes.select {|_, value| value.root }.to_h.values.first
   end

   def readflow xml
      case xml
      when String
         xml.gsub(/[\r\u{feff}]/,"")
      when File, IO
         xml.rewind
         xml.readlines.join
      else
         xml
      end
   end

   protected

   def clean_errors
      @errors = {}
   end

   def show_errors errors
      errors.messages.map do |field, msgs|
         msgs.map do |msg|
         "#{field} #{msg}"
         end
      end.flatten.join(", ")
   end

   def each_field_for schema, xml_context
      schema.has.map do |name, options|
         n, v = type_value(name, options, xml_context)

         if options.if
            handler = handler_for(options.if)
            args = [v, xml_context][0...handler.arity]

            [n, handler[*args] ? v : nil]
         else
            [n, v]
         end
      end.compact.select do |_, (_n, v)|
         !v.nil?
      end.reduce({}) do |res, _name, (name, value)|
         res.merge({name => value})
      end
   end

   def extract_value v
      v = v.respond_to?(:text) && v.text || v
      v = v.respond_to?(:strip) && v.strip || v
   end

   def type_value name, options, xml_context
      new_name, value =
         case options.kind.to_s
         when "field"
            v, = select_value(name, xml_context, options.selectors, options)
            v = extract_value(v)
            [name.to_s, !v.nil? ? v : nil]
         when "scheme"
            scheme_value(name, options, xml_context)
         when "reference"
            reference_value(name, options, xml_context)
         end

      if options.on_complete
         value = extract_value(handled_value(options.on_complete, value, name, xml_context, options))
      end

      if options.required && value.nil?
         error(name, "field is required")
      end

      [new_name, value]
   end

   def scheme_value name, options, xml_context
      value, selector = select_value(name, xml_context, options.selectors, options)

      new_name, new_value =
         if value&.text&.present?
            scheme_name = (selector.as || options.as || name).to_s.singularize

            n, v =
               if options.single
                  [name, each_field_for(@scheme.schemes[scheme_name], value)]
               else
                  [name.to_s.pluralize, value.map { |v| each_field_for(@scheme.schemes[scheme_name], v) }]
               end

            is_empty?(v) ? [n, nil] : [n, v]
         end

      new_name = [new_name, options.postfix].compact.join("_")

      [new_name, new_value]
   end

   # +is_empty?+ checks wheither the value has empty value, including its subvalues, like for hash and array. Booleans are treated as non-empty values.
   # Examples:
   #     is_empty?("new_names"=>[{"field3"=>""}]) #=> true
   #     is_empty?(false) #=> false
   #     is_empty?(nil) #=> true
   #     is_empty?("") #=> true
   #
   def is_empty? value
      case value
      when Hash
         !value.map {|(_, v)| is_empty?(v) ? nil : v }.compact.any?
      when Array
         !value.map {|v| is_empty?(v) ? nil : v }.compact.any?
      when FalseClass
         false
      when TrueClass
         false
      when NilClass
         true
      else
         value.blank?
      end
   end

   def find_new_selector name, xml_context, options
      inx, selector = select_value(name, xml_context, options.selectors, options)

      if inx&.text
         inc = selector
      end

      [inx, inc]
   end

   def reference_value name, options, xml_context
      error(name, "no reference type is supported")

      []
   end

   def error name, error
      @errors ||= {}
      @errors[name] ||= []
      @errors[name] << error

      nil
   end

   # log method TODO
   def debug text
      $stderr.puts(text) if ENV['DEBUG']
   end

   # +select_value+ выборка общего обработчика контекста для заданного атрибута.
   # Осуществляет выбор между обработчиками встроенным и заданным пользователем в
   # подробностях (options).
   #
   def select_value name, dom_context_in, selectors, options
      selectors.reduce([nil, nil]) do |(value, val_selector), path, selector|
         if value.respond_to?(:text) && value.text.present? ||
               !selector.if.nil? && !handler_for(selector.if)[value, dom_context_in]
            next [value, val_selector]
         end

         dom_context = level_to_dom_context(selector.level, dom_context_in)
         value_tmp = search_in(path, dom_context, name, options)
         value_new = handled_value(selector.on_proceed, value_tmp, name, dom_context, options) if selector.on_proceed

         [is_empty?(value_new) ? value_tmp : value_new, selector]
      end
   end

   # +level_to_dom_context+ returns a new DOM context depending on the level from the current passed as a +dom_context_in+
   # argument. When +level+ is a positive integer, it returns a parent context with steps defined by a level,
   # when +level+ is a zero, it returns self context, when +level+ is a -1, it returns a root context.
   # Examples:
   #     level_to_dom_context(-1, dom_context_in) # root DOM context
   #     level_to_dom_context(0, dom_context_in) # self DOM context
   #     level_to_dom_context(1, dom_context_in) # parent DOM context
   #
   def level_to_dom_context level, dom_context_in
      case level
      when -1
         # dom_context_in.xpath('/*').first
         dom_context_in.document
      when 0
         dom_context_in
      else
         (0...level.to_i).reduce(dom_context_in) {|res, _| res.parent rescue res }
      end
   end

   def handler_for handler
      case handler
      when Proc, Method
         handler
      when NilClass
         self.method(:unhdefined_handler)
      when TrueClass
         self.method(:true_handler)
      when FalseClass
         self.method(:false_handler)
      else
         self.methods.include?(handler) && self.method(handler) || self.method(:undefined_handler)
      end
   end

   def true_handler *args
      debug("True handler is used for '#{args[1]}' field with value '#{args.first}'")

      true
   end

   def false_handler value, *args
      debug("False handler is used for '#{args[1]}' field with value '#{args.first}'")

      false
   end

   def undefined_handler value, *args
      warn("Undefined handler is used for '#{args.first}' field with value '#{value}'")

      value
   end

   def handled_value handler, value, name, xml_context, options
      method = handler_for(handler)

      if value.is_a?(Nokogiri::XML::NodeSet)
         new = Nokogiri::XML::NodeSet.new(value.document)

         value.map do |subvalue|
            args = [ subvalue, name, xml_context, options ]
            method[*args[0...method.arity]]
         end.compact.reduce(new) { |new, x| new << x }
      else
         args = [ value, name, xml_context, options ]
         value_tmp = method[*args[0...method.arity]]
      end
   end

   def search_in path, xml_context, name, options
      res =
         if path.blank?
            xml_context
         else
            xml_context.css(path.to_s)
         end

      options.single && res.first || res
   rescue Nokogiri::CSS::SyntaxError => e
      error(name, "Failed to navigate path with messages '#{e.message}'")
      nil
   end
end
