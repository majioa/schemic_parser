module XParser::Methods
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

  def full_context options
    ctxs = [ options[:context] || "" ].flatten
    ctxs.map do |ctx|
      [ current_context, ctx ].flatten.compact.join('/')
    end
  end

  def has_field name, options={}
    data = { type: :field, context: full_context(options) }
    current_scheme[scheme_name(name)] = options.merge(data)
  end

  def has_scheme name, options={}
    data = { type: :scheme, context: full_context(options) }
    current_scheme[scheme_name(name)] = options.merge(data)
  end

  def has_schemes name, options={}
    data = { type: :scheme, multiple: true, context: full_context(options) }
    current_scheme[scheme_name(name)] = options.merge(data)
  end

  def has_reference name, options={}
    data = { type: :reference, context: full_context(options) }
    current_scheme[scheme_name(name)] = options.merge(data)
  end

  # TODO move to protected
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
