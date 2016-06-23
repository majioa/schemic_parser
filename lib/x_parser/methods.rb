module XParser::Methods
  CONTEXT_KEYS = [ :by, :from, :context, :field, :reset_context, :handler ]
  FIELD_KEYS = [ :required, :as, :if ]

  def scheme name, &block
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

  def has_field name, *args
    current_scheme[scheme_name(name)] = make_options(:field, args)
  end

  def has_scheme name, *args
    current_scheme[scheme_name(name)] = make_options(:scheme, args)
  end

  def has_schemes name, *args
    current_scheme[scheme_name(name)] = make_options(:scheme, args, true)
  end

  def has_reference name, *args
    current_scheme[scheme_name(name)] = make_options(:reference, args)
  end

#   has_reference :lot, [
#   { by: 'guid', from: 'ns2:lot', reset_context: 'ns2:protocolLotApplications' },
#   { by: 'ns2:guid', from: 'ns2:protocolLotApplications', reset_context: 'ns2:lotApplicationsList' },
#   ], required: true
#
#   has_field :rate, { required: true },
#   { from: [ 'ns2:winnerIndication' ], handler: proc { |value| ! (value !~ /W/) } },
#   { from: [ 'ns2:applicationPlace' ], handler: proc { |value| ! (value !~ /F/) } },
#   { from: [ 'ns2:applicationRate' ], handler: proc { |value| ! (value !~ /1/) } }

  # TODO move to protected
  #
  def make_options(type, args, multiple = false)
    contexts = full_context(filter_hashes(args, CONTEXT_KEYS))
    local = filter_hashes(args, FIELD_KEYS).reduce({}) { |r, x| r.merge(x) }
    { type: type, multiple: multiple, contexts: contexts }.merge(local)
  end

  def filter_hashes hashes, by
    hashes.flatten.map do |hash|
      (hash.keys & by).map { |x| [ x, hash[x] ] }.to_h
    end.select do |hash|
      hash.any?
    end
  end

  def full_context contexts
    contexts.map do |options|
      ctxs = [ options[:context] || "" ].flatten
      options[:context] = ctxs.map do |ctx|
        [ current_context, ctx ].flatten.compact.join('/')
      end

      options
    end
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

  def current_scheme
    schemes[current_scheme_path.last] ||= {}
  end
end
