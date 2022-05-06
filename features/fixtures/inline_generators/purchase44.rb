# 44-ФЗ Закупка
class Purchase44
   extend Schemic::Parser::Methods

   class << self
      def to_okpd2 value, name, xml_context
         if xml_context.name == 'OKPD'
            "##{value.text}"
   #         value = value.text
   #         record = Okpd1ToOkpd2.where(okpd1: value).first
   #         if record.respond_to?(:okpd)
   #            record.okpd.code
   #         else
   #            error(name, "Не найден код ОКДП #{value} в таблице преобразования")
   #         end
         else
            value.text
         end
      end
   
      def to_okved2 value, name
   #      binding.pry
         if xml_context.name == 'OKVED'
            "$#{value.text}"
         else
            value.text
         end
   #      value = value.text
   #      record = Okved1ToOkved2.where(okved1: value).first
   #      if record.respond_to?(:okved)
   #         record.okved.code
   #      else
   #         error(name, "Не найден код ОКВЕД1 #{value} в таблице преобразования")
   #      end
      end
   end

   has_scheme :purchase, from: %w(
      ns2:fcsNotificationEF ns2:fcsNotificationZK ns2:fcsNotificationOK
      ns2:fcsNotificationEP ns2:fcsNotificationOKOU ns2:fcsNotificationOKD
      ns2:fcsNotificationZakA ns2:fcsNotificationZakKD ns2:fcsNotificationZakK
      ns2:fcsNotificationPO ns2:fcsNotificationZP ns2:fcsNotificationOK
   ), required: true, postfix: 'attributes'

   scheme :purchase do
      has_field :purchase_standard, required: true,
         on_complete: proc { { "code"=>"44", "description"=>"ФЗ-44" } }
      has_field :url, from: 'href'
      has_field :number, from: 'purchaseNumber', required: true
      has_field :description, from: 'purchaseObjectInfo'
      has_field :published_at, from: 'docPublishDate'
      context 'procedureInfo>collecting' do
         has_field :started_at, from: 'startDate'
         has_field :ended_at, from: 'endDate'
         has_field :closed_at, from: 'endDate'
      end
      has_scheme :responsible, from: 'responsibleOrg', context: 'purchaseResponsible', as: :organization, required: true, postfix: 'attributes'
      has_scheme :contact, from: 'responsibleInfo', context: 'purchaseResponsible', as: :person, required: true, postfix: 'attributes'
      has_scheme :placing_method, from: 'placingWay', as: :placing_way, required: true
      has_scheme :etp, from: 'ETP'
      has_schemes :lots, from: %w(
         lot/customerRequirements/customerRequirement
         lots/lot/customerRequirements/customerRequirement
      ), required: true, postfix: 'attributes'
   end

   scheme :etp do
      has_field :name
      has_field :url
   end

   scheme :placing_way do
      has_field :code
      has_field :name
   end

   scheme :organization do
      has_field :full_name, from: 'fullName', required: true
      has_field :mailing_address, from: 'postAddress'
      has_field :actual_address, from: 'factAddress'
      has_field :reg_no, from: 'regNum', required: true
      has_field :inn, from: 'INN'
      has_field :kpp, from: 'KPP'
   end

   scheme :person do
      context 'contactPerson' do
         has_field :last_name, from: 'lastName'
         has_field :first_name, from: 'firstName'
         has_field :middle_name, from: 'middleName'
      end
      has_field :email, from: 'contactEMail'
      has_field :phone, from: 'contactPhone'
   end

   scheme :lot do
      has_field :number, from: 'lotNumber'
      has_field :initial_price, from: 'maxPrice'
      has_scheme :currency, from: 'currency', context: %w(@lot @lots>lot), required: true
      has_field :finance_source, context: %w(@lot @lots>lot), from: 'financeSource'
      has_scheme :customer, as: :organization, from: 'customer', postfix: 'attributes'
      has_schemes :lot_items, [
         { from: 'purchaseObject', context: %w(
               @lot>purchaseObjects @lots>lot>purchaseObjects
            ) }
      ], required: true, postfix: 'attributes'
#    has_reference :lot, [
#    { by: 'guid', from: 'ns2:lot', reset_context: 'ns2:protocolLotApplications' },
#    { by: 'ns2:guid', from: 'ns2:protocolLotApplications', reset_context: 'ns2:lotApplicationsList' },
#    ], required: true
   end

   scheme :currency do
      has_field :code
      has_field :name
   end

   scheme :lot_item do
      has_field :quantity, from: %w(quantity>value quantity)
      has_field :price
      has_field :description, from: 'name', required: true
      has_scheme :okpd, from: %w(OKPD2 OKPD), required: true
      has_scheme :okei, from: 'OKEI'
      has_scheme :okved, from: %w(OKVED2 OKVED)
   end

   scheme :okpd do
      has_field :code, on_proceed: :to_okpd2
      has_field :name
   end

   scheme :okei do
      has_field :code, on_proceed: proc {|value| value.text.to_i }
      has_field :symbol, from: :nationalCode
   end

   scheme :okved do
      has_field :code, on_proceed: :to_okved2
      has_field :name
   end
end
