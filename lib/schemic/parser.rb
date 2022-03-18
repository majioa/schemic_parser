require "schemic/parser/version"
require "schemic/parser/methods"
require "schemic/parser/base"

module Schemic::Parser
   class << self
      def included kls
         kls.extend Schemic::Parser::Base
         kls.extend Schemic::Parser::Methods
      end
   end
end

