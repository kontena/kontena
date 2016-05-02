module Kontena
  module Cli
    module BytesHelper

      KILOBYTE = 1024
      MEGABYTE = KILOBYTE * 1024
      GIGABYTE = MEGABYTE * 1024
      TERABYTE = GIGABYTE * 1024

      def to_kilobytes(bytes, ndigits=nil)
        return 0.0 if bytes.nil?
        round(bytes.to_f / KILOBYTE, ndigits)
      end

      def to_megabytes(bytes, ndigits=nil)
        return 0.0 if bytes.nil?
        round(bytes.to_f / MEGABYTE, ndigits)
      end

      def to_gigabytes(bytes, ndigits=nil)
        return 0.0 if bytes.nil?
        round(bytes.to_f / GIGABYTE, ndigits)
      end

      def to_terabytes(bytes, ndigits)
        return 0.0 if bytes.nil?
        round(bytes.to_f / TERABYTE, ndigits)
      end

      private
      def round(value, ndigits=nil)
        if ndigits.nil?
          return value
        end
        value.round(ndigits)
      end

    end
  end
end
