require 'jig'
Jig.enable :CSS

families = %w{Helvetica Arial sans_serif}
body_plist = { 
  'background-color' => '#FAFAFA',
  'font-size' => 'small',
  'font-family' => families,
  'color' => '#7F7F7f'
}
sheet = Jig.instance_eval {[
  body(         body_plist),
  null*navbar       |{:width => 500.px},
  null.navitem      |{:color => 'red'},
  a%hover           |{:text_decoration => 'underline'},
  div*menu          |{:background => 'green'},
  div.foo           |{:background => 'red'},
  div + foo*x > li[:class => 'even'] >> span |
                     {:clear => 'left'},
  us                |{:font_weight => 'bold'},
  us*even           |{:font_weight => 'bold'},
  group(h1, h2, h3) |{:background => 'silver' }|{:color => 'blue'}
]}

puts sheet
