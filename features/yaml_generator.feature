Feature: YAML Generator

   Scenario: Inline Generator validation
      When developer generates a scheme from "sample.yaml" using the YAML generator
      And he uses the parser to proceed the "sample.xml" XML document
      Then there are no errors on parsing
      And he can get the "sample.json" JSON document
      And he can get the "sample.yaml" YAML document
