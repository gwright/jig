
require "jig"
#
# there are bunch of shorthand methods - each is 'escaped' via a double
# underscore
#
Jig.enable :xml
include Jig::Proxy

puts xml_{ t__{ 'this is text data' } }
puts xml_{ x__{ '<xml> in raw form, nothing is auto-escaped </xml>' } }
puts xml_{ h__{ '<html> entities like & are ignored </html>' } }
puts xml_{ c__{ 'cdata' } }
puts xml_{ tag_(a__('k=v, x=y')){ 'a__ is a handy attribute parser' } }
puts xml_{ tag_(y__('k: v, a: b')){ 'y__ is too - yaml style' } }

~ > ruby samples/g.rb

<?xml version='1.0'?>this is text data
<?xml version='1.0'?><xml> in raw form, nothing is auto-escaped </xml>
<?xml version='1.0'?><html> entities like & are ignored </html>
<?xml version='1.0'?><![CDATA[cdata]]>
<?xml version='1.0'?><tag k='v' x='y'>a__ is a handy attribute parser</tag>
<?xml version='1.0'?><tag k='v' a='b'>y__ is too - yaml style</tag>



