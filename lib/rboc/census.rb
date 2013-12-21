module Census
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

    # Set up the local directory where cached data and the installed key will be stored.
    def setup_local_directory
      unless Dir.exists? LOCAL_DATA_DIR
        Dir.mkdir LOCAL_DATA_DIR
      end

      unless Dir.exists? CACHE_DIR
        Dir.mkdir CACHE_DIR
      end

    end

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

    # Looks for the url basename in the cache directory. If it doesn't exist, then downloads the
    # file from the web.
    #
    def get_cached_url(url)
      local_file = File.join CACHE_DIR, File.basename(url)
      if File.exists? local_file
        File.read local_file
      else
        puts "Getting #{url}"
        c = Curl::Easy.new url
        c.perform
        file_content = c.body_str
        
        File.open local_file, 'w' do |f|
          f.write file_content
        end

        file_content
      end
    end

    # Constructs the URL needed to perform the query on the given file.
    #
    def api_url(year, file, query)
      year = year.to_i
      unless FILE_VALID_YEARS[file].include? year
        raise ArgumentError, "Invalid year '#{year}' for file '#{file}'"
      end

      yield query if block_given?
      [API_URL, year.to_s,  "#{file}?#{query.to_s}"].join('/')
    end

    # Accesses the data api and returns the unmodified body of the HTTP response.  Raises errors
    # if the HTTP response code indicates a problem.
    #
    def api_raw(year, file, query)
      yield query if block_given?
      url = api_url year, file, query
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
    def api_data(year, file, query)
      yield query if block_given?

      # download the first 50 or fewer variables
      json = api_raw year, file, query[0...50]
      d = Data.new json

      # download remaining variables 50 at a time
      offset = 50
      while offset <= query.variables.length
        json = api_raw year, file, query[offset...(offset+50)]
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

  def self.api_call(file)

    define_singleton_method file do |year: FILE_VALID_YEARS[file].first, query: Query.new, &block|
      api_data year, file, query, &block
    end

    define_singleton_method(file+'_raw') do |year: FILE_VALID_YEARS[file].first, query: Query.new, &block|
      api_raw year, file, query, &block
    end
  end

end
