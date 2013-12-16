require 'curb'
require 'json'
require 'nokogiri'

class Census

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

    def contained_in=(hsh)
      @contained_in = hsh
    end

    # Returns the geography portio of the API GET string.
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

    # Returns the API key to be used for this query.
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

    def to_s
      v = @variables
      if v.is_a? Array
        v = v.join(',')
      end

      "get=#{v}&#{geo.to_s}&key=#{self.api_key}"
    end
  end

  class <<self

    def install_key!(key)
      File.open INSTALLED_KEY_PATH, 'w' do |f|
        f.write key
      end
    end

    def acs_raw(query: Query.new, year: ACS_DEFAULT_YEAR, period: ACS_DEFAULT_PERIOD)
      unless ACS_YEARS.include? year
        raise ArgumentError, "Invalid year: #{year}"
      end

      unless ACS_PERIODS.include? period
        raise ArgumentError, "Invalid period: #{period}"
      end

      if block_given?
        yield query
      end

      url = [API_URL, year, "acs#{period}", query.to_s].join('/')

      # c = Curl.get query.to_s
      # c.body_str
    end
    
    def acs(query: Query.new, year: ACS_DEFAULT_YEAR, period: ACS_DEFAULT_PERIOD, &block)
      json = acs_raw(query: query, year: year, period: period, &block)
    end

  end
end

