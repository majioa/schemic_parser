require 'nokogiri'

require "schemic/parser/version"
require "schemic/parser/methods"

class Schemic::Parser
   attr_reader :errors

   class ParameterError < StandardError;end

   def initialize scheme
      @scheme = scheme
   end

   def parse xml
      clean_errors

      filtered = readflow(xml)
      doc = filtered.kind_of?(Nokogiri::XML::Element) && filtered || Nokogiri::XML.parse(filtered)

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
         v = type_value(name, options, xml_context)
         handler = handler_for(options.if) if options.if

         handler && handler[v, xml_context] || v
      end.compact.select {|_, v| !v.nil? }.to_h
   end

   def extract_value v
      v = v.respond_to?(:text) && v.text || v
      v = v.respond_to?(:strip) && v.strip || v
   end

   def type_value name, options, xml_context
      value =
         case options.kind.to_s
         when "field"
            v, = select_value(name, xml_context, options.selectors, options)
            v = extract_value(v)
            v.present? && v || nil
         when "scheme"
            scheme_value(name, options, xml_context)
         #when "reference"
         #   reference_value(name, options, xml_context)
         end

      if options.on_complete
         value = extract_value(handled_value(options.on_complete, value, name, xml_context, options))
      end

      if options.required && value.nil?
         binding.pry
         error(name, "field is required")
      end

      value
   end

   def scheme_value name, options, xml_context
      value, selector = select_value(name, xml_context, options.selectors, options)

      if value&.text&.present?
         scheme_name = (selector.as || options.as || name).to_s.singularize

         if options.single
            each_field_for(@scheme.schemes[scheme_name], value)
         else
            value.map { |v| each_field_for(@scheme.schemes[scheme_name], v) }
         end
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
   end

   def error name, error
      @errors ||= {}
      @errors[name] ||= []
      @errors[name] << error

      nil
   end

   def this_contexts in_context = {}
      [ in_context.merge({context: [""], from: nil}) ]
   end

   def model_for name, options
      (options.as || name).to_s.singularize.camelize.constantize
   end

   # +select_value+ выборка общего обработчика контекста для заданного атрибута.
   # Осуществляет выбор между обработчиками встроенным и заданным пользователем в
   # подробностях (options).
   #
   def select_value name, dom_context, selectors, options
      selectors.reduce([nil, nil]) do |(value, val_selector), path, selector|
         if value && value.text.present? ||
               selector.if && !handler_for(selector.if)[value, dom_context]
            next [value, val_selector]
         end

         value_tmp = search_in(path, dom_context, name, options)
         value_new = handled_value(selector.on_proceed, value_tmp, name, dom_context, options) if selector.on_proceed

         [value_new || value_tmp, selector]
      end
   end

   def handler_for handler
      case handler
      when Proc, Method
         handler
      when NilClass
         self.method(:blank_handler)
      else
         self.methods.include?(handler) && self.method(handler) || self.method(:blank_handler)
      end
   end

   def blank_handler *args
      binding.pry
      warn("Blank handler is used with args: #{args.inspect}")
   end

   def handled_value handler, value, name, xml_context, options
      method = handler_for(handler)

      if method
         new_value =
         if value.is_a?(Nokogiri::XML::NodeSet)
            new = Nokogiri::XML::NodeSet.new(value.document)

            new_value = value.map do |subvalue|
               args = [ subvalue, name, xml_context, options ]
               method[*args[0...method.arity]]
            end.compact.reduce(new) { |new, x| new << x }
            new_value
         else
            args = [ value, name, xml_context, options ]
            value_tmp = method[*args[0...method.arity]]
         end
      else
         value
      end
   end

   def search_in path, xml_context, name, options
      res = xml_context.css(path)

      options.single && res.first || res
   rescue Nokogiri::CSS::SyntaxError => e
      binding.pry
      error name, "Failed to navigate path with messages '#{e.message}'"
      nil
   end
end
