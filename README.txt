jig
    by Gary R. Wright
    FIX (url)

== DESCRIPTION:
  
A jig is a hierarchical data structure used to construct and manipulate strings with an inherent hierarchical syntax.
The name is derived from woodworking where a jig is a wooden template designed to guide other woodworking tools.

A jig represents an ordered sequence of strings and named 'gaps'.  When converted to a string (via Jig#to_s), strings
are copied as is and gaps are represented by a null string.  A new jig may be constructed from an existing jig by 'plugging' 
a named gap.  The new jig shares the layout of the previous jig but with the named gap replaced with the 'plug'.
Gaps may be plugged by strings, another jig, instances of Proc, or any object that responds to #to_s.  
The nature of the plug operation results in common fragments being shared across Jig instances.

== FEATURES/PROBLEMS:
  
* FIX (list of features or problems)

== SYNOPSYS:

  j = Jig.new("a", :middle, "c")
  j.to_s															# "ac"
  j.plug(:middle, "b").to_s						# "abc"
  
  j2 = Jig.new(:part1, :part2)				# two gaps
  j3 = j.plug(:middle, j2)						# 
  

== REQUIREMENTS:

* Ruby 1.8

== INSTALL:

* sudo gem install jig

== LICENSE:

(The MIT License)

Copyright (c) 2007 Gary R. Wright

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
