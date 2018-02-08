require 'scheme/parser/version'

require 'nokogiri'

module Scheme::Parser::Base
   class ParameterError < StandardError;end

   attr_reader :errors, :this

   Struct.new('Value', :text)

   def import xml
      model_attrs = parse(xml)
      #name = File.basename(attrs.keys.first, '_attributes')
      #model = name.singularize.camelize.constantize
      #model_attrs = attrs.values.first

      model = self
      key = current_options[:key].to_s || 'id'

      if model_attrs[key]
         if instance = model.where(key => model_attrs[key]).first
            instance.update!(model_attrs)
         else
            instance = model.new(model_attrs)
            instance.save!
         end
#         binding.pry
#         model_attrs.each do |name, value|
#            if value.is_a?(Array)
#               _update_array(name, value)
#            end
#         end

#         binding.pry
      end
#   rescue => e
#      err_text = "Failed to import record #{name} with messages '#{e.message}'"
#      if instance && !(errs = show_errors(instance.errors)).empty?
#         err_text += " and #{errs}"
#      end
#      err_text += " at #{e.backtrace.first}"
#
#      Rails.logger.error(err_text)
#      error "", err_text
   end

   def parse xml
      clean_errors
      filtered = xml.is_a?(String) && xml.gsub(/[\r\u{feff}]/,"") || xml
      doc = filtered.kind_of?(Nokogiri::XML::Element) && filtered || Nokogiri::XML.parse(filtered)
      @this = {}
      attrs = each_field_for(self.schemes[nil], doc)
      #binding.pry
      raise ParameterError if errors.present?
      attrs
   end

#      def _update_array name, array
#        array.each do |value|
#          if value['id']
#            name = File.basename(name, '_attributes')
#            m = name.singularize.camelize.constantize
#            i = m.where(id: value['id']).first
#            binding.pry
#            i.update!(value)
#          end
#        end
#
#        array.delete_if { |value | value['id'] }
#      end
#
   def import_attrs attrs
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
      if defined?(Zip)
         Zip::File.open(file) do |zip_file|
            zip_file.map do |entry|
               tname = File.join(dir, file, entry.name)
               FileUtils.mkdir_p(File.dirname(tname))
               entry.extract(tname)
               tname
            end
         end
      end
   end

   def each_field_for schema, xml_context
      schema.map do |name, options|
         next unless name # skip settings

         v = type_value(name, options, xml_context)

         real_name = options[:multiple] && name.pluralize || name
         is_assign = [Array, Hash].any? { |x| x === v }
         key = is_assign && "#{real_name}_attributes" || real_name

         if handler = handler_for(options[:if])
            v = handler[v]
         end

         @this[name] ||= []
         @this[name] << v

         [ key, v ]
      end.compact.select {|_, v| !v.nil? }.to_h
   end

   def type_value name, options, xml_context
      value = case options[:type]
      when :field
         v = select_value(name, xml_context, options[:contexts], options).first
         v = ! v.respond_to?(:text) && v || v.text
         v = v.respond_to?(:strip) && v.strip || v
         v.present? && v || nil

      when :scheme
         scheme_value(name, options, xml_context)

      when :reference
         reference_value(name, options, xml_context)
      end

      if options[:on_complete]
         value = handled_value(options[:on_complete], value, name, xml_context, options).text
      end

      if options[:required] && value.nil?
         error(name, "field is required")
      end

      ### apply method defined by :map to the value
      if value && options[:map]
         value = value.send(options[:map].to_s)
      end

      value
   end

   def is_update_required(name, xml_context, options, object)
      base = object.send(options[:update_field])
      inx, inc = find_new_contexts(name, xml_context, options)
      o = select_value(options[:update], inx, this_contexts(inc), options).first

      base < Time.parse(o.text)
   end

   def attributes_update name, options, xml_context
      if options[:update] && options[:update_field] &&
            ref = reference_value(name, options, xml_context)
         if is_update_required(name, xml_context, options, ref)
            { "id" => ref.id }
         else
            nil
         end
      elsif ref = reference_value(name, options, xml_context)
#         binding.pry if name =~ /lot/
         if ref.is_a?(Array)
            ref.map { |r| { "id" => r.id } }
         else
            { "id" => ref.id }
         end
      else
         {}
      end
   end

   def scheme_value name, options, xml_context
      if attrs = attributes_update(name, options, xml_context)
#         binding.pry if name.to_s =~ /lot_apps/

         value, i = select_value(name, xml_context, options[:contexts], options)
#         binding.pry if name =~ /lot/
         if value.text.present?
            as = options[:contexts][i][:scheme] || options[:as] || name
#            binding.pry if name.to_s =~ /lot_item/
            scheme_name = self.scheme_name(as)
            vvv = 
            if options[:multiple]

               if attrs.is_a?(Array)
                  values = [ value, attrs ].transpose
                  values.map do |(v, attr)|
#                     binding.pry
                     each_field_for(self.schemes[scheme_name], v).merge(attr)
                  end
               else
                  value.map { |v| each_field_for(self.schemes[scheme_name], v) }
               end
            else
               each_field_for(self.schemes[scheme_name], value).merge(attrs)
            end
#               binding.pry if name =~ /lots?/
               vvv
         end
      end
   end

   def find_new_contexts name, xml_context, options
      new_contexts = self.filter_hashes(options[:contexts],
         Scheme::Parser::Methods::PURE_CONTEXT_KEYS)
      inx, index = select_value(name, xml_context, new_contexts, options)

      if inx.text
         inc = options[:contexts][index]
      end

      [inx, inc]
   end

   def reference_value name, options, xml_context
      inx, inc = find_new_contexts(name, xml_context, options)

      if inc && inc[:by]
         begin
            value, = select_value(inc[:by], inx, this_contexts(inc), options)
         rescue NoMethodError
            error(name, "field error for '#{inc[:by]}' in context: #{inx.inspect}")
         end

         model = model_for(name, options)

         if field = inc[:field] || inc[:by]
#            binding.pry
            if options[:multiple] && value.respond_to?(:size)
               rela = model.where(field => value.map(&:text))
            else
               rela = model.where(field => value.text)
            end
         end

#         binding.pry if name.to_s =~ /placing_method/
         if rela.empty? && field = inc[:re_field]
            begin
               rela = model.where("? ~* #{field}", value.text).order(code: :desc)
            rescue Java::JavaLang::NoSuchMethodError
               error(name, "reference is unavailable to find out via referenced field" +
                  " '#{field}' with data: #{value.text}")
               []
            end
         end

#         binding.pry if name =~ /lot/
         if options[:multiple]
            rela_a = rela.empty? && [nil] || rela
            value =
            rela_a.map do |rela_v|
               if inc[:on_found]
                  handled_value(inc[:on_found], rela_v, name, xml_context, options).text
               else
                  rela_v
               end
            end
         else
            value = rela.first
            if inc[:on_found]
               value = handled_value(inc[:on_found], value, name, xml_context, options).text
            end
         end

         this['relations'] ||= {}
         this['relations'][name] ||= []
         this['relations'][name] << value

#         binding.pry if name =~ /lot/
         value
      end
   end

   def error name, error
#      binding.pry
      @errors ||= {}
      @errors[name] ||= []
      @errors[name] << error

      nil
   end

   def this_contexts in_context = {}
      [ in_context.merge({context: [""], from: nil}) ]
   end

   def model_for name, options
      (options[:as] || name).to_s.singularize.camelize.constantize
   end

   def search_in xml_context, path, options
      # TODO since nokogiri 1.8.2 dones not understand namespaces in attribute names
      # we shold crop it from path, and traverse manually
      res = xml_context.xpath(path)

      options[:multiple] && res || res.first
   rescue Nokogiri::XML::XPath::SyntaxError => e
      err_text = "Failed to navigate path with messages '#{e.message}'"
      error path, err_text
      Rails.logger.error(err_text)
      nil
   end

   # +select_value+ выборка общего обработчика контекста для заданного атрибута.
   # Осуществляет выбор между обработчиками встроенным и заданным пользователем в
   # подробностях (options).
   #
   def select_value name, xml_context, contexts, options
      contexts.map.with_index do |c, i|
         [ c, i ]
      end.reduce([nil, nil]) do |(value, val_index), (context, index)|
         next [value, val_index] if value && value.text.present?

         new =
         if context[:on_proceed]
            midvalue = value(name, xml_context, context, options)
            handled_value(context[:on_proceed], midvalue, name, xml_context, options)
         else
            value(name, xml_context, context, options)
         end

#         binding.pry if name =~ /lot/
         [ new, index ]
      end
   end

   def handler_for handler
      case handler
      when Proc, Method
         handler
      when NilClass
         nil
      else
         self.methods.include?(handler) && self.method(handler)
      end
   end

   def handled_value handler, value, name, xml_context, options
      method = handler_for(handler)

#      new_value =
#      if context[:by]
#         c = [ this_contexts(context).first.merge(handler: nil) ]
#         select_value(context[:by], value, c, options).first
#      else
#         value
#      end
#
      if method
         new_value =
         if value.is_a?(Nokogiri::XML::NodeSet)
            new = Nokogiri::XML::NodeSet.new(value.document)
            new_value = value.map do |subvalue|
               args = [ subvalue, name, xml_context, options ]
               method[*args[0...method.arity]]
#               if subvalue.nil? || subvalue.is_a?(Nokogiri::XML::Searchable)
#                  subvalue
#               else
#                  binding.pry
#                  Struct::Value.new(method[*args[0...method.arity]])
#               end
            end.compact.reduce(new) { |new, x| new << x }
            new_value
         else
            args = [ value, name, xml_context, options ]
            Struct::Value.new(method[*args[0...method.arity]])
         end
      else
         value
      end
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
   #    args: "ns2:documentationDelivery", "deliveryEndDateTime"
   #    out: ".//ns2:documentationDelivery//:deliveryEndDateTime"]
   #
   # Пример 2:
   #    args: "", "ns2:contact"
   #    out: ".//ns2:contact"
   #
   # Пример 3:
   #    args: nil, "contact", nil
   #    out: ".//:contact"
   #
   def paths name, context
      froms = [ context[:from] || name ].flatten.compact
      ctxs = [ context[:reset_context] || context[:context] ].flatten.compact
      prefix = context[:reset_context] && "" || "."

      integrate(ctxs, froms).map do |from|
         from.map do |a|
            a.split('/')
         end.flatten.map do |a|
            /(:|\A..\z)/ =~ a && a || "#{a}"
         end.unshift(prefix).join("//")
      end
   end
end
