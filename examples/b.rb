
require "jig"
Jig.enable :xml

class C
  attr_accessor 'body'
  include Jig::Proxy

  def initialize
    @body = 'body'
  end

  def to_html
    xhtml { html { body_ { body } } }
  end

  def to_jig
    xhtml << html << body_ { body }
  end
end

puts C.new.to_html

c2 = C.new
jig = c2.to_jig
puts jig

c2.body = 'version 2 body'
puts jig
