
require "jig"
Jig.enable :xml

class C
  attr_accessor 'table'
  include Jig::Proxy

  def initialize
    @table = %w( a b c ), %w( 1 2 3 )
  end

  def to_xml
    xml(
      class_( self.class ),
      object__id_( 42 ),
      send_('send'),
      exit_('exit'),
      table_( tr_ * table.map { |row| td * row } )
    )
  end

  def to_jig
    @_jig ||= xml(
      class_( self.class ),
      object__id_( 42 ),
      send_('send'),
      exit_('exit'),
      table_ { tr_ * table.map { |row| td * row } }
    )
  end
end

puts C.new.to_xml # auto indentation with 'pretty'

c1 = C.new
puts c1.to_jig
c1.table.reverse!
puts c1.to_jig
