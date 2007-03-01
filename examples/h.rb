
require "jig"
Jig.enable:xml
include Jig::Proxy

jig = Jig.new( xhtml(html(body(table(:table), b(:var)))) )

table = lambda { Jig.tr * @table.map { |r| td * r } }

local_variable = nil
jig2 = Jig.new( xhtml(html(body(table(&table), b { local_variable } ))))

@table = [
  %w( a b c ),
  %w( x y z ),
]

local_variable = 'some value'
puts jig2
local_variable = 'some other value'
puts jig2
