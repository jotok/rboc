module Census

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

    attr_accessor :summary_level, :contained_in

    def initialize
      @summary_level = {}
      @contained_in = {}
    end

    # Sets the summary level to the specified value. If 'lvl' is a hash, it should
    # only contain one element.
    #
    def summary_level=(lvl)

      if lvl.is_a? Hash
        k, v = lvl.first
        k = LEVEL_ALIAS[k] if LEVEL_ALIAS[k] 
        @summary_level[k] = v
      else
        k = LEVEL_ALIAS[lvl] || lvl
        @summary_level[k] = '*'
      end
    end

    def to_hash
      h = {}
      @summary_level['us'] = '*' if @summary_level.empty?

      k, v = @summary_level.first
      h['for'] = "#{k}:#{v}"

      unless @contained_in.empty?
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

end
