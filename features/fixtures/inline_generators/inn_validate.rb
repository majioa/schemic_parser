# source: http://инн.рф/chk_inn.html
module InnValidate
   CKEYS = [2, 4, 10, 3, 5, 9, 4, 6, 8]
   CKEYS1 = [3, 7, 2, 4, 10, 3, 5, 9, 4, 6, 8]
   CKEYS2 = [7, 2, 4, 10, 3, 5, 9, 4, 6, 8]

   def validate_inn value
      def validate_inn10 value
         digits = value[0...9].unpack("U*").map { |ord| ord - 0x30 }

         sum = CKEYS.zip(digits).map { |(i, j)| i * j }.reduce(:+)
         rem = (sum % 11).to_s[-1].to_i

         rem == value[-1].to_i && value != '0' * 10
      end

      def validate_inn12 value
         digits = value[0...11].unpack("U*").map { |ord| ord - 0x30 }

         sum1 = CKEYS1.zip(digits).map { |(i, j)| i * j }.reduce(:+)
         sum2 = CKEYS2.zip(digits[0..-2]).map { |(i, j)| i * j }.reduce(:+)
         rem1 = (sum1 % 11).to_s[-1].to_i
         rem2 = (sum1 % 11).to_s[-1].to_i

         rem1 == value[-1].to_i && rem2 == value[-2].to_i && value != '0' * 12
      end

      case value['inn'].size
      when 10
         validate_inn10(value['inn'])
      when 12
         validate_inn12(value['inn'])
      else
         false
      end
   end
end
