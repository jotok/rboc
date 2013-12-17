require 'curb'
require 'json'
require 'uri'

require 'rboc/geo'
require 'rboc/data'

# A module defining methods for accessing the U.S. Census data API.
#
module Census

  # Base URL of the Census data API.
  #
  API_URL = 'http://api.census.gov/data'

  # Path to the installed API key relative to this file.
  #
  INSTALLED_KEY_REL_PATH = '../data/installed_key'

  # Path to the installed API key.
  #
  INSTALLED_KEY_PATH = File.join(File.dirname(File.expand_path(__FILE__)), INSTALLED_KEY_REL_PATH)

  # Data files accessible through the Census API.
  #
  FILES = ['acs1', 'acs1_cd', 'acs3', 'acs5', 'sf1', 'sf3']

  # List valid years of data for each data file.
  #
  FILE_VALID_YEARS = {
    'acs1'    => [2012],
    'acs1_cd' => [2011],
    'acs3'    => [2012],
    'acs5'    => [2011, 2010],
    'sf1'     => [2010, 2000, 1990],
    'sf3'     => [2000, 1990]
  }

  FILE_URL_SUBST = {
    'acs1' => 'acs1/profile',
    'acs3' => 'acs3/profile'
  }

  class CensusApiError < StandardError; end
  class InvalidQueryError < CensusApiError; end
  class NoMatchingRecordsError < CensusApiError; end
  class ServerSideError < CensusApiError; end

  # A class representing a query to the Census API.
  #
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

    # Constructs the URL needed to perform the query on the given file.
    #
    def api_url(year, file, url_file, query)
      year = year.to_i
      unless FILE_VALID_YEARS[file].include? year
        raise ArgumentError, "Invalid year '#{year}' for file '#{file}'"
      end

      url_file ||= file
      yield query if block_given?
      [API_URL, year.to_s,  "#{url_file}?#{query.to_s}"].join('/')
    end

    # Accesses the data api and returns the unmodified body of the HTTP response.  Raises errors
    # if the HTTP response code indicates a problem.
    #
    def api_raw(year, file, url_file, query)
      url = api_url year, file, url_file, query
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

    # Accesses the the data api and parses the result into a Census::Data object.
    #
    def api_data(year, file, url_file, query)
      yield query if block_given?

      # download the first 50 or fewer variables
      json = api_raw year, file, url_file, query[0...50]
      d = Data.new json

      # download remaining variables 50 at a time
      offset = 50
      while offset <= query.variables.length
        json = api_raw year, file, url_file, query[offset...(offset+50)]
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

  def self.api_call(file, url_file)

    define_singleton_method file do |year: FILE_VALID_YEARS[file].first, query: Query.new, &block|
      # api_data year, file, url_file, &block
      api_url year, file, url_file, query, &block
    end

    define_singleton_method(file+'_raw') do |year: FILE_VALID_YEARS[file], query: Query.new, &block|
      # api_raw year, file, url_file, &block
      api_url year, file, url_file, query, &block
    end
  end

  FILES.each do |f| 
    self.api_call f, FILE_URL_SUBST[f]
  end

end
