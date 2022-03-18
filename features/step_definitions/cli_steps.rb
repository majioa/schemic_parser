Given('options for Setup CLI:') do |text|
   subs = []
   args =
      text.gsub(/"[^"]*"/) do |m|
         i = subs.size
         /"([^"]*)"/ =~ m
         subs << $1
         "\x1#{i.chr}"
      end.split(/\s+/).map do |token|
         token.gsub(/\x1./) do |chr|
            /\x1(.)/ =~ chr
            subs[$1.ord]
         end
      end

   cli.option_parser.default_argv = args
end

Given('blank setup CLI') do
   @cli = nil
   cli.option_parser.default_argv = []
end

Given('the default option for {string} is {string}') do |name, value|
   cli.options[name] = value
end

When('developer loads schemic_parser') do
   cli.run
end

Then('property {string} of options is {string}') do |property, value|
   expect(cli.options.send(property)).to eql(value)
end

Then('CLI option {string} is {string}') do |option, value|
   expect(cli.options[option]).to eql(value)
end

Then('CLI option {string} is:') do |option, text|
   expect(cli.options[option]).to eql(YAML.load(text))
end

Then('property {string} of options is:') do |property, text|
   expect(cli.options.send(property)).to eql(YAML.load(text))
end

Then('CLI option {string} is of an {string} type') do |property, type|
   expect(cli.options.send(property)).to be_kind_of(type.constantize)
end
