require 'optparse'
require 'ostruct'
require 'rdoba/os'

require 'schemic/parser'

class Schemic::Parser::CLI
   DEFAULT_OPTIONS = {
      rootdir: Dir.pwd,
      scheme: {}.to_os,
   }.to_os

   def option_parser
      @option_parser ||=
         OptionParser.new do |opts|
            opts.banner = "Usage: schemic_parser [options]"

            opts.on("-r", "--rootdir=FOLDER", String, "Root folder to store output to") do |folder|
               options.rootdir = folder
            end

            opts.on("-s", "--scheme-file=FILE", String, "Scheme file to configure parse in YAML") do |file|
               options.scheme_file = file
               options.scheme = YAML.load_file(file).to_os
            end

            opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
               options.verbose = v
            end

            opts.on("-h", "--help", "This help") do |v|
               puts opts
               exit
            end
         end
      if @argv
         @option_parser.default_argv.replace(@argv)
      elsif @option_parser.default_argv.empty?
         @option_parser.default_argv << "-h"
      end

      @option_parser
   end

   def options
      @options ||= DEFAULT_OPTIONS.dup
   end

   def parse!
      return @parse if @parse

      option_parser.parse!
   ensure
      @parse = OpenStruct.new(options: options)
   end

   def parse
      parse!
   end

   def run
      parse
   end

   def initialize argv = nil
      @argv = argv&.split(/\s+/)
   end
end

