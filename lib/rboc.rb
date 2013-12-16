require 'curb'
require 'json'
require 'nokogiri'

# A module defining methods for accessing the U.S. Census data API.
#
module Census

  API_URL = 'http://api.census.gov/data'

  ACS_YEARS = [2010, 2011, 2012]
  ACS_PERIODS = [1, 3, 5]
  ACS_DEFAULT_YEAR = 2012
  ACS_DEFAULT_PERIOD = 5

  INSTALLED_KEY_REL_PATH = '../data/installed_key'
  INSTALLED_KEY_PATH = File.join(File.dirname(File.expand_path(__FILE__)), INSTALLED_KEY_REL_PATH)

  # A result data set
  #
  class Data

    include Enumerable

    attr_reader :colnames, :rows

    def initialize(json='')
      if json.empty?
        @colnames = []
        @rows = []
      else
        o = JSON.parse json
        @colnames, *@rows = *o
      end
    end

    def each
      @rows.each do |row|
        yield Hash[@colnames.zip row]
      end
    end

    def merge!(json)
      o = JSON.parse json
      colnames, *rows = *o

      @colnames += colnames
      @rows.map!.with_index do |row, i|
        row += rows[i]
      end
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

    # Returns the geography portion of the API GET string.
    #
    def to_s
      k, v = @summary_level.first
      s = "for=#{k}:#{v}"

      unless @contained_in.nil? || @contained_in.empty?
        s += "&in=" + @contained_in.map {|k, v| "#{k}:#{v}"}.join("+")
      end

      s
    end
  end

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

    # Returns the query portion of the API GET string.
    #
    def to_s
      v = @variables
      v = v.join(',') if v.is_a? Array

      "get=#{v}&#{geo.to_s}&key=#{self.api_key}"
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

    # Accesses the data api for the ACS and returns the unmodified body of the HTTP response. 
    # If a block is given, it will be called on the query argument.
    #
    def acs_raw(query: Query.new, year: ACS_DEFAULT_YEAR, period: ACS_DEFAULT_PERIOD)
      unless ACS_YEARS.include? year
        raise ArgumentError, "Invalid year: #{year}"
      end

      unless ACS_PERIODS.include? period
        raise ArgumentError, "Invalid period: #{period}"
      end

      yield query if block_given?

      url = [API_URL, year, "acs#{period}", query.to_s].join('/')

      # TODO do something with the response code
      # c = Curl.get url
      # c.body_str
    end
    
    # Accesses the the data api for the ACS and parses the result into a Census::Data object.
    # If a block is given, it will be called on the query argument.
    #
    def acs(query: Query.new, year: ACS_DEFAULT_YEAR, period: ACS_DEFAULT_PERIOD)
      yield query if block_given?

      # download 50 variables at a time
      d = Data.new
      offset = 0
      while 50 * offset <= query.variables.length
        json = acs_raw(query: query[offset...(offset+50)], year: year, period: period)
        d.merge! json
      end

      d
    end

  end
end

