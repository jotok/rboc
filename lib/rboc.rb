require 'curb'
require 'json'
require 'uri'
require 'set'

require 'rboc/census'
require 'rboc/geo'
require 'rboc/data'

# A module defining methods for accessing the U.S. Census data API.
#
# Census data is divided between a number of files, like the American Community Survey
# (ACS) 5 year estimates file, the ACS 3 year estimates file, and the 2010 Census
# summary file. See the {data documentation}[http://www.census.gov/developers/data/] on
# the Census website for a description of all available files.
#
# In +rboc+, the list of available files (using abbreviated names) is contained in
# +Census::DATA_SETS+.  Each entry in that array corresponds to a class constant in
# +Census+ assigned to a +Census::DataSet+ instance. A DataSet object contains one or
# more DataSetVintage objects which represent particular vintage for the given survey.
# Use the DataSet#vintage_years method to see the vintage years available.
#
#     Census::ACS5.vintage_years
#     # => [2010, 2011, 2012]
#
# To access a particular data set vintage, use square brackets.
#
#     Census::ACS5[2010].class
#     # => Census::DataSetVintage
#
# To download data, use the +query+ method on a DataSet or DataSetVintage object.
# Calling #query on the containing DataSet is the same as calling #query on the most
# recent vintage year. 
#
#     Census::ACS5.query(q=Census::Query.new) {|q| ...}
#     # returns data for most recent vintage year
#     Census::ACS5[2010].query(q=Census::Query.new) {|q| ...}
#     # returns data for 2010 vintage year
#
# If a block is passed it is called on the Census::Query argument. Queries return
# Census::ResultSet. For each file there is also a "raw" query method with the same
# signature:
#
#     Census::ACS5.query_raw(q=Census::Query.new) {|q| ...}
#
# The raw version returns the unmodified response string, which gives the requested
# data in JSON format. Note, however, that +#query_raw+ will raise an error if you try to
# download more than 50 variables (this is a restriction of the Census API).  #query
# will break your request into chunks and merge them into a single response object.
#
# Examples:
#
#     # In the following examples I assume the user has installed a key locally, so a
#     key is not # specified in query parameters.
#
#     # Create a query to request the total population for each county in Iowa.
#     require 'rboc'
#     my_q = Census::Query.new
#     my_q.variables = ['B00001_001E'] # this needs to be an array
#     my_q.geo.summary_level = 'county'
#     my_q.geo.contained_in = { 'state' => 19 }
#
#     # Pass the query to an appropriate Census file, examine the returned column names, and 
#     # iterate over the results.
#     result = Census::ACS5.query my_q
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
#     result2 = Census::ACS5.query do |q|
#       q.variables = ['B00001_001E']
#       q.geo.summary_level = 'county'
#       q.geo.contained_in = { 'state' => 19 }
#     end
#     result2 == result
#     # => true
#
#     # There is a second, chainable syntax for defining query parameters that
#     # is convenient for one-liners.
#     result3 = Census::ACS5.query {|q| q.get('B00001_001E').for('county').in('state' => 19)}
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

  # Where cached responses from the Census API. Only data descriptions are stored.
  #
  CACHE_DIR = File.join LOCAL_DATA_DIR, 'cache'

  # Path to the installed API key.
  #
  INSTALLED_KEY_PATH = File.join LOCAL_DATA_DIR, 'installed_key'

  # Data discoverable API URL
  #
  DATA_DISCOVERY_URL = 'http://api.census.gov/data.json'

  self.setup_local_directory!
  data_sets = JSON.parse self.get_cached_url(DATA_DISCOVERY_URL)

  # extract unique file names and valid years
  data_names = Set.new
  data_sets.each do |d|
    name = d['c_dataset'].join('_').upcase

    if data_names.include? name
      self.const_get(name).add_vintage DataSetVintage.new(d)
    else
      data_names << name
      ds = DataSet.new
      ds.add_vintage DataSetVintage.new(d)
      self.const_set name, ds
    end
  end

  DATA_SETS = data_names.sort
end
