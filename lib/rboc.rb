require 'curb'
require 'json'
require 'uri'

require 'rboc/census'
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

  # Where to store local data
  #
  LOCAL_DATA_DIR = File.join ENV['HOME'], '.census'

  # Path to the installed API key.
  #
  INSTALLED_KEY_PATH = File.join LOCAL_DATA_DIR, 'installed_key'

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

  FILES.each do |f| 
    self.api_call f, FILE_URL_SUBST[f]
  end

  unless Dir.exists? LOCAL_DATA_DIR
    Dir.mkdir LOCAL_DATA_DIR
  end

  cache_dir = File.join LOCAL_DATA_DIR, 'cache'
  unless Dir.exists? cache_dir
    Dir.mkdir cache_dir
  end

end
