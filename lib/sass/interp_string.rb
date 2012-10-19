module Sass
  class InterpString
    # @return [Array<String, Sass::Script::Node>]
    attr_reader :contents

    # @return [Sass::Source::Range]
    attr_accessor :source_range

    def initialize(contents=[])
      raise "ERROR: nil is not allowed in InterpString." if contents.nil?
      contents = [contents] unless contents.is_a?(Array)
      @contents = Sass::Util.merge_adjacent_strings(contents.map do |c|
          next c.contents if c.is_a?(InterpString)
          next c
        end.flatten)
    end

    def options=(options)
      @contents.each {|c| c.options = options if c.is_a?(Sass::Script::Node)}
    end

    def empty?
      @contents.all? {|c| c.is_a?(String) && c.empty?}
    end

    def strip!
      @contents[0] = @contents[0].lstrip if @contents.first.is_a?(String)
      @contents[-1] = @contents[-1].rstrip if @contents.last.is_a?(String)
      self
    end

    def hash
      @contents.hash
    end

    def eql?(other)
      @contents.eql?(other.contents)
    end

    def ==(other)
      other.is_a?(InterpString) && @contents == other.contents
    end

    def +(other)
      if other.is_a?(InterpString)
        InterpString.new(@contents + other.contents)
      else
        InterpString.new(@contents + [other])
      end
    end

    def prepend(element)
      if element.is_a?(InterpString)
        @contents = element.contents + @contents
      elsif element.is_a?(String) && @contents.first.is_a?(String)
        @contents[0] = element + @contents.first
      else
        @contents.unshift element
      end
    end

    def <<(element)
      if element.is_a?(InterpString)
        @contents.concat element.contents
      elsif element.is_a?(String) && @contents.last.is_a?(String)
        @contents[-1] = @contents.last + element
      else
        @contents << element
      end
      self
    end

    def to_s
      return @contents.join unless dynamic?
      raise "ERROR: InterpString#to_s requires a static string, was #{inspect}"
    end

    def inspect
      to_src.inspect
    end

    def dynamic?
      @contents.any? {|c| !c.is_a?(String)}
    end

    def run(environment)
      @contents.map do |e|
        next e if e.is_a?(String)
        val = e.perform(environment)
        # Interpolated strings should never render with quotes
        next val.value if val.is_a?(Sass::Script::String)
        val.to_s
      end.join
    end

    def to_src(options={})
      @contents.map do |e|
        next e if e.is_a?(String)
        "\#{#{e.to_sass(options)}}"
      end.join
    end

    def deep_copy
      InterpString.new(@contents.map {|c| c.is_a?(Sass::Script::Node) ? c.deep_copy : c})
    end

    def as_string
      @contents.select {|e| e.is_a?(String)}.join
    end

    def with_extracted_values(&block)
      InterpString.new(Sass::Util.with_extracted_values(@contents, &block))
    end
  end
end
