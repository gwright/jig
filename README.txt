Jig
    by Gary R. Wright
    FIX (url)

== DESCRIPTION:
  
A jig is a data structure designed to facilitate construction and
manipulation of strings with an inherent hierarchical syntax.  The
idea is derived from the <bigwig> project (http://www.brics.dk/bigwig/)
and in particular the XML templating constructs described in the
paper: A Type System for Dynamic Web Documents
(http://www.brics.dk/bigwig/publications/dyndoc.pdf).  The name is
derived from woodworking where a jig is a template designed to guide
other tools.

A jig is an ordered sequence of objects (usually strings) and named
_gaps_.  When rendered as a string by Jig#to_s, the objects are
rendered calling #to_s on each object in order. The gaps are skipped.

A new jig may be constructed from an existing jig by 'plugging' one
or more of the named gaps.  The new jig shares the objects and their
ordering from the original jig but with the named gap replaced with
the 'plug'.  Gaps may be plugged by any object or sequence of
objects.  When a gap is plugged with another jig, the contents
(including gaps) are incorporated into the new jig.

Several subclasses (Jig::XML, Jig::XHTML, Jig::CSS) are defined to
help in the construction of XML, XHTML, and CSS documents.

This is a jig with a single gap named :alpha.
  Jig.new(:alpha)                         # => <#Jig: [:alpha]>
This is a jig with two objects, 'before' and 'after' separated by
a gap named :middle.
  j = Jig.new('before', :middle, 'after)  # => #<Jig: ["before", :middle, "after"]>
The plug operation derives a new jig from the old jig.
  j.plug(:middle, ", during, and")        # => #<Jig: ["before", ", during, and ", "after"]>
This operation doesn't change j.  It can be used again:
  j.plug(:middle, " and ")                # => #<Jig: ["before", " and ", "after"]>
There is a destructive version of plug that modifies
the jig in place:
  j.plug!(:middle, "filled")          # => #<Jig: ["before", "filled", "after"]>
  j                                   # => #<Jig: ["before", "filled", "after"]>
There are a number of ways to construct a Jig and many of
them insert an implicit gap into the Jig.  This gap is
identified as :___ and is used as the default gap
for plug operations when one isn't provided:

  puts Jig.new("A", :___, "C").plug("B")   # => ABC

In order to make Jig's more useful for HTML generation,
the Jig::XHTML class supports a variety of convenience methods;

  HT = Jig::XHTML
  puts b = HT.element("body")     # => <body></body>
  puts b.plug("text")             # => <body>text</body>

Method missing makes this even simpler:

  b = HT.span
  puts b.plug("text")             # => <span>text</span>

Attributes can be specified with a hash:

  summary = HT.p(:class => "summary")
  puts summary.plug("This is a summary") # => <p class="summary">This is a summary</p>

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
