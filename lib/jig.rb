
require 'strscan'

=begin rdoc
A jig is an ordered sequence of objects and named gaps. During construction,
a gap is represented by a symbol:

  Jig.new('left', :middle, 'right')   # ["left", :middle, "right"]
  Jig.new(1, :two, 3.0, "4")          # [1, :two, 3.0, "4"]
  Jig.new(lambda { rand(6) })         # [<Proc:0x 255b2>]

As a convenience, a block provided to Jig::new is added to the sequence as a proc:

  Jig.new { rand(6) }                 # [<Proc:0x 27646>]

Jig#[] also constructs new jig instances:

  Jig[:header, :body, :footer]        # [:header, :body, :footer]

The primary motivation for Jigs is to provide a templating mechanism for strings.
In woodworking, a jig is a piece of wood used as a template or guide for other tools.

At any time, a jig can be converted to a string by Jig#to_s.  The string is 
constructed by concatenating string representations of the objects in the jig as follows:
- strings are concatenated as-is
- gaps are skipped
- procs are evaluated, the results converted to a string, and concatenated
- other objects are converted by calling _to_s_ and the resulting string is concatenated

A variety of operations are provided to manipulate jigs but the
most interesting is the 'plug' operation:

  grep  = Jig.new("grep", :pattern, :files)
  grep_religion = command.plug(:pattern, "religion")
  grep_all = grep_religion.plug(:files, %w{file1 file2 file3}.join)

which constructs a new jig that shares all the contents of the
previous jig but with the named gap replaced by one or more objects.
If there are more than one gaps with the same name, they are all
replaced with the same sequence of objects.

  j = Jig.new("first", :separator, "middle", :separator, "after")
  j.plug(:separator, '/').to_s    # "first/middle/last"

This is a jig with a single gap named "alpha".
  j = Jig.new(:alpha)
The plug operation derives a new jig from the old jig.
  j.plug(:alpha, "during")        # -> beforeduringafter

This operation doesn't change j.  It can be used again:

  j.plug(:alpha, "and")           # -> beforeandafter

There is a destructive version of plug that modifies
the jig in place:

  j.plug!(:alpha, "filled")       # -> beforefilledafter

There are a number of ways to construct a Jig and many of
them insert an implicit gap into the Jig.  This gap is
identified as :___ and is used as the default gap
for plug operations when one isn't provided:

  Jig.new("A", :___, "C").plug("B")   # -> ABC

In order to make Jig's more useful for HTML generation,
the Jig class supports a variety of convenience methods;

  b = Jig.element("body")     # <body></body>
  b.plug("text")              # <body>text</body>

Method missing makes this even simpler:

  b = Jig.body
  b.plug("text")

Attributes can be specified with a hash:

  b = Jig.p({:class => "summary"})
  b.plug("This is a summary")
  # <p class="summary">This is a summary</p>

=end
class Jig
  module Mixin
  end
  VERSION = '0.8.0'
  autoload :XML, "jig/xml"
  autoload :XHTML, "jig/xhtml"
  autoload :CSS, "jig/css"
  GapPattern = "[a-zA-Z_/][a-zA-Z0-9_/]*"

  # A Gap represents a named position within the ordered sequence of objects
  # stored in a Jig.  In addition to a name, a gap can also have an associated
  # filter.  When a gap is filled by a plug operation, the replacement items are
  # passed to the filter and the return value(s) are used as the replacement items.
  # The default filter simply returns the same list of items.
  class Gap
    ATTRS = :__a
    GAP = :___
    attr :name    # the name associated with the gap
    attr :filter  # the lambda associated with the gap

    # Construct a new gap with the specified name.  A block, if given, becomes
    # the filter for replacement items.
    def initialize(name=GAP, &filter)
      @name = name.to_sym
      @filter = filter && lambda(&filter)
    end

    def inspect
      "#<Gap: [#{name}, #{filter.inspect}]>"
    end

    # Pass the replacement items through the filter.
    def fill(*filling)
      return *(filter && filter[*filling] || filling)
    end

    # Two gaps are equal if they have the same name and
    # use the same filter.
    def ==(other)
      name == other.name && filter == other.filter
    end
  end

  DEFAULT_GAP = Gap.new
  GAP = DEFAULT_GAP.name

  attr_accessor  :contents    # the sequence of objects
  protected      :contents=
  attr_accessor  :rawgaps        # the unfilled gaps
  protected      :rawgaps=
  attr_accessor  :extra       # extra state information, used by extensions
  protected      :extra

  class <<self
    alias [] :new

    # Construct a null jig.  An null jig has no contents and no gaps and
    # is often useful as a starting point for construction of more complex jigs.
    # It can be considered analogous to an empty array or a null string.
    def null
      new(nil)
    end
  end

  # A jig is rendered as an array of objects with gaps represented by symbols.
  # Gaps with associated filters are shown with trailing braces: :gap{}.
  #   Jig.new.inspect         # #<Jig: [:___]>
  def inspect
    info = rawgaps.map {|g| g.filter && "#{g.name}{}".to_sym || g.name }
    "#<Jig: #{contents.zip(info).flatten[0..-2].inspect}>"
  end

  # Returns _true_ if the jig has no remaining gaps to be filled.
  #   Jig.new.full?            # false
  #   Jig.new('a').full?       # true
  #   Jig.new.plug('a').full?  # true
  def closed?
    rawgaps.empty?
  end

  # Returns _true_ if the jig has any remaining gaps to be filled.
  #   Jig.new.full?            # true
  #   Jig.new('a').full?       # false
  #   Jig.new.plug('a').full?  # false
  def open?
    not rawgaps.empty?
  end

  # Returns _true_ if the jig has no gaps and corresponds to the empty string.
  #   Jig.new.empty?           # false
  #   Jig.new(nil).empty?      # true
  #   Jig.new.plug("").empty?  # true
  def null?
    closed? && to_s.empty?
  end

  # Returns an array containing the names, in order, of the gaps in
  # the current jig.  A name may occur more than once in the list.
  def gaps
    rawgaps.collect { |g| g.name }
  end

  # Returns _true_ if the named gap appears in the jig.
  def has_gap?(gap_name)
    rawgaps.find {|x| x.name == gap_name }
  end

  # Returns the position of the named gap or nil if the gap
  # is not found.
  def index(name)
    rawgaps.each_with_index {|g,i| return (i*2)+1 if g.name == name }
    nil
  end

  # call-seq:
  #   slice(n)  -> jig
  #   slice(s..e)  -> jig
  #   slice(name) -> gap
  #
  # Extracts parts of a jig.  If an integer index is provided the
  # contents preceeding the nth gap is returned as a jig.
  # If called with a range index, the contents selected by the
  # range is returned as well as any gaps within that range.
  # If a non-numeric index is provided, the gap with the matching
  # name is returned. Returns nil if the numeric index is out of range or the
  # named gap is not found.
  #
  #   j = Jig.new('0', :alpha, '1', :beta, '2')
  #   j.slice(:alpha)         # #<Gap: :alpha >
  #   j.slice(0)              # Jig['0']
  #   j.slice(0..1)           # Jig['0', :alpha, '1']
  def slice(index)
    if Integer === index
      if (index % 2).zero?
        Jig[contents[index/2]]
      else
        rawgaps[(index-1)/2]
      end
    elsif Range === index
      j = Jig.new
      altindex = lambda { |x| (contents.size-1)*2 + x + 1 }
      b = (index.begin >= 0) && index.begin || altindex[index.begin]
      e = (index.end >= 0) && index.end || altindex[index.end]
      index = b..e
      case [index.begin % 2, index.end % 2]
      when [0,0]
        j.rawgaps = rawgaps[(index.begin/2)...(index.end/2)]
        j.contents = contents[(index.begin/2)..(index.end/2)]
      when [0,1]
        j.rawgaps = rawgaps[(index.begin/2)...((index.end+1)/2)]
        j.contents = contents[(index.begin/2)..((index.end-1)/2)].push([])
      when [1,0]
        j.rawgaps = rawgaps[((index.begin-1)/2)...((index.end)/2)]
        j.contents = contents[(index.begin+1/2)..((index.end)/2)].unshift([])
      when [1,1]
        j.rawgaps = rawgaps[((index.begin-1)/2)...((index.end+1)/2)]
        j.contents = contents[((index.begin+1)/2)..((index.end-1)/2)].push([]).unshift([])
      end
      if !j.contents or !j.rawgaps
        raise ArgumentError, "index #{index} out of range"
      end
      j
    else
      has_gap?(index)
    end
  end

  # call-seq:
  #   jig * int    -> a_jig
  #   jig * array  -> a_jig
  #
  # With an integer argument, a new jig is constructed by concatenating
  # *int* copies of *self*.
  #   three = Jig.new * 3      # Jig[:___, :___, :___]
  #   puts three.plug('3')     # "333"
  # With an array argument, the elements of the array are used to plug
  # the default gap. The resulting jigs are concatenated
  # to form the final result:
  #   item = Jig["- ", :___, "\n"]
  #   list = item * [1,2,3]
  #   puts list               # "- 1\n- 2\n- 3\n"
  def mult(other)
    case other
    when Integer
      raise ArgumentError, "count must be greater than zero" if other < 1
      (1...other).inject(dup)  { |j,i| j.push_jig(self) }
    when Array
      other.inject(Jig.null) { |j,x| j.concat( plug(x) ) }
    else
      raise ArgumentError, "other operand for * must be Integer or Array, was #{other.class})"
    end
  end

  # Construct a jig from the list of _items_.  Symbols in the list are
  # replaced with a gap named by the symbol.
  #
  #   item = Jig.new(:quantity, "@", :price, "=", :amount)
  #   time = Jig.new(:hours, ":", :minutes, ":",  :seconds)
  #
  # If a block is provided, it is appended as a proc to the list of items. Procs within
  # a jig are not evaluated until the jig is converted to a string by Jig#to_s.
  #   i = 0
  #   j = Jig.new("i = ") { i }
  #   puts j     # i = 0
  #   i = 1
  #   puts j     # i = 1
  # 
  # If no arguments are given and no block is given, the jig is constructed
  # with a single default gap named :___ (also known as Jig::GAP).
  #   one_gap = Jig.new
  #   p one_gap.gaps   # [:___]
  def initialize(*items, &block)
    @contents = [[]]
    @rawgaps = []
    @extra = {}
    items.push(block) if block
    items.push(DEFAULT_GAP) if items.empty?
    concat(items)
  end

  # Applies Kernel#freeze to the jig and its internal structures.  A frozen jig
  # may still be used with non-mutating methods such as #concat or #plug but an exception
  # will be raised if a mutating method such as #push or #plug! are called.
  def freeze
    super
    @contents.freeze
    @rawgaps.freeze
    @extra.freeze
    self
  end

  # Returns _true_ if the two jigs have equal gap lists and contents.
  # Jigs that are not equal may still have the same string representation.
  # Procs are not evaluated by _==_.
  #   a = Jig.new(:alpha, :beta)
  #   b = Jig.new(:alpha, :beta)
  #   a.equal?(b)            # false
  #   a == b                 # true
  #   a.plug(:alpha, 1) == b.plug(:beta, 1)              # false
  #   a.plug(:alpha, 1).to_s == b.plug(:beta, 1).to_s    # true
  #
  def ==(other)
    self.class == other.class &&
    (rawgaps == other.rawgaps) && 
    (contents.flatten == other.contents.flatten)
  end

  # Returns true if the string representation of the jig equals 
  # other.to_s.
  def =~(other)
    to_s == other.to_s
  end

  # Return self.
  def to_jig
    self
  end

  # Create a new jig formed by inserting a copy of the current jig between each
  # element of the array.  The elements of the array are treated like plug arguments.
  # Example : (Jig.new('X') | [1,2,3]).to_s   # =>  "1X2X3"
  # XXX
  def wedge(array)
    Jig[array.zip((1..(array.size - 1)).to_a.map { self.dup })]
  end

  # A duplicate jig is returned.  This is a shallow copy, the 
  # contents of the jig are not duplicated.
  def dup
    other = super
    other.contents = @contents.dup
    other.rawgaps = @rawgaps.dup
    other.extra = @extra.dup
    other
  end

  # Pushes the items onto the end of the current jig.
  # The current jig is modified.  Use jig.dup.push(*items) if
  # you want a fresh jig.  Individual items are handled as follows:
  # - strings: pushed as is
  # - symbols: converted to a gap and pushed
  # - gaps: pushed as is
  # - jigs: each item of the other jig is pushed in order to the current jig, including gaps.
  # - any object that responds to _to_jig_ is converted and the results pushed.
  # - any object that responds to _call_ is pushed as a proc.
  # - all other objects are pushed as is.
  #
  # If XML features have been enabled:
  # - hash: each key, value pair is appended as follows:
  #   - if the value is a symbol, the pair is appended as an attribute gap
  #   - if the value is a Jig::Gap, the pair is appended as an attribute gap
  #   - otherwise the pair is converted to a string (#{key}=\"#{value}\") and appended
  def push(*items)
    items.each do |i|
      case i
      when NilClass, FalseClass then next
      when Symbol   then push_gap Gap.new(i)
      when String   then contents.last << i
      when Jig::Gap then push_gap i
      when Jig      then push_jig i
      else 
        if respond_to?(p = "push_#{i.class.name.downcase}")
          send(p, i)
        elsif i.respond_to? :to_jig
          push_jig i.to_jig
        else
          if i.respond_to? :call
            (class <<i; self; end).class_eval {
              undef inspect
              alias inspect :to_s
              def to_s; call.to_s; end
            }
          end
          contents.last << i
        end
      end
    end
    self
  end

  # The collection is converted to a list of items via *collection.
  # Resulting items are pushed onto the end of the current jig.
  #
  #   j = Jig.new 1
  #   j.concat([2,3])
  #   j == Jig[1,2,3]                # true
  #
  #   j.concat Jig[4,:alpha,5]
  #   j == Jig[1,2,3,4,:alpha,5]     # true
  #
  # If you don't want to modify the current jig, use Jig#+ instead.
  def concat(collection)
    push(*collection)
  end

  # Duplicates the current jig and calls map!.
  def map(&b)
    dup.map!(&b)
  end

  # Iterates through all the gaps passing the name of each gap
  # to the block. The value yielded by the block is used 
  # to plug the gap.
  #   j = Jig.new(:alpha, :beta).map do |g|
  #     g == :alpha && 'a' || g
  #   end
  #   j == Jig.new('a', :beta)          # true
  #
  # All the gaps are conceptually plugged at the same time. See
  # plug! for more details.
  def map!(&b)
    plug_all!(gaps_set.inject({}) { |h, g| h[g.name] = yield(g.name); h })
  end

  # call-seq:
  #   plug!(symbol)              -> a_jig
  #   plug!(symbol, item, *more) -> a_jig
  #   plug!(hash)                -> a_jig
  #   plug!(item, *more)         -> a_jig
  #   plug! { |gap| ... }        -> a_jig
  #   plug!                      -> a_jig
  #
  # Plugs one or more named gaps (see #plug) and returns self.  The current jig is
  # modified.  To construct a new jig use #plug instead.
  # If the named plug is not defined, the jig is not changed.
  def plug!(*args, &block)
    return fill!(&block) if block
    first = args.first
    return fill!(first) if first.respond_to?(:has_key?)

    if Symbol === first
      return fill!(first => (x = *args[1..-1]))
    else
      return fill!(GAP => (x = *args))
    end
  end
  alias []= :plug!

  def plugn!(first, *more, &block)
    case first
    when Integer
      index = first
    else
      more.unshift first
      index = 0
    end
    more.push(block) if block
    _plugn!(index, *more)
  end

  def multn(items)
    (0...[rawgaps.size,items.size].min).inject(self) { |j,i|
      j.plugn 0, items[i]
    }
  end

  # call-seq:
  #   plug(symbol)              -> a_jig
  #   plug(symbol, item, *more) -> a_jig
  #   plug(hash)                -> a_jig
  #   plug(item, *more)         -> a_jig
  #   plug                      -> a_jig
  #
  # Duplicates the current jig,  plugs one or more named gaps, and
  # returns the result. Plug silently ignores attempts to fill
  # undefined gaps.
  #
  # If called with a signle symbol argument, the
  # default gap is plugged with a simple gap (symbol).
  #
  # If called with a symbol and one or more items, the
  # named gap is plugged with the items.
  #
  # If called with a hash, the keys are used as gap names and
  # the values are used to plug the respective gaps.  The gaps
  # are effectively plugged in parallel to avoid any ambiguity
  # when gaps are plugged with jigs that themselves contain
  # additional gaps.
  #
  # If called with a list of one or more items the default gap is
  # plugged with the list of items.
  #
  # If called with no arguments, the default gap is closed by
  # plugging it with with nil.
  #
  #   b = Jig::Gap.new :beta
  #   j = Jig.new                 # Jig[:___]
  #   jg = Jig[:gamma, :epsilon]  # Jig[:gamma, :epsion]
  #
  #   j.plug :alpha               # Jig[:alpha]
  #   j.plug b                    # Jig[:beta]
  #   j.plug 1                    # Jig[1]
  #   j.plug :alpha, 'a'          # Jig[:___]
  #   jg.plug :gamma, 'a', 'b'    # Jig['a', 'b', :epsilon]
  #   jg.plug :gamma => 'a', 
  #           :epsilon => 'e'     # Jig['a', 'e']
  #   j.plug 1,2,3                # Jig[1,2,3]
  #   j.plug                      # Jig[nil]
  def plug(*args, &block)
    dup.plug!(*args, &block)
  end

  # call-seq:
  #   plugn(index, *items) -> a_jig
  #   plugn(array)         -> a_jig
  #   plugn(hash)          -> a_jig
  #   plugn(*items)        -> a_jig
  #
  # Similar to #plug but gaps are identified by numerical index, not by name.
  #
  # When called with an array, the nth item of the array is use to plug the
  # nth gap.
  #
  # When called with a hash, the hash keys are used as indexes into the
  # gap list.
  #
  # When called with no explicit index or implicit index list (array or
  # hash), the first gap (index = 0) is plugged with the items.
  #
  #   list = Jig["1) \n", :item, "2) \n", :item, "3) \n'", :item]
  #   result = list.plugn(:item, 'first', 'second', 'third')
  #   puts result           #   "1) first\n2) second\n3) third\n"
  def plugn(*args, &block)
    dup.plugn!(*args, &block)
  end

  #alias merge  :plug
  #alias merge! :plug!

  # Returns a new jig constructed by inserting the item *before* the specified gap.
  # The gap itself remains in the new jig.
  def before(first, *items)
    gap = GAP
    case first
    when Symbol
      if !items.empty?
        gap = first
      else
        items.unshift first
      end
    else
      items.unshift first
    end
    items.push(rawgaps.find {|x| x.name == gap})
    plug(gap, *items)
  end

  # A new jig is constructed by inserting the item *after* the specified gap.
  # The gap itself remains in the new jig.
  def after(gap, item=nil)
    gap,item = GAP, gap unless item
    plug(gap, Jig.new(gap, item))
  end

  alias << :plug!

  # Duplicate the current jig and then fill any gaps as with _fill!_
  def fill(hash)
    dup.fill!(hash)
  end


  # Duplicate the current jig and then fill any gaps specified by pairs via
  # _plug_all!_.
  def plug_all(pairs={})
    dup.plug_all!(pairs)
  end

  # Fill all remaining gaps with plugs from pairs. It is assumed that pairs
  # will always return a value for any key, perhaps nil.
  def plug_all!(pairs={})
    gaps.uniq.inject(self) {|jig,gap| jig.plug!(gap, pairs[gap]) }
  end

  alias close :plug_all!

  # A string is constructed by concatenating the contents of the jig.
  # Gaps are effectively considered null strings.  Any procs in the jig
  # are evaluated, the results converted to a string via to_s.  All
  # other objects are converted to strings via to_s.
  def to_s
    contents.join
  end

  def split(*args)
    if args.empty?
      contents.map { |c| c.join }
    else
      to_s.split(*args)
    end
  end

  def join(*args)
    contents.join(*args)
  end

  def open(*args, &b)
    join.open(*args, &b)
  end

  private 

  # This method is where the magic happens. The contents and gap arrays
  # are modified such that the named gap is removed and the items are 
  # put in its place.
  #
  # Gaps and contents are maintainted in two separate arrays.  Each
  # element in the contents array is a tree of objects implemented as
  # nested arrays.  The first element of the gap array represents the
  # gap between the the first and second element of the contents array.
  #
  #             0   1   2   3
  # contents:   c1  c2  c3  c4
  # gaps:       g1  g2  g3
  #
  # sequence:   c1  g1  c2  g2  c3  g3 c4
  #
  # The following relation always holds:  gaps.size + 1 == contents.size
  # 
  # Mutate the existing jig by filling all remaining gaps.  The gap name
  # is looked up via _pairs[name]_ and the result is used to plug the gap.
  # If there is no match in _pairs_ for a gap, it remains unplugged.
  # This method is useful when the number of gaps is small compared to
  # the number of pairs.
  def fill!(pairs=nil)
    self.rawgaps = rawgaps.inject([]) do |list, gap|
      insert = lambda {|match, fill|
          case fill.rawgaps.size
          when 0
            contents[match,2] = [[contents[match], fill.contents.first, contents[match+1]]]
          when 1
            contents[match,2] = [[contents[match], fill.contents.first ], [fill.contents.last, contents[match+1]]]
          when 2
            contents[match,2] = [[contents[match], fill.contents.first ],fill.contents[1], [fill.contents.last, contents[match+1]]]
          else
            contents[match,2] = [[contents[match], fill.contents.first ]].concat(fill.contents[1..-2]).push([fill.contents.last, contents[match+1]])
          end
          list.concat(fill.rawgaps)
      }
      items = if block_given?
        yield(gap.name) 
      else
        pairs.fetch(gap.name, gap.name)
      end
      if items == gap.name
        next list << gap 
      end
      match = list.size
      fill = *gap.fill(items)
      if !fill
        contents[match,2] = [[contents[match],contents[match+1]]]
        next list
      end
      case fill
      when Jig
        insert[match,fill]
      when Symbol
        list.push Gap.new(fill)
      when Gap
        list.push fill
      else
        if fill.respond_to?(:to_jig)
          insert[match, fill.to_jig]
        elsif fill.respond_to?(:fetch)
          insert[match, Jig[*fill]]
        elsif fill.respond_to?(:call)
          insert[match, Jig[*fill]]
        else
          contents[match,2] = [[contents[match],fill,contents[match+1]]]
          list
        end
      end
      list
    end
    self
  end

  def _plugn!(index, *items)
    fill = rawgaps.fetch(index).fill(*items)
    fill = fill.to_jig if fill.respond_to? :to_jig
    if Jig === fill
      case fill.rawgaps.size
      when 0
        contents[index,2] = [[contents[index], fill.contents.first, contents[index+1]]]
      when 1
        contents[index,2] = [[contents[index], fill.contents.first ], [fill.contents.last, contents[index+1]]]
      else
        contents[index,2] = [[contents[index], fill.contents.first ], fill.contents[1..-2], [fill.contents.last, contents[index+1]]]
      end
      gaps[index,1] = fill.rawgaps
    elsif Symbol === fill
      gaps[index, 1] = Gap.new(fill)
    elsif Gap === fill
      gaps[index, 1] = fill
    else
      contents[index, 2] = [contents[index,2].insert(1, fill)]
      gaps[index, 1] = nil
    end
    self
  end

  def push_gap(gitem)
    @rawgaps << gitem
    @contents << []
    self
  end

  def push_jig(other)
    self.contents = contents[0..-2] + [contents[-1] + other.contents[0]] + other.contents[1..-1]
    rawgaps.concat other.rawgaps
    self
  end
  protected :push_jig

  #Null = null.freeze

  class <<self
    GapStart = '(a:|:|\{)'
    GapEnd = '(:a|:|\})'
    DelimStart = Regexp.new "(<#{GapStart})"
    DelimEnd = "(#{GapEnd}>)"

    # Convert a string into a jig. Code in the string is evaluated relative to _context_,
    # which should be an instance of Binding.  If a block is provided, the block is evaluated
    # and its result is parsed into a jig.  In this case, the block is used as the
    # context for evaluating any embedded code.
    #
    # The method parses the string by looking for the following sequences:
    #   <:identifier:>    is converted into a named gap
    #   <:identifier,identifier:>  is converted to a key/value pair and becomes an attribute gap
    #   <{code}>          is converted to a proc
    def parse(string=nil, context=nil, &block)
      if block
        context = block
        string = block.call
      end
      raw = StringScanner.new(string)
      items = []
      while !raw.eos?
        if chunk = raw.scan_until(DelimStart)
          items << chunk[0..-3] unless chunk[0..-3].empty?
          start_delim = raw[1]
        else
          items << raw.rest
          break
        end

        case start_delim
        when '<:'   # gap
          unless raw.scan(Regexp.new("(#{GapPattern}),(#{GapPattern})(#{DelimEnd})"))
            unless raw.scan(Regexp.new("((#{GapPattern})|)#{DelimEnd}"))
              raise ArgumentError, "invalid gap found: #{raw.rest[0..10]}.."
            end
            if raw[1].empty?
              items << GAP
            else
              items << raw[2].to_sym
            end
            unless (end_delim = raw[3]) == ':>'
              raise ArgumentError, "mismatched delimiters: '#{start_delim}' and '#{end_delim}'"
            end
          else
            if items[-1].respond_to?(:merge)
              items[-1].merge! raw[1] => raw[2].to_sym
            else
              items << { raw[1] => raw[2].to_sym }
            end
            unless (end_delim = raw[3]) == ':>'
              raise ArgumentError, "mismatched delimiters: '#{start_delim}' and '#{end_delim}'"
            end
          end
        when '<{'   # code gap
          unless raw.scan(Regexp.new("(.*)#{DelimEnd}"))
            raise ArgumentError, "unterminated code gap found: #{raw.rest[0..10]}.."
          end
          code = raw[1]
          unless (end_delim = raw[2]) == '}>'
            raise ArgumentError, "mismatched delimiters: '#{start_delim}' and '#{end_delim}'"
          end
          items << eval( "lambda { #{code} }", context)
        end
      end
      newjig = self[*items]
      newjig
    end

    # Read the contents of filename into a string and parse it as Jig.
    def parse_file(filename, *context)
      parse(File.read(filename), *context)
    end

    # Incorporate methods and class methods specific to _feature_.
    def xenable(*features)
      features.map do |f|
        begin
          begin
            extend Jig.const_get(f)::ClassMethods
          rescue NameError
          end
          include Jig::const_get(f)
          f
        rescue
          nil
        end
      end
    end

    def xderive(*features)
      Class.new(self) {
        enable(*features)
      }
    end
  end

  module Base
    # call-seq:
    #   jig + obj -> a_jig
    #
    # Duplicate the current jig then use concat to add _obj_.
    #   j = Jig[1, :alpha]
    #   j + 2                     # Jig[1, :alpha, 2]
    #   j + :beta                 # Jig[1, :alpha, :beta]
    #   j + Jig[:beta]            # Jig[1, :alpha, :beta]
    #   j + [3,4]                 # Jig[1, :alpha, 3, 4]
    #   j + [Jig.new, Jig.new]    # Jig[1, :alpha, :___, :___]
    #   j + Jig[:beta] * 2        # Jig[1, :alpha, :beta, :beta]
    def +(obj)
      dup.concat(obj)
    end
    def [](*args)
      slice(*args)
    end

    def *(*args)
      mult(*args)
    end

    def ^(*args)
      multn(*args)
    end
  end
  include Base

  module Proxy
    def method_missing(*a, &b)
      Jig.send(*a, &b)
    end
  end
end
