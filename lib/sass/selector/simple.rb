module Sass
  module Selector
    # The abstract superclass for simple selectors
    # (that is, those that don't compose multiple selectors).
    class Simple
      # The line of the Sass template on which this selector was declared.
      #
      # @return [Fixnum]
      attr_accessor :line

      # The name of the file in which this selector was declared,
      # or `nil` if it was not declared in a file (e.g. on stdin).
      #
      # @return [String, nil]
      attr_accessor :filename

      # Returns a representation of the node
      # as an array of strings and potentially {Sass::Script::Node}s
      # (if there's interpolation in the selector).
      # When the interpolation is resolved and the strings are joined together,
      # this will be the string representation of this node.
      #
      # @return [Sass::InterpString]
      def to_interp_str
        Sass::Util.abstract(self)
      end

      # Returns a string representation of the node.
      # This is basically the selector string.
      #
      # @return [String]
      def inspect
        to_interp_str.to_src
      end

      # @see \{#inspect}
      # @return [String]
      def to_s
        inspect
      end

      # Returns a hash code for this selector object.
      #
      # By default, this is based on the value of \{#to\_interp\_str},
      # so if that contains information irrelevant to the identity of the selector,
      # this should be overridden.
      #
      # @return [Fixnum]
      def hash
        @_hash ||= to_interp_str.hash
      end

      # Checks equality between this and another object.
      #
      # By default, this is based on the value of \{#to\_interp\_str},
      # so if that contains information irrelevant to the identity of the selector,
      # this should be overridden.
      #
      # @param other [Object] The object to test equality against
      # @return [Boolean] Whether or not this is equal to `other`
      def eql?(other)
        other.class == self.class && other.hash == self.hash &&
          other.to_interp_str.eql?(to_interp_str)
      end
      alias_method :==, :eql?

      # Unifies this selector with a {SimpleSequence}'s {SimpleSequence#members members array},
      # returning another `SimpleSequence` members array
      # that matches both this selector and the input selector.
      #
      # By default, this just appends this selector to the end of the array
      # (or returns the original array if this selector already exists in it).
      #
      # @param sels [Array<Simple>] A {SimpleSequence}'s {SimpleSequence#members members array}
      # @return [Array<Simple>, nil] A {SimpleSequence} {SimpleSequence#members members array}
      #   matching both `sels` and this selector,
      #   or `nil` if this is impossible (e.g. unifying `#foo` and `#bar`)
      # @raise [Sass::SyntaxError] If this selector cannot be unified.
      #   This will only ever occur when a dynamic selector,
      #   such as {Parent} or {Interpolation}, is used in unification.
      #   Since these selectors should be resolved
      #   by the time extension and unification happen,
      #   this exception will only ever be raised as a result of programmer error
      def unify(sels)
        return sels if sels.any? {|sel2| eql?(sel2)}
        sels_with_ix = Sass::Util.enum_with_index(sels)
        _, i =
          if self.is_a?(Pseudo) || self.is_a?(SelectorPseudoClass)
            sels_with_ix.find {|sel, _| sel.is_a?(Pseudo) && (sels.last.final? || sels.last.type == :element)}
          else
            sels_with_ix.find {|sel, _| sel.is_a?(Pseudo) || sel.is_a?(SelectorPseudoClass)}
          end
        return sels + [self] unless i
        return sels[0...i] + [self] + sels[i..-1]
      end

      protected

      # Unifies two namespaces,
      # returning a namespace that works for both of them if possible.
      #
      # @param ns1 [Sass::InterpString, nil] The first namespace.
      #   `nil` means none specified, e.g. `foo`.
      #   The empty string means no namespace specified, e.g. `|foo`.
      #   `"*"` means any namespace is allowed, e.g. `*|foo`.
      # @param ns2 [Sass::InterpString, nil] The second namespace. See `ns1`.
      # @return [Array(Sass::InterpString or nil, Boolean)]
      #   The first value is the unified namespace, or `nil` for no namespace.
      #   The second value is whether or not a namespace that works for both inputs
      #   could be found at all.
      #   If the second value is `false`, the first should be ignored.
      def unify_namespaces(ns1, ns2)
        return ns2, true if ns1 == Sass::InterpString.new('*')
        return ns1, true if ns2 == Sass::InterpString.new('*')
        return nil, false unless ns1 == ns2 || ns1.nil? || ns2.nil?
        return ns1 || ns2, true
      end
    end
  end
end
