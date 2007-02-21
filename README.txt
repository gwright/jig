jig
    by Gary R. Wright
    FIX (url)

== DESCRIPTION:
  
A jig is a data structure designed to facilitate construction and manipulation of strings with an inherent hierarchical syntax.
The name is derived from woodworking where a jig is a template designed to guide other tools.
The idea is derived from the <bigwig> project (http://www.brics.dk/bigwig/) and in particular the XML templating
constructs described in the paper: A Type System for Dynamic Web Documents (http://www.brics.dk/bigwig/publications/dyndoc.pdf).

A jig is an ordered sequence of objects (usually strings) and named _gaps_. 
A string corresponding to the jig is produced by Jig#to_s and is formed by
concatenating the string representation of the objects (via #to_s). 
Gaps are skipped and thus not represented in the resulting string.

A new jig may be constructed from an existing jig by 'plugging' a named gap.  
The new jig shares the objects and their ordering from the previous jig but with the named gap replaced with the 'plug'.
Gaps may be plugged by any object or sequence of objects.
When a gap is plugged with another jig, the contents (including gaps) are incorporated into the new jig.

By default, a Jig does not provide any methods that are XML specific.
Additional XML features can be enabled dynamically via Jig.enable(:xml).

== FEATURES/PROBLEMS:
  
* FIX (list of features or problems)

== SYNOPSYS:

  j = Jig.new("a", :middle, "c")
  j.to_s                        # "ac"
  j2 = j.plug(:middle, "b")
  p j2 == j                     # false
  j2.to_s                       # "abc"
  
  j2 = Jig.new(:part1, :part2)  # two gaps
  j3 = j.plug(:middle, j2)      # 
  
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
