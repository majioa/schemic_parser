class Array
   # [1,2].map { |x| [3,4].map { |y| [x, y] } }.flatten(1)
   #=> [[1, 3], [1, 4], [2, 3], [2, 4]]
   def integrate ary2
      self.map { |x| ary2.map { |y| [x, y] } }.flatten(1)
   end
end

module Schemic::Parser::Methods
   CONTEXT_KEYS = [ :by, :re, :from, :context, :field, :reset_context, :on_proceed, :scheme, :on_found ]
   FIELD_KEYS = [ :required, :as, :if, :update, :update_field, :on_complete, :map ]
   PURE_CONTEXT_KEYS = [ :from, :context, :reset_context ]

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
      current_options[:key] = name
   end

   def has_field name_in, *args
      has_param(scheme_name(name), :field, false, args)
   end

   def has_scheme name, *args
      has_param(scheme_name(name), :scheme, false, args)
   end

   def has_schemes name, *args
      has_param(scheme_name(name), :scheme, true, args)
   end

   def has_reference name, *args
      has_param(scheme_name(name), :reference, false, args)
   end

   def has_param name, param_name, multiple, *args
      current_scheme[name] = make_options(param_name, args, name, multiple)
#      binding.pry
      current_scheme[name]
   end

#    has_reference :lot, [
#    { by: 'guid', from: 'ns2:lot', reset_context: 'ns2:protocolLotApplications' },
#    { by: 'ns2:guid', from: 'ns2:protocolLotApplications', reset_context: 'ns2:lotApplicationsList' },
#    ], required: true
#
#    has_field :rate, { required: true },
#    { from: [ 'ns2:winnerIndication' ], handler: proc { |value| ! (value !~ /W/) } },
#    { from: [ 'ns2:applicationPlace' ], handler: proc { |value| ! (value !~ /F/) } },
#    { from: [ 'ns2:applicationRate' ], handler: proc { |value| ! (value !~ /1/) } }

   # TODO move to protected
   #
   def make_options type, args, name, multiple = false
      selectors = make_selectors(filter_hashes(args, CONTEXT_KEYS), name, args)
      local = filter_hashes(args, FIELD_KEYS).reduce({}.to_os) { |r, x| r.merge(x.to_os) }

      { type: type, multiple: multiple, selectors: selectors }.to_os.merge(local)
   end

   def make_selectors contexts, name, args
      (contexts.empty? && [{}] || contexts).map do |options|
         ctxs = [ options[:context] || "" ].flatten

         context = ctxs.map do |ctx|
            [current_context, ctx].flatten.compact.join('/')
         end

         current_scheme

         #binding.pry

         make_selector(name, options)
      end.flatten
   end

   def current_context
      @current_context ||= []
   end

   def current_scheme_path
      @current_scheme_path ||= []
   end

   def schemes
      @schemes ||= {}
   end
   def current_options
      current_scheme[nil] ||= {}
   end

   def current_scheme
      schemes[current_scheme_path.last] ||= {}
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
      froms = [options[:from] || [name].compact].flatten

      #ctxs = [reset_context || context].flatten.compact
      #prefix = reset_context && ">" || ""

      paths_in =
         if options[:context]
      #binding.pry
            context = [options[:context]].flatten
            context.integrate(froms).map { |from| from.join(">") }
         else
            froms
         end

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
            level_root = no_root.size > no_parent.size && -1 || level
      #binding.pry

            { path: no_root.sub(/:/, '|').gsub(/\//, '>'), parent_level: level_root }.to_os
         end

#      binding.pry if cpaths.map {|x| x.path }

        # { path: path, context: context }.to_os
      cpaths
   end

   def filter_hashes hashes, by
      hashes.flatten.map do |hash|
         (hash.keys & by).map { |x| [ x, hash[x] ] }.to_h
      end.select do |hash|
         hash.any?
      end
   end
end
