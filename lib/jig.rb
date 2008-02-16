require 'strscan'

=begin rdoc
A jig is an ordered sequence of objects and named gaps. During construction,
a gap is represented by a symbol:

  Jig.new('left', :middle, 'right')   # => <#Jig: ["left", :middle, "right"]>
  Jig.new(1, :two, 3.0, "4")          # => <#Jig: [1, :two, 3.0, "4"]>
  Jig.new(lambda { rand(6) })         # => <#Jig: [#<Proc:0x00437ee8>]

As a convenience, a block provided to Jig::new is added to the sequence as a proc:

  Jig.new { rand(6) }                 # => #<Jig: [#<Proc:0x00026660@-:2>]>

Jig#[] also constructs new jig instances:

  Jig[:header, :body, :footer]        # [:header, :body, :footer]

At any time, a jig can be converted to a string by Jig#to_s.  The string is 
constructed by concatenating string representations of the objects in the jig as follows:
- strings are concatenated as-is
- gaps are skipped
- procs are evaluated, the results converted to a string, and concatenated
- other objects are converted by calling _to_s_ and the resulting string is concatenated

A variety of operations are provided to manipulate jigs but the
most common is the 'plug' operation:

  comment = Jig.new("/*", :comment, "*/")
  partial = comment.plug(:comment, "This is a ", :adjective, " comment")
  puts partial.plug(:adjective, 'silly')        # => /* This is a silly comment */
  puts partial.plug(:adjective, 'boring')       # => /* This is a boring comment */

The plug method constructs a new jig that shares all the contents of the
previous jig but with the named gap replaced by one or more objects.
If there are more than one gaps with the same name, they are all
replaced with the same sequence of objects.

  j = Jig.new("first", :separator, "middle", :separator, "after")
  puts j.plug(:separator, '/')                  # => "first/middle/last"
=end
class Jig
  VERSION = '0.1.0'
  autoload :XML, "jig/xml"
  autoload :XHTML, "jig/xhtml"
  autoload :CSS, "jig/css"

  # A Gap represents a named position within the ordered sequence of objects
  # stored in a jig.  In addition to a name, a gap can also have an associated
  # filter.  When a gap is filled by a plug operation, the replacement items are
  # passed to the filter and the return value(s) are used to fill the gap.
  # The default filter simply returns the unchanged list of items.
  class Gap
    ATTRS = :__a
    GAP = :___

    # the name associated with the gap
    attr :name    

    # the lambda associated with the gap
    attr :filter  

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

    # Change the name of the gap.
    def rename(name)
      @name = name.to_sym
      self
    end

    # Construct a new gap, _name..  This gap will try to re-format lines of
    # text to a maximum of _width_ columns.
    #   ten = Jig.new(Jig::Wrap.new(10))
    #   puts ten.plug("this is ok")           # => "this is ok"
    #   puts ten.plug("this will be split")   # => "this will\nbe split"
    def self.wrap(width=72, name=GAP)
      new(name) do |plug| 
        # From James Edward Gray II's entry to Ruby Quiz #113 [ruby-talk:238693]
        plug.to_s.sub("\n"," ").strip.gsub(/(.{1,#{width}}|\S{#{width+1},})(?: +|$\n?)/, "\\1\n").chomp
      end
    end

    # Construct a new gap, _name_. This gap will try to re-format lines of
    # text into a single or multi-line comment block with each line of text
    # limited to _width_ columns.
    #
    # If _prefix_ is provided, each line of text will be prefixed accordingly.
    # If _open_ is provided, a single line of text will be wrapped with the _open_
    # and _close_ strings but multiple lines of text will be formatted as a block
    # comment.  If _close_ is not provided it is taken to be the <i>open.reverse</i>.
    #   Jig[Jig::Gap.comment]                       # text reformated to 72 columns
    #   Jig[Jig::Gap.comment("# ")]                 # text reformated as Ruby comments
    #   Jig[Jig::Gap.comment("// ")]                # text reformated as Javascript comments
    #   Jig[Jig::Gap.comment(" *", "/* ")]          # text reformated as C comments
    #
    # If the default gap name isn't appropriate you must fill in all the arguments:
    #   Jig[Jig::Gap.comment("# ", nil, nil, 72, :alternate)]    # alternate gap name
    def self.comment(prefix="", open=nil, close=nil, width=72, name=GAP)
      wrap = Jig[Jig::Gap.wrap(width, name)]
      if open
        close ||= open.reverse
        block_line = Jig.new(prefix, " ", GAP, "\n")
        one_line = Jig.new(open, GAP, close, "\n")
        block = Jig.new(open, "\n", GAP, close, "\n")
      else
        one_line = Jig.new(prefix, GAP, "\n")
        block_line = one_line
        block = Jig.new
      end
      new(name) do |plug|
        text = (wrap % plug.to_s).to_s
        if text.index("\n")
          block % (block_line * text.split(/\n/))
        else
          block % (one_line % text)
        end
      end
    end
  end

  # :section: Construction

  DEFAULT_GAP = Gap.new
  GAP = DEFAULT_GAP.name

  # the sequence of objects
  attr_accessor  :contents    
  protected      :contents=
  # the unplugged gaps
  attr_accessor  :rawgaps     
  protected      :rawgaps=

  class <<self
    alias [] :new

    # Construct a null jig.  A null jig has no contents and no gaps.
    # It can be considered analogous to an empty array or a null string.
    #   jigs = (1..3).map { |i| Jig[i, :___, i] }
    #   aggregate = jigs.inject(Jig.null) { |s,j| s + j }
    #   puts aggregate.plug('x')    # 1x12x23x3
    def null
      new(nil)
    end

    # Convert a string into a jig. The string is scanned for blocks deliminated by %{...}.
    # The blocks are interpreted as follows:
    #   %{:identifier:}          is converted into a gap named *identifier*
    #   %{!code!}                is converted to a lambda
    #
    # Code blocks are interpreted when the resulting jig is rendered via Jig#to_s.
    # Each time parse is called, an anonymous module is created to evaluate *all* the
    # code blocks created during that call to parse. Alternatively, the code blocks can
    # be evaluated against an explicit binding passed as the second argument.
    #
    #   Jig.parse("abc").to_s     # abc
    #   Jig.parse("1 %{:x} 3")    # Jig[1, :x, 3]
    #   Jig.parse("1 %{:x} 3")    # Jig[1, :x, 3]
    #
    #   a = 5
    #   Jig.parse("%{a + 1}", binding).to_s    #  6
    #   Jig.parse("%{b + 1}").to_s             #  NameError
    #
    #   class A
    #     def to_jig
    #       Jig.parse("secret: %{secret}", binding)
    #     end
    #     def secret
    #        "xyzzy"
    #     end
    #     private :secret
    #   end
    #
    #   A.new.secret          # NoMethodError
    #   A.new.to_jig.to_s     # secret: xyzzy

    Before = /[^%]*/
    Replace = /%\{(.?)(.+)\1\}/

    def parse(string=nil, context=nil)
      wrapper = context || Module.new.class_eval { binding }
      scanner = StringScanner.new(string)
      raw = []
      while !scanner.eos?
        if before = scanner.scan(Before)
          if replace = scanner.scan(Replace)
            raw << before
            raw << interpolate(replace, wrapper)
          else
            raw << before
            raw << scanner.getch unless scanner.eos?
          end
        else
          raw << scanner.rest
          scanner.terminate
        end
      end
      Jig.new(*raw)
    end

    def interpolate(replace, context)
      all, delimiter, content = *(replace.match(Replace))

      case delimiter
      when ':'
        content.to_sym
      when '!', ''
        eval("lambda {#{content}}", context)
      else
        parse_other(delimiter, content)
      end
    end

    def parse_other(delim, stripped)
      raise ArgumentError, "invalid delimiter: \"#{delim}\""
    end
    private :parse_other
  end

  # Construct a jig from the list of _items_.  Symbols in the list are
  # replaced with a gap named by the symbol.
  #
  #   j1 = Jig.new('first', :middle, 'last')      # => #<Jig: ['first', :middle, 'last']
  #   j1.gaps                                     # => [:middle]
  #
  # If a block is provided, it is appended as a proc to the list of items. 
  # Procs within a jig are not evaluated until the jig is rendered as a
  # string by to_s.
  #
  #   i = 0
  #   j = Jig.new("i is ") { i }
  #   puts j                        # => "i is 0"
  #   i = 1
  #   puts j                        # => "i is 1"
  # 
  # If no arguments are given and no block is given, the jig is constructed
  # with a single default gap named <tt>:\___</tt> (also known as Jig::GAP).
  #   one_gap = Jig.new
  #   one_gap.gaps           # => [:___]
  def initialize(*items, &block)
    @contents = [[]]
    @rawgaps = []
    items.push(block) if block
    items.push(DEFAULT_GAP) if items.empty?
    concat(items)
  end

  # The internal structure of a jig is duplicated on #dup or #clone, but
  # not the objects that make up the contents of the jig.  This is analogous
  # to how an array is duplicated.
  def initialize_copy(other)
    super
    @contents = other.contents.dup
    @rawgaps = other.rawgaps.dup
  end

  # :section: Equality
  # This section describes methods for comparing jigs.
  # [<tt>j1.equal?(j2)</tt>]   identity, same objects
  # [<tt>j1.eql?(j2)</tt>]     equivalent, same class and structure
  # [<tt>j1 == j2</tt>]        similar, jigs with same structure
  # [<tt>j1 =~ j2</tt>]        text representations are equal
  #
  #   a = Jig.new(:alpha, 1, :beta)
  #   b = Jig.new(:alpha, 1, :beta)
  #   a.equal?(b)             # false
  #   a.eql?(b)               # true
  #
  #   c = Class.new(Jig).new(:alpha, 1, :beta)
  #   a.eql?(c)               # false
  #   a == c                  # true
  #   a =~ c                  # true
  #   a.to_s == c.to_s        # true
  #
  #   d = Class.new(Jig).new(:beta, 1, :alpha)
  #   a.eql?(d)               # false
  #   a == d                  # false
  #   a =~ d                  # true
  #   a.to_s == d.to_s        # true

  # Returns true if the two jigs are instances of the same class and have 
  # equal gap lists and contents (via Array#eql?).
  # Jigs that are not equal may still have the same string representation.
  # Procs are not evaluated by Jig#eql?.
  def eql?(rhs)
    self.class == rhs.class &&
    contents.zip(rawgaps).flatten.eql?(rhs.contents.zip(rhs.rawgaps).flatten)
  end

  # Returns true if +rhs+ is an instance of Jig or one of Jig's subclasses and
  # the two jigs have equal gap lists and contents (via Array#==).
  # Procs are not evaluated by Jig#==.
  def ==(rhs)
    Jig === rhs &&
    contents.zip(rawgaps).flatten == rhs.contents.zip(rhs.rawgaps).flatten
  end

  # Returns true if the string representation of the jig matches the
  # +rhs+ using String#=~. Procs are evaluated by Jig#=~.
  #   Jig.new("chitchat") =~ Jig.new("chit", "chat")        # => true
  #   Jig.new("chitchat") =~ Jig.new("chit", :gap, "chat")  # => true
  #   Jig.new("chitchat") =~ /chit/                         # => true
  #   Jig.new(1,:a,2) =~ Jig.new(1, 2, :a)                  # => true
  def =~(rhs)
    if Regexp === rhs
      to_s =~ rhs
    else
      to_s == rhs.to_s
    end
  end

  # Returns true if the string representation of the jig matches the
  # +rhs.to_str+ using String#=~. Procs are evaluated by Jig#===.
  def ===(rhs)
    to_s =~ rhs.to_str
  end

  # :section: Reflection
  # This section describes methods that query the state of a jig.

  # The inspect string for a jig is an array of objects with gaps 
  # represented by symbols.  Gaps with associated filters are shown 
  # with trailing braces (:gap{}).
  #   Jig.new.inspect                                     # => #<Jig: [:___]>
  #   Jig.new(1,:a,2).inspect                             # => #<Jig: [1, :a, 2]>
  #   Jig.new(Gap.new(:example) { |x| x.to_s.reverse })  # => #<Jig: [:example{}]>
  def inspect
    info = rawgaps.map {|g| g.filter && "#{g.name}{}".to_sym || g.name }
    "#<Jig: #{contents.zip(info).flatten[0..-2].inspect}>"
  end

  # Returns true if the jig has no gaps.
  #   Jig.new.closed?            # false
  #   Jig.new('a').closed?       # true
  #   Jig.new.plug('a').closed?  # true
  def closed?
    rawgaps.empty?
  end

  # Returns true if the jig has any gaps.
  #   Jig.new.open?            # true
  #   Jig.new('a').open?       # false
  #   Jig.new.plug('a').open?  # false
  def open?
    not rawgaps.empty?
  end

  # Returns true if the jig has no gaps and renders as the empty string.
  # This method will cause proc objects within the jig to be evaluated.
  #   Jig.new.null?           # false
  #   Jig.new(nil).null?      # true
  #   Jig.new.plug("").null?  # true
  def null?
    closed? && to_s.empty?
  end

  # Returns an array containing the names, in order, of the gaps in
  # the current jig.  A name may occur more than once in the list.
  #   Jig.new.gaps                # => [:___]
  #   Jig.new(:a, :b).gaps        # => [:a, :b]
  #   Jig.new(:a, :b).plug.gaps   # => []
  def gaps
    rawgaps.map { |g| g.name }
  end

  # Returns true if the named gap appears in the jig.
  #   Jig.new.has_gap? :___       # => true
  #   Jig.new.plug.has_gap? :___  # => false
  def has_gap?(name)
    rawgaps.find {|g| g.name == name }
  end

  # Returns the position of the first gap with the given name 
  # or nil if a gap is not found.  See slice for a description 
  # of the indexing scheme for jigs.
  #   Jig.new.index(:___)         # => 1
  #   Jig.new.index(:a)           # => nil
  #   Jig.new(:a,:b).index(:b)    # => 3
  def index(name)
    rawgaps.each_with_index {|g,i| return (i*2)+1 if g.name == name }
    nil
  end

  # Returns self.
  #   j = Jig.new
  #   j.equal?(j.to_jig)          # => true
  def to_jig
    self
  end

  # :section: Operations
  # This section describes methods that perform operations on jigs,
  # usually resulting in a new jig instance.

  # call-seq:
  #   slice(position)   -> jig
  #   slice(range)      -> jig
  #   slice(start, len) -> jig
  #
  # Extracts parts of a jig.  The indexing scheme for jigs
  # accounts for contents and gaps as follows:
  #
  #        1    3       <- gaps
  #   +----+----+----+
  #   |    |    |    |
  #   +----+----+----+
  #     0    2    4     <- contents
  #
  # Each indexible element of the contents is itself a list
  # of zero or more objects. A jig with n gaps will always have
  # n + 1 content lists.
  #
  # When called with a single integer (pos), slice returns the
  # indexed item (a gap or a content list) as a jig.
  #
  #   j = Jig.new(0, :alpha, 'z')
  #   j.slice(0)                   # => #<Jig: [0]>
  #   j.slice(1)                   # => #<Jig: [:alpha]>
  #   j.slice(2)                   # => #<Jig: ['z']>
  #
  # When called with a range or a start position and length, 
  # slice extracts the indexed items and returns them as a new jig.
  #
  #   j = Jig.new(0, :alpha, 'z')
  #   j.slice(0..1)                # => #<Jig: [0, :alpha]>
  #   j.slice(1..2)                # => #<Jig: [:alpha, 'z']>
  #   j.slice(0,1)                 # => #<Jig: [0]>
  #   j.slice(0,2)                 # => #<Jig: [0, :alpha]>
  #
  # Negative array indices are respected:
  #
  #   j = Jig.new(0, :alpha, 'z')
  #   j.slice(-1)                  # => #<Jig: ['z']>
  #   j.slice(-2..-1)              # => #<Jig: [:alpha, 'z']>
  #   j.slice(-2, 1)               # => #<Jig: [:alpha]>
  def slice(index, len=1)
    if Range === index
      if index.exclude_end?
        first, last = index.begin, index.end - 1
      else
        first, last = index.begin, index.end 
      end
    else
      first, last = index, index + len - 1
    end

    # Adjust for negative indices.
    first = 2*contents.size + first - 1 if first < 0
    last = 2*contents.size + last - 1 if last < 0
    first_adjust, last_adjust = first % 2, last % 2

    j = Jig.new
    j.rawgaps = rawgaps[((first - first_adjust)/2)...((last + last_adjust)/2)]
    j.contents = contents[((first + first_adjust)/2)..((last - last_adjust)/2)]

    j.contents.unshift([]) if first_adjust.nonzero?
    j.contents.push([]) if last_adjust.nonzero?
    if !j.contents or !j.rawgaps
      raise ArgumentError, "index #{index} out of range"
    end
    j
  end
  alias [] :slice

  # call-seq:
  #   jig * count  -> a_jig
  #   jig * array  -> a_jig
  #
  # With an integer argument, a new jig is constructed by concatenating
  # _count_ copies of _self_.
  #   three = Jig.new * 3      # => Jig[:___, :___, :___]
  #   puts three.plug('3')     # => "333"
  #
  # With an array argument, the elements of the array are used to plug
  # the default gap. The resulting jigs are concatenated
  # to form the final result:
  #   require 'yaml'
  #   item = Jig["- ", :___, "\n"]    # => #<Jig: ["- ", :___, "\n"]>
  #   list = item * [1,2,3]           # => #<Jig: ["- ", 1, "\n", "- ", 2, "\n", "- ", 3, "\n"]>
  #   puts list                       # => "- 1\n- 2\n- 3\n"
  #   puts YAML.load(list.to_s)       # => [1, 2, 3]
  def mult(rhs)
    case rhs
    when Integer
      raise ArgumentError, "count must be greater than zero" if rhs < 1
      (1...rhs).inject(dup)  { |j,i| j.push(self) }
    when Array
      rhs.inject(Jig.null) { |j,x| j.concat( plug(x) ) }
    else
      raise ArgumentError, "rhs operand for * must be Integer or Array, was #{rhs.class})"
    end
  end
  alias * :mult

  # call-seq:
  #   plug                      -> a_jig
  #   plug { |gap| ... }        -> a_jig
  #   plug(hash)                -> a_jig
  #   plug(symbol, item, ...)   -> a_jig
  #   plug(item, ...)           -> a_jig
  #
  # Duplicates the current jig,  plugs one or more named gaps, and
  # returns the result. Plug silently ignores attempts to fill
  # undefined gaps.  In all cases, the replacement items are inserted
  # into the jig as during Jig construction (see Jig#new).
  #
  # If called with no arguments, any remaining gaps are plugged with nil.
  #
  # If called with a block, the name of each gap in the jig is passed to
  # the block and the gap is replaced with the return value of the block.
  #
  # If called with a hash, the keys are used as gap names and
  # the values are used to plug the respective gaps.  The gaps
  # are effectively plugged in parallel to avoid any ambiguity
  # when gaps are plugged with jigs that themselves contain
  # additional gaps.
  #
  # If called with a single symbol argument, the default gap is replaced
  # with a new gap named by the symbol.
  #
  # If two or more arguments are provided and the first argument is 
  # a symbol, the named gap is replaced with the list of items.
  #
  # In all other cases, the default gap is replaced with the list of
  # items.
  #
  #   j = Jig.new                 # => #<Jig: [:___]>
  #   jg = Jig[:gamma, :epsilon]  # => #<Jig: [:gamma, :epsilon]>
  #
  #   j.plug :alpha               # => #<Jig: [:alpha]>
  #   j.plug 1                    # => #<Jig: [1]>
  #   j.plug :alpha, 'a'          # => #<Jig: ['a']>
  #   jg.plug :gamma, ['a', 'b']  # => #<Jig: ['a', 'b', :epsilon]>
  #   jg.plug :gamma => 'a', 
  #           :epsilon => 'e'     # => #<Jig: ['a', 'e']>
  #   j.plug [1,2,3]              # => #<Jig: [1, 2, 3]>
  #   j.plug                      # => #<Jig: []>
  def plug(*args, &block)
    dup.plug!(*args, &block)
  end
  alias % :plug

  # call-seq:
  #   plugn(n, item)       -> a_jig
  #   plugn(range, array)  -> a_jig
  #   plugn(symbol, array) -> a_jig
  #   plugn(array)         -> a_jig
  #   plugn(hash)          -> a_jig
  #   plugn(item)          -> a_jig
  #
  # Similar to #plug but gaps are identified by an integer offset, not by name.
  # Unlike #index, and #slice, #plugn assumes that gaps are indexed 
  # consecutively starting with 0. 
  #
  # * When the first argument is an integer, +n+, the n-th gap
  #   is replaced with the item.
  # * When the first argument is a range, the gaps indexed by +range+
  #   are replaced with the items in +array+.
  # * When the only argument is an array, the gaps indexed by
  #   +0...array.size+ are replaced with the items in the array.
  # * When the only argument is a hash, the keys of the hash are taken
  #   as indices and the respective gaps are replaced with the associated
  #   values from the hash.
  # * Any other single argument is taken as the replacement for the first
  #   gap.
  #
  # Examples:
  #   list = Jig[:item, ',', :item, ',', :item]
  #   list.plugn(1, 'second')                           # => ",second,"
  #   list.plugn(1..2, %w{second third})                # => ",second,third"
  #   list.plugn('first')                               # => "first,,"
  #   list.plugn(%w{first second})                      # => "first,second,"
  #   list.plugn(0 => 'first', 2 => 'third')            # => "first,,third"
  def plugn(*args, &block)
    dup.plugn!(*args, &block)
  end

  # call-seq:
  #   before(symbol, item, ...)      -> a_jig
  #   before(item, ...)              -> a_jig
  #
  # Returns a new jig constructed by inserting the item *before* the specified gap
  # or the default gap if the first argument is not a symbol.
  # The gap itself remains in the new jig.
  #   Jig.new.before(1,2,3)           # => #<Jig: [1, 2, 3, :___]>
  #   Jig.new.before(:a, 1,2,3)       # => #<Jig: [:___]>
  #   Jig.new(:a, :b).before(:b, 1)   # => #<Jig: [:a, 1, :b]>
  def before(*args)
    dup.before!(*args)
  end

  # call-seq:
  #   after(symbol, item, ...)      -> a_jig
  #   after(item, ...)              -> a_jig
  #
  # A new jig is constructed by inserting the items *after* the specified gap
  # or the default gap if the first argument is not a symbol.
  # The gap itself remains in the new jig.
  #   Jig.new.after(1,2,3)           # => #<Jig: [:___, 1, 2, 3]>
  #   Jig.new.after(:a, 1,2,3)       # => #<Jig: [:___]>
  #   Jig.new(:a, :b).after(:a, 1)   # => #<Jig: [:a, 1, :b]>
  def after(*args)
    dup.after!(*args)
  end

  # call-seq:
  #   split(pattern=$;, [limit])
  #
  # With no arguments, the jig is split at the gap positions into an 
  # array of strings.  If arguments are provided, the jig is
  # rendered to a string by #to_s and the result of String#split (with the
  # arguments) is returned.
  def split(*args)
    if args.empty?
      contents.map { |c| c.join }
    else
      to_s.split(*args)
    end
  end

  # The contents of the jig are joined via Array#join.
  def join(sep=$,)
    contents.join(sep)
  end

  # Applies Kernel#freeze to the jig and its internal structures.  A frozen jig
  # may still be used with non-mutating methods such as #plug but an exception
  # will be raised if a mutating method such as #push or #plug! are called.
  def freeze
    super
    @contents.freeze
    @rawgaps.freeze
    self
  end

  # :section: Update
  # This section describes methods that modify the current jig.

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
  def push(*items)
    items.each do |i|
      case i
      when String   then 
        contents.last << i
      when Symbol   then 
        rawgaps << Gap.new(i)
        contents << []
      when Jig      then 
        push_jig i
      when NilClass, FalseClass then 
        next
      when Jig::Gap then 
        rawgaps << i
        contents << []
      else 
        if respond_to?(p = "push_#{i.class.name.downcase}")
          send(p, i)
        elsif i.respond_to? :to_jig
          push_jig i.to_jig
        elsif i.respond_to? :call
          (class <<i; self; end).class_eval {
            undef inspect
            #:stopdoc:
            alias inspect :to_s
            undef to_s
            def to_s; call.to_s; end
            #:startdoc:
          }
          contents.last << i
        else
          contents.last << i
        end
      end
      #contents.last.concat(add)
    end
    self
  end

  # The collection is converted to a list of items via <tt>*collection</tt>.
  # Resulting items are pushed onto the end of the current jig.
  #
  #   j = Jig.new 1
  #   j.concat([2,3])
  #   j == Jig[1,2,3]                # true
  #
  #   j.concat Jig[4,:alpha,5]
  #   j == Jig[1,2,3,4,:alpha,5]     # true
  #
  def concat(collection)
    push(*collection)
  end

  # call-seq:
  #   plug!                      -> a_jig
  #   plug! { |gap| ... }        -> a_jig
  #   plug!(hash)                -> a_jig
  #   plug!(symbol, *items)      -> a_jig
  #   plug!(*items)              -> a_jig
  #
  # Plugs one or more named gaps (see #plug) and returns self.  The current jig is
  # modified.  To construct a new jig use #plug instead.
  # If the named plug is not defined, the jig is not changed.
  def plug!(*args, &block)
    return fill!(&block) if block or args.empty?
    first, *more = args
    case first
    when Hash
      fill! { |g| first.fetch(g, g) }
    when Symbol 
      if more.empty?
        fill! { |g| g == GAP ? first : g }
      else
        fill! { |g| g == first ? (x = *more) : g }
      end
    else
      fill! { |g| g == GAP ? (x = *args) : g }
    end
  end
  alias []= :plug!
  alias << :plug!

  # Same as #plug but modifies self.
  def plugn!(first=nil, second=nil, &block)

    return filln!(&block) if block or !first

    case first
    when Hash
      filln!(*first.keys) { |i| first[i] }
    when Integer 
      #filln!(first => second)
      filln!(first) { second }
    when Array
      filln!(*(0...first.size)) { |index| first.fetch(index) }
    when Range 
      # pairs = first.inject({}) { |p, i| p[i] = second[i-first.begin]; p }
      filln!(*first) { |index| second && second.fetch(index-first.begin) }
    else
      filln!(0) { first }
    end
  end

  # call-seq:
  #   before!(symbol, item, ...)      -> a_jig
  #   before!(item, ...)              -> a_jig
  #
  # Like #before but modifies the current jig.
  def before!(*args)
    if Symbol === args.first
      gap = args.shift
    else
      gap = GAP
    end
    if current = rawgaps.find {|x| x.name == gap}
      plug!(gap, args.push(current))
    else
      self
    end
  end

  # call-seq:
  #   after!(symbol, item, ...)      -> a_jig
  #   after!(item, ...)              -> a_jig
  #
  # Like #after but modifies the current jig.
  def after!(*args)
    if Symbol === args.first
      gap = args.shift
    else
      gap = GAP
    end
    if current = rawgaps.find {|x| x.name == gap}
      plug!(gap, args.unshift(current))
    else
      self
    end
  end

  # A string is constructed by concatenating the contents of the jig.
  # Gaps are effectively considered null strings.  Any procs in the jig
  # are evaluated, the results converted to a string via to_s.  All
  # other objects are converted to strings via to_s.
  def to_s
    contents.flatten.join
  end
  alias to_str :to_s


  # Calls the block once for each gap in the jig passing the name of
  # the gap. If the block returns the gapname, the gap remains in the
  # jig, otherwise the gap is replaced with the return value of the block.
  # If called without a block, all the gaps are replaced with the empty
  # string.
  def fill!
    adjust = 0
    gaps.each_with_index do |gap, index|
      match = index + adjust
      items = block_given? && yield(gap)
      if items != gap
        fill = rawgaps.at(match).fill(items)
        adjust += plug_gap!(match, fill) - 1
      end
    end
    self
  end

  # Calls the block once for each index passing the index to the block.
  # The gap is replaced with the return value of the block.
  # If called without a block, the indexed gaps are replaced 
  # with the empty string.
  def filln!(*indices)
    # XXX need to handle indices that are too small
    adjust = 0
    normalized = indices.map { |x| (x >= 0) && x || (x+rawgaps.size) }.sort
    normalized.each do |index|
      match = index + adjust
      gap = rawgaps.fetch(match)
      items = block_given? && yield(index)
      fill = gap.fill(items)
      adjust += plug_gap!(match, fill) - 1
    end
    self
  end

  # :stopdoc:
  # This method alters the current jig by replacing a gap with a (possibly
  # empty) sequence of objects. The contents and rawgap arrays
  # are modified such that the named gap is removed and the sequence of
  # objects are put in the logical position of the former gap.
  #
  # Gaps and contents are maintainted in two separate arrays.  Each
  # element in the contents array is a list of objects implemented as
  # an array.  The first element of the gap array represents the
  # gap between the the first and second element of the contents array.
  #
  #      +----+----+
  #      |    |    |     <--- rawgaps array
  #      +----+----+
  #   +----+----+----+
  #   |    |    |    |   <--- contents array
  #   +----+----+----+
  #
  # The following relation always holds:  rawgaps.size == contents.size - 1
  # :startdoc:
  # Replaces the named gap in the current jig with _plug_ and returns the
  # number of gaps that were inserted in its place.
  def plug_gap!(gap, plug)
    case plug
    when String
      contents[gap,2] = [contents[gap] + [plug] + contents[gap+1]]
      rawgaps.delete_at(gap)
      return 0
    when nil, []
      contents[gap,2] = [contents[gap] + contents[gap+1]]
      rawgaps.delete_at(gap)
      return 0
    else
      plug = Jig[*plug] unless Jig === plug
      filling, gaps = plug.contents, plug.rawgaps
    end

    case filling.size
    when 0
      contents[gap,2] = [contents[gap] + contents[gap+1]]
    when 1
      contents[gap,2] = [contents[gap] + filling.first + contents[gap+1]]
    else
      contents[gap,2] = [contents[gap] + filling.first] + filling[1..-2] + [filling.last + contents[gap+1]]
    end
    rawgaps[gap, 1] = gaps
    gaps.size
  end


  # Append a jig onto the end of the current jig.
  def push_jig(other)
    self.contents = contents[0..-2] + [contents[-1] + other.contents[0]] + other.contents[1..-1]
    rawgaps.concat other.rawgaps
    self
  end

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
  alias append :+
end
