Feature: CLI

   Scenario: CLI rootdir validation
      Given blank setup CLI
      And options for Setup CLI:
         """
         --rootdir=/var/tmp
         """
      When developer loads schemic_parser
      Then CLI option "rootdir" is "/var/tmp"

   Scenario: CLI scheme file argument validation
      Given blank setup CLI
      And options for Setup CLI:
         """
         --scheme-file=features/fixtures/default_scheme.yaml
         """
      When developer loads schemic_parser
      Then CLI option "scheme_file" is "features/fixtures/default_scheme.yaml"
      And CLI option "scheme" is of an "OpenStruct" type
