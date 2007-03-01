
require "jig"
Jig.enable :xml

#
# '_' really bails you out for namespaces
#
module Furniture
  class Table
    include Jig::Proxy

    attr 'legs'

    def initialize
      @legs = %w[ 1 2 3 4 ]
    end

    def to_xml
      xml(
        furniture_table({'xmlns:f' => 'http://www.w3schools.com/furniture'},
          *legs.map { |l| furniture_leg("leg #{l}") }
        )
      )
    end
  end
end

puts Furniture::Table.new.to_xml
