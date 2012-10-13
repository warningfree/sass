require 'sass/tree/node'

module Sass::Tree
  # A static node representing a Sass comment (silent or loud).
  #
  # @see Sass::Tree
  class CommentNode < Node
    # The text of the comment, not including `/*` and `*/`.
    #
    # @return [Sass::InterpString]
    attr_reader :value

    # The text of the comment
    # after any interpolated SassScript has been resolved.
    # Only set once \{Tree::Visitors::Perform} has been run.
    #
    # @return [String]
    attr_accessor :resolved_value

    # The type of the comment. `:silent` means it's never output to CSS,
    # `:normal` means it's output in every compile mode except `:compressed`,
    # and `:loud` means it's output even in `:compressed`.
    #
    # @return [Symbol]
    attr_accessor :type

    # @param value [Sass::InterpString] See \{#value}
    # @param type [Symbol] See \{#type}
    def initialize(value, type)
      @value = value.with_extracted_values {|str| normalize_indentation str}
      @type = type
      super()
    end

    # Compares the contents of two comments.
    #
    # @param other [Object] The object to compare with
    # @return [Boolean] Whether or not this node and the other object
    #   are the same
    def ==(other)
      self.class == other.class && value == other.value && type == other.type
    end

    # Returns `true` if this is a silent comment
    # or the current style doesn't render comments.
    #
    # Comments starting with ! are never invisible (and the ! is removed from the output.)
    #
    # @return [Boolean]
    def invisible?
      case @type
      when :loud; false
      when :silent; true
      else; style == :compressed
      end
    end

    # Returns the number of lines in the comment.
    #
    # @return [Fixnum]
    def lines
      @value.as_string.count("\n")
    end

    private

    def normalize_indentation(str)
      pre = str.split("\n").inject(str[/^[ \t]*/].split("")) do |pre, line|
        line[/^[ \t]*/].split("").zip(pre).inject([]) do |arr, (a, b)|
          break arr if a != b
          arr << a
        end
      end.join
      str.gsub(/^#{pre}/, '')
    end
  end
end
