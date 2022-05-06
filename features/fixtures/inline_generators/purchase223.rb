# 223-ФЗ Закупка
class Purchase223
   extend Schemic::Parser::Methods

   class << self
      def to_okpd2 value, name, xml_context
         if xml_context.name == 'okdp'
            "$#{value.text}"
         else
            value.text
         end
      end

      def to_okved2 value, name, xml_context
         if xml_context.name == 'okved'
            "$#{value.text}"
         else
            value.text
         end
      end

      def url_process value
         if value
            'http://zakupki.gov.ru/223/purchase/public/purchase/info/' +
            'common-info.html?noticeInfoId=' + value.sub(/.*noticeInfoId=/, '')
         end
      end
   end

   has_scheme :purchase, from: %w(ns2:purchaseNoticeData ns2:purchaseNoticeAEData
      ns2:purchaseNoticeAE94FZData ns2:purchaseNoticeEPData
      ns2:purchaseNoticeZKData ns2:purchaseNoticeOAData
      ns2:purchaseNoticeOKData), postfix: 'attributes'

   scheme :purchase do
      has_field :purchase_standard, required: true,
         on_complete: proc { { "code"=>"223", "description"=>"ФЗ-223" } }
      has_field :number, from: 'ns2:registrationNumber'
      has_field :url, from: 'ns2:urlOOS', on_complete: :url_process
      has_field :description, from: 'ns2:name'
      has_field :published_at, from: 'ns2:publicationDateTime'
      has_field :closed_at, from: 'ns2:submissionCloseDateTime'
      context 'ns2|documentationDelivery' do
         has_field :started_at, from: 'deliveryStartDateTime'
         has_field :ended_at, from: 'deliveryEndDateTime'
      end
      has_scheme :contact, from: 'ns2:contact', as: :person, required: true, postfix: 'attributes'
      has_scheme :placing_method, from: '^', as: :purchase_method, required: true
      has_scheme :etp, from: 'ns2:electronicPlaceInfo'
      has_schemes :lots, context: 'ns2|lots', from: 'lot', required: true, postfix: 'attributes'
   end

   scheme :etp do
      has_field :name
      has_field :url
   end

   scheme :purchase_method do
      has_field :code, from: 'ns2:purchaseMethodCode'
      has_field :name, from: 'ns2:purchaseCodeName'
   end

   scheme :organization do
      has_field :short_name, from: 'shortName'
      has_field :full_name, from: 'fullName', required: true
      has_field :mailing_address, from: 'postalAddress'
      has_field :actual_address, from: 'legalAddress'
      has_field :phone
      has_field :email
      has_field :inn
      has_field :kpp
      has_field :ogrn
      has_field :okato
   end

   scheme :person do
      has_field :first_name, from: 'firstName'
      has_field :middle_name, from: 'middleName'
      has_field :last_name, from: 'lastName'
      has_field :email
      has_field :phone
      has_scheme :organization, from: 'mainInfo', context: 'organization', postfix: 'attributes'
   end

   scheme :lot do
      has_field :initial_price, from: %w(initialSum lotData/initialSum)
      has_scheme :currency, from: 'currency', context: [ 'lotData', '.' ]
      has_field :source_guid, from: 'guid'
      has_field :subject, context: [ 'lotData', '.' ]
      has_scheme :customer, as: :organization, from: 'mainInfo', context: %w(
         @ns2|purchaseNoticeData>ns2|customer @ns2|purchaseNoticeAEData>ns2|customer
         @ns2|purchaseNoticeAE94FZData>ns2|customer @ns2|purchaseNoticeEPData>ns2|customer
         @ns2|purchaseNoticeZKData>ns2|customer @ns2|purchaseNoticeOAData>ns2|customer
         @ns2|purchaseNoticeOKData>ns2|customer), postfix: 'attributes'
      has_schemes :lot_items, from: 'lotItem',
         context: %w(lotData>lotItems lotItems), required: true, postfix: 'attributes'
   end

   scheme :currency do
      has_field :code
      has_field :name
   end

   scheme :lot_item do
      has_field :quantity, from: 'qty'
      has_field :description, from: %w(additionalInfo name), required: true
      has_scheme :okpd, from: %w(okpd2 okdp), required: true
      has_scheme :okei
      has_scheme :okved, from: %w(okved2 okved)
   end

   scheme :okpd do
      has_field :code, on_proceed: :to_okpd2
      has_field :name
   end

   scheme :okei do
      has_field :code, on_complete: proc {|code| code.to_i }
      has_field :symbol, from: :name
   end

   scheme :okved do
      has_field :code, on_proceed: :to_okved2
      has_field :name
   end
end
