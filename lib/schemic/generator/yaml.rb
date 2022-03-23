require 'yaml'
require 'rdoba/os'

require 'schemic/generator'

module Schemic::Generator::YAML
   class << self
      def load_from file_name
         ::YAML.load_file(file_name).to_os
      end
   end
end
