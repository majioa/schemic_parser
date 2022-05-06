When('developer generates a scheme from {string} using the YAML generator') do |file_name|
   @scheme = Schemic::Generator::YAML.load_from(File.join("features/fixtures/yaml_generators", file_name))
end

When('he uses the parser to proceed the {string} XML document') do |file_name|
   @parser = Schemic::Parser.new(@scheme)
   @tree = @parser.parse(open(File.join("features/fixtures/xmls", file_name)))
end

Then('there are no errors on parsing') do
   expect(@parser.errors).to be_empty
end

Then('he can get the {string} JSON document') do |file_name|
   # binding.pry
   expect(@tree.as_json).to include_json(JSON.parse(IO.read(File.join("features/fixtures/jsons", file_name))))
end

Then('he can get the {string} YAML document') do |file_name|
   expect(@tree.to_yaml).to be_eql(IO.read(File.join("features/fixtures/yamls", file_name)))
end
