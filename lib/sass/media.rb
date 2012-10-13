# A namespace for the `@media` query parse tree.
module Sass::Media
  # A comma-separated list of queries.
  #
  #   media_query [ ',' S* media_query ]*
  class QueryList
    # The queries contained in this list.
    #
    # @return [Array<Query>]
    attr_accessor :queries

    # @param queries [Array<Query>] See \{#queries}
    def initialize(queries)
      @queries = queries
    end

    # Merges this query list with another. The returned query list
    # queries for the intersection between the two inputs.
    #
    # Both query lists should be resolved.
    #
    # @param other [QueryList]
    # @return [QueryList?] The merged list, or nil if there is no intersection.
    def merge(other)
      new_queries = queries.map {|q1| other.queries.map {|q2| q1.merge(q2)}}.flatten.compact
      return if new_queries.empty?
      QueryList.new(new_queries)
    end

    # Returns the CSS for the media query list.
    #
    # @return [String]
    def to_css
      queries.map {|q| q.to_css}.join(', ')
    end

    # Returns the Sass/SCSS code for the media query list.
    #
    # @param options [{Symbol => Object}] An options hash (see {Sass::CSS#initialize}).
    # @return [String]
    def to_src(options)
      queries.map {|q| q.to_src(options)}.join(', ')
    end

    # Returns a representation of the query as an array of strings and
    # potentially {Sass::Script::Node}s (if there's interpolation in it). When
    # the interpolation is resolved and the strings are joined together, this
    # will be the string representation of this query.
    #
    # @return [Sass::InterpString]
    def to_interp_str
      Sass::InterpString.new(Sass::Util.intersperse(queries.map {|q| q.to_interp_str}, ', '))
    end

    # Returns a deep copy of this query list and all its children.
    #
    # @return [QueryList]
    def deep_copy
      QueryList.new(queries.map {|q| q.deep_copy})
    end
  end

  # A single media query.
  #
  #   [ [ONLY | NOT]? S* media_type S* | expression ] [ AND S* expression ]*
  class Query
    # The modifier for the query.
    #
    # When parsed as Sass code, this contains strings and SassScript nodes. When
    # parsed as CSS, it contains a single string (accessible via
    # \{#resolved_modifier}).
    #
    # @return [Sass::InterpString]
    attr_accessor :modifier

    # The type of the query (e.g. `"screen"` or `"print"`).
    #
    # When parsed as Sass code, this contains strings and SassScript nodes. When
    # parsed as CSS, it contains a single string (accessible via
    # \{#resolved_type}).
    #
    # @return [Sass::InterpString]
    attr_accessor :type

    # The trailing expressions in the query.
    #
    # When parsed as Sass code, each expression contains strings and SassScript
    # nodes. When parsed as CSS, each one contains a single string.
    #
    # @return [Array<Sass::InterpString>]
    attr_accessor :expressions

    # @param modifier [Sass::InterpString] See \{#modifier}
    # @param type [Sass::InterpString] See \{#type}
    # @param expressions [Array<Sass::InterpString>] See \{#expressions}
    def initialize(modifier, type, expressions)
      @modifier = modifier
      @type = type
      @expressions = expressions
    end

    # See \{#modifier}.
    # @return [String]
    def resolved_modifier
      # modifier should contain only a single string
      modifier.to_s
    end

    # See \{#type}.
    # @return [String]
    def resolved_type
      # type should contain only a single string
      type.to_s
    end

    # Merges this query with another. The returned query queries for
    # the intersection between the two inputs.
    #
    # Both queries should be resolved.
    #
    # @param other [Query]
    # @return [Query?] The merged query, or nil if there is no intersection.
    def merge(other)
      m1, t1 = resolved_modifier.downcase, resolved_type.downcase
      m2, t2 = other.resolved_modifier.downcase, other.resolved_type.downcase
      t1 = t2 if t1.empty?
      t2 = t1 if t2.empty?
      if ((m1 == 'not') ^ (m2 == 'not'))
        return if t1 == t2
        type = m1 == 'not' ? t2 : t1
        mod = m1 == 'not' ? m2 : m1
      elsif m1 == 'not' && m2 == 'not'
        # CSS has no way of representing "neither screen nor print"
        return unless t1 == t2
        type = t1
        mod = 'not'
      elsif t1 != t2
        return
      else # t1 == t2, neither m1 nor m2 are "not"
        type = t1
        mod = m1.empty? ? m2 : m1
      end
      q = Query.new(Sass::InterpString.new, Sass::InterpString.new, other.expressions + expressions)
      q.type = Sass::InterpString.new(type)
      q.modifier = Sass::InterpString.new(mod)
      return q
    end

    # Returns the CSS for the media query.
    #
    # @return [String]
    def to_css
      css = ''
      css << resolved_modifier
      css << ' ' unless resolved_modifier.empty?
      css << resolved_type
      css << ' and ' unless resolved_type.empty? || expressions.empty?
      css << expressions.map do |e|
        # It's possible for there to be script nodes in Expressions even when
        # we're converting to CSS in the case where we parsed the document as
        # CSS originally (as in css_test.rb).
        e.map {|c| c.is_a?(Sass::Script::Node) ? c.to_sass : c.to_s}.join
      end.join(' and ')
      css
    end

    # Returns the Sass/SCSS code for the media query.
    #
    # @param options [{Symbol => Object}] An options hash (see {Sass::CSS#initialize}).
    # @return [String]
    def to_src(options)
      src = ''
      src << modifier.to_src(options)
      src << ' ' unless modifier.empty?
      src << type.to_src(options)
      src << ' and ' unless type.empty? || expressions.empty?
      src << expressions.map {|e| e.to_src(options)}.join(' and ')
      src
    end

    # @see \{MediaQuery#to\_interp\_str}
    def to_interp_str
      res = Sass::InterpString.new
      res << modifier
      res << ' ' unless modifier.empty?
      res << type
      res << ' and ' unless type.empty? || expressions.empty?
      res << Sass::InterpString.new(Sass::Util.intersperse(expressions, ' and '))
      res
    end

    # Returns a deep copy of this query and all its children.
    #
    # @return [Query]
    def deep_copy
      Query.new(modifier.deep_copy, type.deep_copy, expressions.map {|e| e.deep_copy})
    end
  end
end
