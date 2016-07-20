class CSVDiff

    # Represents a CSV input (i.e. the left/from or right/to input) to the diff
    # process.
    class CSVSource

        # @return [String] the path to the source file
        attr_accessor :path

        # @return [Array<String>] The names of the fields in the source file
        attr_reader :field_names
        # @return [Array<String>] The names of the field(s) that uniquely
        #   identify each row.
        attr_reader :key_fields
        # @return [Array<String>] The names of the field(s) that identify a
        #   common parent of child records.
        attr_reader :parent_fields
        # @return [Array<String>] The names of the field(s) that distinguish a
        #   child of a parent record.
        attr_reader :child_fields

        # @return [Array<Fixnum>] The indexes of the key fields in the source
        #   file.
        attr_reader :key_field_indexes
        # @return [Array<Fixnum>] The indexes of the parent fields in the source
        #   file.
        attr_reader :parent_field_indexes
        # @return [Array<Fixnum>] The indexes of the child fields in the source
        #   file.
        attr_reader :child_field_indexes

        # @return [Boolean] True if the source has been indexed with case-
        #   sensitive keys, or false if it has been indexed using upper-case key
        #   values.
        attr_reader :case_sensitive
        alias_method :case_sensitive?, :case_sensitive
        # @return [Boolean] True if leading/trailing whitespace should be stripped
        #   from fields
        attr_reader :trim_whitespace
        # @return [Hash<String,Hash>] A hash containing each line of the source,
        #   keyed on the values of the +key_fields+.
        attr_reader :lines
        # @return [Hash<String,Array<String>>] A hash containing each parent key,
        #   and an Array of the child keys it is a parent of.
        attr_reader :index
        # @return [Array<String>] An array of any warnings encountered while
        #   processing the source.
        attr_reader :warnings


        # Creates a new diff source.
        #
        # A diff source must contain at least one field that will be used as the
        # key to identify the same record in a different version of this file.
        # If not specified via one of the options, the first field is assumed to
        # be the unique key.
        #
        # If multiple fields combine to form a unique key, the parent is assumed
        # to be identified by all but the last field of the unique key. If finer
        # control is required, use a combination of the :parent_fields and
        # :child_fields options.
        #
        # All key options can be specified either by field name, or by field
        # index (0 based).
        #
        # @param source [String|Array<Array>] Either a path to a CSV file, or an
        #   Array of Arrays containing CSV data. If the :field_names option is
        #   not specified, the first line must contain the names of the fields.
        # @param options [Hash] An options hash.
        # @option options [String] :encoding The encoding to use when opening the
        #   CSV file.
        # @option options [Hash] :csv_options Any options you wish to pass to
        #   CSV.open, e.g. :col_sep.
        # @option options [Array<String>] :field_names The names of each of the
        #   fields in +source+.
        # @option options [Boolean] :ignore_header If true, and :field_names has
        #   been specified, then the first row of the file is ignored.
        # @option options [String] :key_field The name of the field that uniquely
        #   identifies each row.
        # @option options [Array<String>] :key_fields The names of the fields
        #   that uniquely identifies each row.
        # @option options [String] :parent_field The name of the field(s) that
        #   identify a parent within which sibling order should be checked.
        # @option options [String] :child_field The name of the field(s) that
        #   uniquely identify a child of a parent.
        # @option options [Boolean] :case_sensitive If true (the default), keys
        #  are indexed as-is; if false, the index is built in upper-case for
        #  case-insensitive comparisons.
        def initialize(source, options = {})
            if source.is_a?(String)
                require 'ccsv'
                mode_string = options[:encoding] ? "r:#{options[:encoding]}" : 'r'
                csv_options = options.fetch(:csv_options, {})
                @path = source
                source = []
                Ccsv.foreach(@path) {|l| source << l}
            end
            if kf = options.fetch(:key_field, options[:key_fields])
                @key_fields = [kf].flatten
                @parent_fields = @key_fields[0...-1]
                @child_fields = @key_fields[-1..-1]
            else
                @parent_fields = [options.fetch(:parent_field, options[:parent_fields]) || []].flatten
                @child_fields = [options.fetch(:child_field, options[:child_fields]) || [0]].flatten
                @key_fields = @parent_fields + @child_fields
            end
            @field_names = options[:field_names]
            @warnings = []
            index_source(source, options)
        end


        # Returns the row in the CSV source corresponding to the supplied key.
        #
        # @param key [String] The unique key to use to lookup the row.
        # @return [Hash] The fields for the line corresponding to +key+, or nil
        #   if the key is not recognised.
        def [](key)
            @lines[key]
        end


        private

        # Given an array of lines, where each line is an array of fields, indexes
        # the array contents so that it can be looked up by key.
        def index_source(lines, options)
            @lines = {}
            @index = Hash.new{ |h, k| h[k] = [] }
            if @field_names
                index_fields
            end
            @case_sensitive = options.fetch(:case_sensitive, true)
            @trim_whitespace = options.fetch(:trim_whitespace, false)
            line_num = 0
            lines.each do |row|
                line_num += 1
                next if line_num == 1 && @field_names && options[:ignore_header]
                unless @field_names
                    @field_names = row
                    index_fields
                    next
                end
                field_vals = row
                line = {}
                @field_names.each_with_index do |field, i|
                    line[field] = field_vals[i]
                    line[field].strip! if @trim_whitespace && line[field]
                end
                key_values = @key_field_indexes.map{ |kf| field_vals[kf].to_s.upcase }
                key = key_values.join('~')
                parent_key = key_values[0...(@parent_fields.length)].join('~')
                parent_key.upcase! unless @case_sensitive
                if @lines[key]
                    @warnings << "Duplicate key '#{key}' encountered and ignored at line #{line_num}"
                else
                    @index[parent_key] << key
                    @lines[key] = line
                end
            end
        end


        def index_fields
            @key_field_indexes = find_field_indexes(@key_fields, @field_names)
            @parent_field_indexes = find_field_indexes(@parent_fields, @field_names)
            @child_field_indexes = find_field_indexes(@child_fields, @field_names)
            @key_fields = @key_field_indexes.map{ |i| @field_names[i] }
            @parent_fields = @parent_field_indexes.map{ |i| @field_names[i] }
            @child_fields = @child_field_indexes.map{ |i| @field_names[i] }
        end


        # Converts an array of field names to an array of indexes of the fields
        # matching those names.
        def find_field_indexes(key_fields, field_names)
            key_fields.map do |field|
                if field.is_a?(Fixnum)
                    field
                else
                    field_names.index{ |field_name| field.to_s.downcase == field_name.downcase } or
                        raise ArgumentError, "Could not locate field '#{field}' in source field names: #{
                            field_names.join(', ')}"
                end
            end
        end

    end

end

