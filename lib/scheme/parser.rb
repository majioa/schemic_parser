require "scheme/parser/version"
require "scheme/parser/methods"
require "scheme/parser/base"

module Scheme::Parser
   class << self
      def included kls
         kls.extend Scheme::Parser::Base
         kls.extend Scheme::Parser::Methods
      end
   end
end

