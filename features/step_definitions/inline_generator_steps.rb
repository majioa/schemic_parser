Given('inline generator defined as {string}') do |generator_class|
   @generator_class = generator_class
end

When('developer generates a scheme with the inline generator') do
   @scheme = @generator_class.constantize.generate
end
