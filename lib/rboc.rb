require 'curb'
require 'json'
require 'nokogiri'
require 'uri'

# A module defining methods for accessing the U.S. Census data API.
#
module Census

  API_URL = 'http://api.census.gov/data/'

  ACS_YEARS = [2010, 2011, 2012]
  ACS_PERIODS = [1, 3, 5]

  INSTALLED_KEY_REL_PATH = '../data/installed_key'
  INSTALLED_KEY_PATH = File.join(File.dirname(File.expand_path(__FILE__)), INSTALLED_KEY_REL_PATH)

  # A result data set
  #
  class Data

    include Enumerable

    attr_reader :colnames, :rows

    # Constructs a new data object from Census data returned by the API. The format of JSON
    # should be:
    #     [["column1", "column2", ...], [row11, row12, ...], [row21, row22, ...], ...]
    #
    def initialize(json='[]')
      json = JSON.parse json if json.is_a? String
      @colnames, *@rows = *json
    end

    def each
      @rows.each do |row|
        yield Hash[@colnames.zip row]
      end
    end

    def merge!(json)
      json = JSON.parse json if json.is_a? String
      colnames, *rows = *json

      if @colnames.empty?
        @rows = rows.clone
      else
        @rows.map!.with_index do |row, i|
          row += rows[i]
        end
      end

      @colnames += colnames
    end

  end

  # A Census geography
  #
  class Geography
    LEVELS = [
      'us', 'region', 'division', 'state', 'county', 'tract'
    ]

    LEVEL_ALIAS = {
      'regions' => 'region',
      'divisions' => 'division',
      'states' => 'state',
      'counties' => 'county',
      'tracts' => 'tract',
    }

    # Sets the summary level to the specified value. If 'lvl' is a hash, it should
    # only contain one element.
    #
    def summary_level=(lvl)
      @summary_level = {}

      if lvl.is_a? Hash
        k, v = lvl.first
        k = LEVEL_ALIAS[k] if LEVEL_ALIAS[k] 
        @summary_level[k] = v
      else
        k = LEVEL_ALIAS[lvl] || lvl
        @summary_level[k] = '*'
      end
    end

    # The summary level is understood relative to this geography.
    #
    def contained_in=(hsh)
      @contained_in = hsh
    end

    def to_hash
      h = {}

      k, v = @summary_level.first
      h['for'] = "#{k}:#{v}"

      unless @contained_in.nil? || @contained_in.empty?
        h['in'] = @contained_in.map {|k, v| "#{k}:#{v}"}.join("+")
      end

      h
    end

    # Returns the geography portion of the API GET string.
    #
    def to_s
      URI.encode_www_form self.to_hash
    end
  end

  class CensusApiError < StandardError; end
  class InvalidQueryError < CensusApiError; end
  class NoMatchingRecordsError < CensusApiError; end
  class ServerSideError < CensusApiError; end

  class Query
    attr_accessor :variables, :geo

    def initialize
      @variables = []
      @geo = Geography.new
    end

    def api_key=(key)
      @api_key = key
    end

    # Returns the API key to be used for this query. If the key hasn't been set explicitly, this
    # method attempts to load a key previously installed by Census#install_key!.
    #
    def api_key
      unless @api_key
        if File.exist? INSTALLED_KEY_PATH
          File.open(INSTALLED_KEY_PATH) do |f|
            @api_key = f.read
          end
        end
      end

      @api_key
    end

    # these chainable methods mirror the field names in the HTTP get string

    def get(*vars)
      @variables = vars
      self
    end

    def for(level)
      @geo.summary_level = level
      self
    end

    def in(container)
      @geo.contained_in = container
      self
    end

    def key(key)
      @api_key = key
      self
    end

    # Constructs a new Query object with a subset of variables. Creates a shallow copy of this
    # Query's geography and api key.
    #
    def [](rng)
      variables = @variables[rng]
      q = Query.new
      q.variables = variables
      q.geo = @geo
      q.api_key = @api_key
      q
    end

    def to_hash
      h = {}
      h['key'] = self.api_key
      h.merge! geo.to_hash

      v = @variables
      v = v.join(',') if v.is_a? Array
      h['get'] = v

      h
    end

    # Returns the query portion of the API GET string.
    #
    def to_s
      URI.encode_www_form self.to_hash
    end
  end

  class <<self

    # Writes the given key to a local file. If a key is installed, then you don't have to specify
    # a key in your query.
    #
    def install_key!(key)
      File.open INSTALLED_KEY_PATH, 'w' do |f|
        f.write key
      end
    end

    def api_url(year, file, query=Query.new)
      yield query if block_given?

      url = URI.join API_URL, year.to_s, "#{file}?#{query.to_s}"
      url.to_s
    end

    # Accesses the data api for the ACS and returns the unmodified body of the HTTP response. 
    # If a block is given, it will be called on the query argument.
    #
    def acs_raw(year, period, query=Query.new)
      unless ACS_YEARS.include? year
        raise ArgumentError, "Invalid year: #{year}"
      end

      unless ACS_PERIODS.include? period
        raise ArgumentError, "Invalid period: #{period}"
      end

      yield query if block_given?

      url = api_url year, "acs#{period}", query
      puts "GET #{url}"

      c = Curl::Easy.new url
      c.perform

      case c.response_code
      when 400
        raise InvalidQueryError
      when 204
        raise NoMatchingRecordsError
      when 500
        raise ServerSideError
      else
        c.body_str
      end
    end
    
    # Accesses the the data api for the ACS and parses the result into a Census::Data object.
    # If a block is given, it will be called on the query argument.
    #
    def acs(year, period, query=Query.new)
      yield query if block_given?

      # download the first 50 or fewer variables
      json = acs_raw year, period, query[0...50]
      d = Data.new json

      # download remaining variables 50 at a time
      offset = 50
      while offset <= query.variables.length
        json = acs_raw year, period, query[offset...(offset+50)]
        json = JSON.parse json

        # sometimes the API returns a descriptive hash (in a single element array) if the
        # requested columns are invalid
        raise InvalidQueryError if json.first.is_a? Hash

        d.merge! json
        offset += 50
      end

      d
    end

  end
end

