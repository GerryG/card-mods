# CsvFile loads csv data from a given path or file handle and provides methods
# to iterate over the data.
class Card
  class CsvFile
    # @param headers [true, false, :detect] (false) if true the import raises an error
    #    if the csv file has no or wrong headers
    def initialize path_or_file, item_class, col_sep: ",", encoding: "utf-8", headers: true
      raise ArgumentError, "no row class given" unless item_class.is_a?(Class)
      raise ArgumentError, "#{item_class} must inherit from ImportItem" unless item_class < ImportItem
      @item_class = item_class
      @col_sep = col_sep
      @encoding = encoding
      @headers = headers

      read_csv path_or_file
      @rows.shift if @headers
    end

    # yields the rows of the csv file as ImportItem objects
    def each_row import_manager=nil, rows=nil
      each_row_hash rows do |row_hash, index|
        yield @item_class.new(row_hash, index, import_manager: import_manager)
      end
    end

    # yields the rows of the csv file as simple hashes
    def each_row_hash rows=nil, &block
      if rows
        selected_rows rows, &block
      else
        all_rows &block
      end
    end

    def row_count
      @rows.size
    end

    def row_hash index
      row_to_hash @rows[index]
    end

    def selected_rows rows
      rows.each do |index|
        yield row_hash(index), index
      end
    end

    private

    def read_csv path_or_file
      @rows =
        if path_or_file.respond_to?(:read)
          read_csv_from_file_handle path_or_file
        else
          read_csv_from_path path_or_file
        end
    end

    def read_csv_from_path path
      raise StandardError, "file does not exist: #{path}" unless File.exist? path
      rescue_encoding_error do
        CSV.read path, csv_options
      end
    end

    def read_csv_from_file_handle file
      CSV.parse to_utf_8(file.read, force: true), csv_options
      # CSV.parse file.read, csv_options
    end

    def rescue_encoding_error
      yield
    rescue ArgumentError => _e
      # if parsing with utf-8 encoding fails, assume it's iso-8859-1 encoding
      # and convert to utf-8
      with_encoding "iso-8859-1:utf-8" do
        yield
      end
    end

    def to_utf_8 str, encoding: "utf-8", force: false
      if force
        str.force_encoding encoding
      else
        str.encode encoding
      end
    rescue Encoding::UndefinedConversionError => _e
      # If parsing with utf-8 encoding fails, assume it's iso-8859-1 encoding
      # and convert to utf-8.
      # If that failed to force it to iso-8859-1 before converting it.
      to_utf_8 str, encoding: "iso-8859-1", force: (encoding == "iso-8859-1")
    end

    def csv_options
      { col_sep: @col_sep, encoding: @encoding }
    end

    def with_encoding encoding
      enc = @encoding
      @encoding = encoding
      yield
    ensure
      @encoding = enc
    end

    def all_rows
      @rows.each.with_index do |row, i|
        next if row.compact.empty?
        yield row_to_hash(row), i
      end
    end

    # def map_headers
    #   @col_map = {}
    #   headers = @rows.shift.map { |h| h.to_name.key.to_sym }
    #   @item_class.columns.each do |key|
    #     @col_map[key] = headers.index key
    #     raise StandardError, "column #{key} is missing" unless @col_map[key]
    #   end
    # end
  #
    # def header_row?
    #   return unless first_row = @rows.first.map { |h| h.to_name.key.to_sym }
    #   @item_class.columns.all? do |item|
    #     first_row.include? item
    #   end
    # end

    def row_to_hash row
      @item_class.column_keys.each_with_object({}).with_index do |(k, h), i|
        h[k] = row[i]
        h[k] &&= h[k].strip
      end
    end

    # def initialize_column_map header_line
    #   if (header_line == :detect && header_row?) || header_line == true
    #     map_headers
    #   else
    #     @col_map = @item_class.columns.zip((0..@item_class.columns.size)).to_h
    #   end
    # end
  end
end