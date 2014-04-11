require 'curb'
require 'json'

module Census

  # Create one DataSetVintage object per data set description in the discovery API.
  #
  class DataSetVintage

    # a map from API json variables to member variables
    #
    MEMBER_VARS = {
      :vintage => 'c_vintage',
      :dataset => 'c_dataset',
      :geography_link => 'c_geographyLink',
      :variables_link => 'c_variablesLink',
      :is_aggregate => 'c_isAggregate',
      :title => 'title',
      :web_service => 'webService',
      :access_level => 'accessLevel',
      :contact_point => 'contactPoint',
      :description => 'description',
      :identifier => 'identifier',
      :mbox => 'mbox',
      :publisher => 'publisher',
      :references => 'references',
      :spatial => 'spatial',
      :temporal => 'temporal'
    }

    MEMBER_VARS.each {|var, _| attr_reader var}

    def initialize(json)
      MEMBER_VARS.each do |var, key|
        v = ('@' + var.to_s).to_sym
        self.instance_variable_set v, json[key]
      end

      # 'vintage' should be an int
      @vintage = @vintage.to_i
    end

    # Accesses the data api and returns the unmodified body of the HTTP response.  Raises errors
    # if the HTTP response code indicates a problem.
    #
    def query_raw(q=Query.new)
      yield q if block_given?

      url = self.web_service + '?' + q.to_s
      puts "GET #{url}"

      c = Curl::Easy.new url
      c.perform
      r = c.response_code

      if r == 200
        return c.body_str
      elsif r == 400
        raise InvalidQueryError
      elsif r == 204
        raise NoMatchingRecordsError
      elsif r == 500
        raise ServerSideError
      elsif r == 302 && (c.head.include?("missing_key") || c.head.include?("invalid_key"))
        raise InvalidKeyError
      else
        raise CensusApiError, "Unexpected HTTP response code: #{r}"
      end
    end

    # Accesses the the data api and parses the result into a Census::Data object.
    #
    def query(q=Query.new)
      yield q if block_given?

      # download the first 50 or fewer variables
      json = self.query_raw q[0...50]
      rs = ResultSet.new json

      # download remaining variables 50 at a time
      offset = 50
      while offset <= q.variables.length
        json = self.api_raw year, file, q[offset...(offset+50)]
        json = JSON.parse json

        # sometimes the API returns a descriptive hash (in a single element array) if the
        # requested columns are invalid
        raise InvalidQueryError if json.first.is_a? Hash

        rs.merge! json
        offset += 50
      end

      rs
    end
  end

  # A simple container object that proxies its query method to an underlying
  # DataSetVintage object.
  #
  class DataSet
    def initialize
      @vintages = {}
      @newest_vintage = 0
    end

    def add_vintage(v)
      y = v.vintage
      @vintages[y] = v
      @newest_vintage = y if y > @newest_vintage
    end

    def vintage_years
      @vintages.keys
    end

    def [](vintage)
      unless @vintages.keys.include? vintage
        raise ArgumentError, "Unknown vintage"
      end
      @vintages[vintage.to_i]
    end

    def query_raw(q=Query.new)
      yield q if block_given?
      @vintages[@newest_vintage].query_raw q
    end

    def query(q=Query.new)
      yield q if block_given?
      @vintages[@newest_vintage].query q
    end

  end

  # A result data set
  #
  class ResultSet

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
      @rows.each do |row|
        yield Hash[@colnames.zip row]
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

    def ==(other)
      other.is_a?(ResultSet) && self.colnames == other.colnames && self.rows == other.rows
    end

  end
end
