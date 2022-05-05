class Array
   # [1,2].map { |x| [3,4].map { |y| [x, y] } }.flatten(1)
   #=> [[1, 3], [1, 4], [2, 3], [2, 4]]
   def integrate ary2
      self.map { |x| ary2.map { |y| [x, y] } }.flatten(1)
   end
end

# TODO inline generator
module Schemic::Parser::Methods
   CONTEXT_KEYS = %i(by re from context field on_proceed scheme on_found)
   FIELD_KEYS = %i(required as if update update_field on_complete map postfix)
   PURE_CONTEXT_KEYS = %i(from context)

   def scheme name, options = {}, &block
      current_scheme_path << name.to_s
      yield
      current_scheme_path.pop
   end

   def context name, &block
      current_context << name.to_s
      yield
      current_context.pop
   end

   def scheme_name name
      name.to_s.singularize
   end

   def use_default_key name
      current_scheme[:key] = name
   end

   def has_field name_in, *args
      has_param(name_in.to_s, :field, true, args)
   end

   def has_scheme name, *args
      has_param(scheme_name(name), :scheme, true, args)
   end

   def has_schemes name, *args
      has_param(scheme_name(name), :scheme, false, args)
   end

   def has_reference name, *args
      has_param(name.to_s, :reference, true, args)
   end

   def has_param name, param_name, single, *args
      current_scheme[:has][name] = make_options(param_name, args, name, single)
   end

#    has_reference :lot, [
#    { by: 'guid', from: 'ns2:lot', reset_context: 'ns2:protocolLotApplications' },
#    { by: 'ns2:guid', from: 'ns2:protocolLotApplications', reset_context: 'ns2:lotApplicationsList' },
#    ], required: true
#
   # TODO move to protected
   #
   def make_options kind, args, name, single = true
      selectors = make_selectors(filter_hashes(args, CONTEXT_KEYS), name, args)
      local = transform_field_keys(args)

      { kind: kind, single: single, selectors: selectors }.to_os.merge(local)
   end

   # +transform_field_keys+ filters out and then transforms the passed in arguments to then merge them in to the scheme
   #
   def transform_field_keys hash_in
      filter_hashes(hash_in, FIELD_KEYS).reduce({}.to_os) do |r, x|
         new =
            x.map do |key, value|
               new_value =
                  if key =~ /if|on_complete/
                     value.is_a?(Symbol) && (method(value) rescue value) || value
                  else
                     value
                  end

               [key, new_value]
            end.to_h.to_os

         r.merge(new)
      end
   end

   # +transform_selector_keys+ filters out and then transforms the passed in arguments to then merge them in to the scheme
   #
   def transform_selector_keys hash_in
      filter_hashes(hash_in, CONTEXT_KEYS|[:level]).reduce({}.to_os) do |r, x|
         new =
            x.map do |key, value|
               new_value =
                  if key =~ /on_proceed|on_found/
                     value.is_a?(Symbol) && (method(value) rescue value) || value
                  else
                     value
                  end

               [key, new_value]
            end.to_h.to_os

         r.merge(new)
      end
   end

   def make_selectors contexts, name, args
      (contexts.empty? && [{}] || contexts).reduce({}.to_os) do |selectors, options|
         ctxs = [ options[:context] || "" ].flatten

         context = ctxs.map do |ctx|
            [current_context, ctx].flatten.compact.join('/')
         end

         current_scheme

         selectors.merge(make_selector(name, options))
      end
   end

   def current_context
      @current_context ||= []
   end

   def current_scheme_path
      @current_scheme_path ||= [self.to_s.downcase]
   end

   def schemes
      @schemes ||= {}.to_os
   end

   def current_scheme
      schemes[current_scheme_path.last] ||= { has: {}, root: schemes.to_h.keys.size == 0 }.to_os
   end

   def generate
      { schemes: @schemes }.to_os
   end

   # +paths_context+ объединяет переданные строки контекста в единую строку в
   # формате xpath.
   #
   # +forms_in+ array of some parent nodes to search the +name+ node in.
   #
   # special chars for from and context options' fields are:
   #    @ - root context
   #    ^ - parent context
   #    . or <blank> - current context
   #
   # Example 1:
   #    args:
   #       from: ["deliveryEndDateTime"]
   #       context: "ns2:documentationDelivery"
   #    out:
   #       paths: ["ns2|documentationDelivery > deliveryEndDateTime"]
   #       dom_context: # current
   #
   # Example 2:
   #    args:
   #       from: ["ns2:documentationDelivery>lots", ""]
   #       context: "@lot"
   #    out:
   #       paths: ["lot>ns2|documentationDelivery>lots", "lot>ns2|documentationDelivery"]
   #       dom_context: # root
   #
   # Example 3:
   #    args:
   #       from: ["ns2:documentationDelivery", "^"]
   #       context: "^^"
   #    out:
   #       paths: ["documentationDelivery", ""]
   #       dom_context: # parent * 3
   #
   def make_selector name, options
      froms = [options.delete(:from) || [name].compact].flatten

      #ctxs = [reset_context || context].flatten.compact
      #prefix = reset_context && ">" || ""

      paths_in =
         if options[:context]
            context = [options.delete(:context)].flatten
            context.integrate(froms).map { |from| from.join(">") }
         else
            froms
         end.map(&:to_s)

      cpaths =
         paths_in.map do |path|
#            no_parent_tokens = path.split(/\^/)
#            level = no_parent_tokens.size - 1
#            if level > 0
#               context_parent, path_parent =
#                  no_parent_tokens.reduce([current_scheme_path, nil]) do |(context_in, path_in), token|
#      binding.pry
#                     path = [token, current_scheme_path, path_in].reject {|x| x.blank? }.join(">")
#                     [context_in.parent, path]
#                  end
#            else
#               path_parent = no_parent_tokens.join("")
 #           end

            no_parent = path.gsub(/\^/, '')
            level = path.size - no_parent.size

            no_root = no_parent.gsub(/@/, '')
            #root = no_root.size - path_parent.size
            level_root = no_root.size < no_parent.size && -1 || level
            new_path = no_root.sub(/:/, '|').gsub(/\//, '>')
#            new_path = name if new_path.blank?
            new_path = new_path.gsub(/\./, name)
#           binding.pry if path =~ /[@]/

            # binding.pry if name =~ /number/
            [ new_path, transform_selector_keys({ level: level_root }.merge(options)) ]
         end.to_h.to_os

      cpaths
   end

   def filter_hashes hashes, by
      [hashes].flatten.map do |hash|
         (hash.keys & by).map { |x| [ x, hash[x] ] }.to_h
      end.select do |hash|
         hash.any?
      end
   end
end
