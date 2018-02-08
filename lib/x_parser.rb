require "x_parser/version"
require "x_parser/methods"
require "x_parser/base"

module XParser
   class << self
      def included kls
         kls.extend XParser::Base
         kls.extend XParser::Methods
      end
   end
end

