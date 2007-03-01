
require "jig"
Jig.enable :xml

puts Jig.instance_eval {
  xml(
    html(
      head( title("Sample A")),
      body( "sample body")
    )
  )
}
