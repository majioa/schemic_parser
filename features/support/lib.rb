module Lib
   def cli
      @cli ||= Schemic::Parser::CLI.new
      @cli.option_parser.default_argv << "-v" # NOTE to avoid errors
      @cli
   end

   def adopt_value value
      case value
      when ""
         nil
      when /(\[|\{|---)/
         YAML.load(value)
      when /^:/
         value[1..-1].to_sym
      when /:/
         value.split(",").map {|v| v.split(":") }.to_os
      when /.yaml$/
         YAML.load(IO.read(value))
      else
         value
      end
   end
end

World(Lib)
