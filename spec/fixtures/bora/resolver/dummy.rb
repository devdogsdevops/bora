class Bora
  module Resolver
    class Dummy
      def initialize(stack); end

      def resolve(_uri)
        'foo'
      end
    end
  end
end
