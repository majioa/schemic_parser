# 223-ФЗ Заявка
class Protocol223
   extend Schemic::Parser::Methods
   extend InnValidate

   scheme :protocol, root: true do
      has_scheme :purchase, from: %w(ns2:purchaseProtocolData
         ns2:purchaseProtocolPAAEData ns2:purchaseProtocolPAEPData
         ns2:purchaseProtocolPAOAData ns2:purchaseProtocolOSZData
         ns2:purchaseProtocolZKData), postfix: 'attributes'
   end

   scheme :purchase do
      has_field :number, from: 'ns2|purchaseInfo/purchaseNoticeNumber', required: true
      has_field :booked_at, from: 'ns2|publicationDateTime', required: true
      has_schemes :lots, from: [ 'ns2:lot', '' ],
         context: 'ns2|lotApplicationsList>ns2|protocolLotApplications', required: true, postfix: 'attributes'
   end

   scheme :lot do
      has_field :source_guid, from: 'ns2|guid', required: true
      has_schemes :lot_apps, from: %w(ns2|application ^ns2|application), required: true, postfix: 'attributes'
   end

   scheme :supplier do
      has_scheme :organization, from: '', if: :validate_inn, postfix: 'attributes'
      has_field :type, on_complete: proc { |value| value == 'P' && 'Individual' || 'Entity' }
   end

   scheme :organization do
      has_field :short_name, from: 'name'
      has_field :inn, required: true
      has_field :kpp
      has_field :ogrn
      has_field :mailing_address, from: 'address'
   end

   scheme :lot_app do
      has_scheme :supplier, from: %w(ns2|supplierInfo ns2|participantInfo), required: true, postfix: 'attributes'
      has_field :last_price, from: %w(ns2|lastPrice ns2|price)
      has_field :rate, [
         { from: 'ns2|winnerIndication', on_proceed: proc { |value| ! (value.text !~ /W/) } },
         { from: 'ns2|applicationPlace', on_proceed: proc { |value| ! (value.text !~ /F/) } },
         { from: 'ns2|applicationRate', on_proceed: proc { |value| ! (value.text !~ /1/) } }
      ], required: true
   end
end
