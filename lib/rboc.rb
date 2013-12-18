require 'curb'
require 'json'
require 'uri'

require 'rboc/geo'
require 'rboc/data'

# A module defining methods for accessing the U.S. Census data API.
#
# Census data is divided between a number of files, like the American Community Survey (ACS) 5 year
# estimates file, the ACS 3 year estimates file, and the 2010 Census summary file. See the {data
# documentation}[http://www.census.gov/developers/data/] on the Census website for a description of
# all available files.
#
# In +rboc+, the list of available files (using abbreviated names) is contained in +Census::FILES+.
# For each entry in that array, there is a corresponding class method in +Census+ that you can use
# to query the file. These methods all have the same signature:
#
#     Census.acs5(year: y, query: q) {|q| ...}
#
# I'm using +acs5+ as an example, but any file name in +Census::FILES+ would work. +year+ should be
# an integer argument indicating the reference year of the data you're requesting. Valid years of
# data are given in +Census::FILE_VALID_YEARS+, the default value is the most recent year of data.
# +query+ should be a +Census::Query+ object. If a block is given, then it will be called on
# +query+.
#
# The Census API methods return a +Census::Data+ object which can be used to iterate over the
# result. For each file there is also a "raw" method with the same signature:
#
#     Census.acs5_raw(year: y, query: q) {|q| ...}
#
# The raw version returns the unmodified response string, which gives the requested data in JSON
# format. Note, however, that +Census.acs5_raw+ will raise an error if you try to download more than
# 50 variables (this is a restriction of the Census API). `Census.acs5` will break your request into
# chunks and merge them into a single response object.
#
# Examples:
#
#     # In the following examples I assume the user has installed a key locally, so a key is not
#     # specified in query parameters.
#
#     # Create a query to request the total population for each county in Iowa.
#     my_q = Census::Query.new
#     my_q.variables = ['B00001_001E'] # this needs to be an array
#     my_q.geo.summary_level = 'county'
#     my_q.geo.contained_in = { 'state' => 19 }
#
#     # Pass the query to an appropriate Census file, examine the returned column names, and 
#     # iterate over the results.
#     result = Census.acs5(query: my_q)
#     result.colnames
#     # => ["B00001_001E", "state", "county"]
#     result.each {|row| p row}
#     # {"B00001_001E" => "1461", "state" => "19", "county" => "001"}
#     # {"B00001_001E" => "823", "state" => "19", "county" => "003"}
#     # ...
#
#     # You can also iterate over rows without column names
#     result.rows.each {|row| p row}
#     # ["1461", "19", "001"]
#     # ["823", "19", "003"]
#     # ...
#
#     # You can use a block to set query parameters.
#     result2 = Census.acs5 do |q|
#       q.variables = ['B00001_001E']
#       q.geo.summary_level = 'county'
#       q.geo.contained_in = { 'state' => 19 }
#     end
#     result2 == result
#     # => true
#
#     # There is a second, chainable syntax for defining query parameters that is convenient for 
#     # one-liners.
#     result3 = Census.acs5 {|q| q.get('B00001_001E').for('county').in('state' => 19)}
#     result3 = result
#     # => true
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
    'acs5'    => [2012, 2011, 2010],
    'sf1'     => [2010, 2000, 1990],
    'sf3'     => [2000, 1990]
  }

  FILE_URL_SUBST = {
    'acs1' => 'acs1/profile',
    'acs3' => 'acs3/profile'
  }

  class CensusApiError < StandardError; end
  class InvalidQueryError < CensusApiError; end
  class InvalidKeyError < CensusApiError; end
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
      @api_key ||= Census.installed_key
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

    # Returns the currently installed key or +nil+ if no key is installed.
    #
    def installed_key
      if File.exists? INSTALLED_KEY_PATH
        File.read INSTALLED_KEY_PATH
      else
        nil
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
      yield query if block_given?
      url = api_url year, file, url_file, query
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
      api_data year, file, url_file, query, &block
    end

    define_singleton_method(file+'_raw') do |year: FILE_VALID_YEARS[file].first, query: Query.new, &block|
      api_raw year, file, url_file, query, &block
    end
  end

  FILES.each do |f| 
    self.api_call f, FILE_URL_SUBST[f]
  end

end
