require 'json'

module Census

  # A result data set
  #
  class Data

    # Split a list of column names into geographic columns and data columns
    def self.split_colnames(colnames)
      geocolnames = []
      datacolnames = []
      colnames.each do |s|
        if Geography::LEVELS.include? s
          geocolnames << s
        else
          datacolnames << s
        end
      end

      [geocolnames, datacolnames]
    end

    include Enumerable

    attr_reader :colnames, :rows

    # Constructs a new data object from Census data returned by the API. The format of JSON
    # should be:
    #     [["column1", "column2", ...], [row11, row12, ...], [row21, row22, ...], ...]
    #
    def initialize(json='[]')
      json = JSON.parse json if json.is_a? String
      @colnames, *@rows = *json
      @colmap = Hash[@colnames.zip (0..@colnames.length)]

      @geocolnames, @datacolnames = self.class.split_colnames colnames
    end

    def each
      Enumerator.new do |y|
        @rows.each do |row|
          y << Hash[@colnames.zip row]
        end
      end
    end

    # Merges an existing Census data set with additional data returned from the API. Currently,
    # this method assumes columns and rows are returned in a consistent order given the same
    # geography.
    #
    def merge!(json)
      json = JSON.parse json if json.is_a? String
      colnames, *rows = *json
      colmap = Hash[colnames.zip (0..colnames.length)]
      geocolnames, datacolnames = self.class.split_colnames colnames

      if geocolnames != @geocolnames
        raise ArgumentError, "Mismatched geographies"
      end

      @rows.map!.with_index do |row, i|
        if  @geocolnames.any? {|s| row[@colmap[s]] != rows[i][colmap[s]]}
          raise ArgumentError, "Mismatched rows"
        end

        row += datacolnames.map {|s| rows[i][colmap[s]]}
      end

      n = @colnames.length
      @colmap.merge! Hash[datacolnames.zip (n..(n+datacolnames.length))]
      @colnames += datacolnames
      @datacolnames += datacolnames

      self
    end

  end
end
