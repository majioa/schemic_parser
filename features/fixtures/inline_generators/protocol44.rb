# 44-ФЗ Протокол/Заявка
class Protocol44
   extend Schemic::Parser::Methods
   include InnValidate

   has_scheme :purchase, from: %w(ns2|fcsProtocolEF3 ns2|fcsProtocolEFSingleApp
      ns2|fcsProtocolOK2 ns2|fcsProtocolOKSingleApp ns2|fcsProtocolOKOU3
      ns2|fcsProtocolOKOUSingleApp ns2|fcsProtocolOKD5 ns2|fcsProtocolOKDSingleApp
      ns2|fcsProtocolZK ns2|fcsProtocolZKAfterProlong ns2|fcsProtocolZKBI
      ns2|fcsProtocolZKBIAfterProlong ns2|fcsProtocolPO ns2|fcsProtocolZPFinal), postfix: 'attributes'

   scheme :purchase do
      has_field :number, from: 'purchaseNumber', required: true
      has_field :booked_at, from: 'publishDate', required: true
      has_schemes :lots, from: %w(protocolLots>protocolLot protocolLot), postfix: 'attributes'
   end

   scheme :lot do
      has_field :number, from: 'lotNumber'
      has_schemes :lot_apps, context: ['applications', ''], from: 'application', postfix: 'attributes'
   end

   scheme :supplier do
      has_scheme :organization, from: '', field: 'inn', required: true, postfix: 'attributes'
      has_scheme :contact, from: 'contactInfo', as: :person, postfix: 'attributes'
      has_field :ext_info, from: 'additionalInfo'
      has_field :status
      has_field :type, from: 'participantType', required: true, 
         on_complete: proc { |value| value =~ /^P/ && 'Individual' || 'Entity' }
   end

   scheme :organization do
      has_field :short_name, from: 'organizationName'
      has_field :inn, from: %w(inn idNumber), required: true
      has_field :kpp
      has_field :inn_ext, from: 'idNumberExtension'
      has_field :mailing_address, from: 'postAddress'
      has_field :actual_address, from: 'factualAddress'
      has_field :phone, from: 'contactPhone'
   end

   scheme :person do
      has_field :last_name, from: 'lastName'
      has_field :first_name, from: 'firstName'
      has_field :middle_name, from: 'middleName'
   end

   scheme :lot_app do
      has_scheme :supplier, from: 'appParticipant', required: true, postfix: 'attributes'
      has_field :rate, [
         { from: 'resultType', context: 'admittedInfo',
            on_complete: proc { |value| !(value !~ /WIN_OFFER/) } },
         { from: 'appRating',
            on_complete: proc { |value| !(value != '1') } }
      ], required: true
   end
end
