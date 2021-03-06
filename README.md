# rboc: A ruby interace to the U.S. Census Bureau data API

## Quick Start

*This is in-progress work and I'm likely to push API-breaking changes until at least version 1.2. If you've stumbled upon this gem in the meantime and you'd like to start using it, feel free to contact me so I can warn you before breakage.*

For each Census data file (e.g., acs5, sf1) there is a corresponding class constant in Census (e.g. `Census::ACS5`, `Census::SF1`). These methods take block arguments that can be used to specify your data request. For example, the API call

    http://api.census.gov/data/2011/acs5?key=xxx&for=county:*&in=state:19&get=B00001_001E

(which requests the 5-year average population estimate at the county level for all counties in Iowa) is equivalent to the `rboc` method call

    Census::ACS5.query {|q| q.get('B00001_001E').for('counties').in('state' => 19).key('xxx')}

To specify the vintage year of data that you're looking for, use square brackets:

    Census::ACS5[2010].query {|q| q.get('B00001_001E').for('counties').in('state' => 19).key('xxx')}

The most recent vintage year is used by default.

You can "install" your API key (i.e., save it to a file in your home directory) by calling

    Census.install_key! 'xxx'

Subsequent `rboc` queries will use your installed key unless another key is specified.

Currently, you have to know the variable and geography codes that you're interested in. `rboc` will not help you.

## Deliberate Start

The `rboc` gem is a ruby interface to the data API provided by the U.S. Census Bureau (the "boc" in `rboc` stands for Bureau of the Census). It provides a rubyish wrapper around the HTTP/GET interface and performs some basic validation on the request and response. If you're new to the Census API, then you may want to browse the [developer documentation](http://www.census.gov/developers/) and the [data documentation](http://www.census.gov/developers/data/) on the Census website. Before accessing the API you will need to [request a key](http://www.census.gov/developers/tos/key_request.html).

Census data is divided between a number of files, like the American Community Survey (ACS) 5 year estimates file, the ACS 3 year estimates file, and the 2010 Census summary file. A complete list of files is found in the data documentation. A list of file abbreviations is given by `Census::DATA_SETS`. For each abbreviation there is a corresponding class constant in the `Census` module which is used to access the file data. Using the "acs5" file as an example:

    Census::ACS5.query(q=Census::Query.new) {|q| ...}

All arguments are optional (although you'll probably get an `InvalidQueryError` if you don't specify any query parameters). Calling `query` directly on the data set returns the most recent vintage year of data. To obtain a different vintage year of data, pass the desired year in square brackets:

    Census::ACS5[2010].query(q=Census::Query.new) {|q| ...}

If a block is provided, then it's called on the query argument. In practice, you'll probably either provide a query or a block:

    my_q = Census::Query.new
    my_q.geo.summary_level = 'state'
    my_q.variables = ['B00001_001E'] # this should be an array
    result1 = Census::ACS5.query my_q

    result2 = Census::ACS5.query {|q| q.get('B00001_001E').for('state')}

This example also demonstrates two ways to set query parameters. You can either assign directly to the query's instance variables, or you can use a chainable syntax that mirrors the parameters to the Census API.

The data returned by `query` is a `Census::ResultSet` object.

    result = Census::ACS5.query {|q| q.get('B00001_001E').for('state')}
    result.colnames
    # => ["B00001_001E", "state"]

    # result.each returns each row as a hash using column names as keys
    result.each {|row| p row}
    # {"B00001_001E" => "372109", "state" => "01"}
    # {"B00001_001E" => "72384", "state" => "02}
    # ... approximately 50 states

    # you can also iterate over rows without column names
    result.rows.each {|row| p row}
    # ["372109", "01"]
    # ["72384", "02"]
    # ...

You can also issue a "raw" query which returns the Census API call as an unmodified string.

    result = Census::ACS5.query_raw {|q| q.get('B00001_001E').for('state')}
    # => "[[\"B00001_001E\",\"state\"],\n[\"372109\",\"01\"], ..."

Note that the Census API only allows you to request 50 or fewer variables at a time. `query_raw` will raise an error if you request more than 50 variables. However, `query` will split the request into chunks and merge the response into a single `Census::ResultSet` object.

I hope this gets you started hacking with Census data. Please contact me with bug reports and suggestions.

## Future Work

* 1.2: Add functionality to let the user search for codes using regexes or strings.
* 2.0: Add (smart) geographic objects and table-level data requests, as in the acs package for R.

## Notes

* Currently will fail hard if (geo) columns and rows of data aren't returned in a consistent order from the API.
