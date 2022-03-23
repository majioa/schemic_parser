require 'schemic/adapter'

module Schemic::Adapter::Rails
   def import xml
      model_attrs = parse(xml)
      model = self
      key = current_options[:key].to_s || 'id'

      if model_attrs[key]
         if instance = model.where(key => model_attrs[key]).first
            instance.update!(model_attrs)
         else
            instance = model.new(model_attrs)
            instance.save!
         end
      end
   end

   def reference_value name, options, xml_context
      inx, selector = find_new_selector(name, xml_context, options)

      if selector[:by]
         begin
            value, = select_value(selector[:by], inx, this_contexts(selector), options)
         rescue NoMethodError
            error(name, "field error for '#{selector[:by]}' in context: #{inx.inspect}")
         end

         model = model_for(name, options)

         if field = selector[:field] || selector[:by]
#            binding.pry
            if !options.single && value.respond_to?(:size)
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
         if options.single
            value = rela.first
            if inc[:on_found]
               value = handled_value(inc[:on_found], value, name, xml_context, options).text
            end
         else
            rela_a = rela.empty? && [nil] || rela
            value =
            rela_a.map do |rela_v|
               if inc[:on_found]
                  handled_value(inc[:on_found], rela_v, name, xml_context, options).text
               else
                  rela_v
               end
            end
         end

         this['relations'] ||= {}
         this['relations'][name] ||= []
         this['relations'][name] << value

#         binding.pry if name =~ /lot/
         value
      end
   end

   def attributes_update name, options, xml_context
      if options.update && options.update_field &&
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

   def is_update_required(name, xml_context, options, object)
      base = object.send(options.update_field)
      inx, inc = find_new_contexts(name, xml_context, options)
      o, = select_value(options.update, inx, this_contexts(inc), options)

      base < Time.parse(o.text)
   end

end
