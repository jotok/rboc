# rboc

The `rboc` gem is a ruby interface to the data API provided by the U.S. Census Bureau (the "boc" in `rboc` stands for Bureau of the Census). Currently, this gem provides minimal wrapper around the HTTP/GET interface. For example, you can access the most recent 5-year population estimates given by the American Communities Survey (ACS) by requesting the URL:

    http://api.census.gov/data/2011/acs5?key=xxx&for=county:*&in=state:19&get=B00001_001E

Here, "xxx" is a stand-in for your API key. The `rboc` syntax for this request is

    result = Census.acs5 do |q|
      q.variables = ['B00001_001E']
      q.geo.summary_level = 'county'
      q.geo.contained_in = { 'state' => 19 }
      q.api_key = 'xxx'
    end

or, more succinctly,

    result = Census.acs5 {|q| q.get('B00001_001E').for('counties').in('state' => 19).key('xxx')}

Note that the user needs to know the variable and geographic codes that they are interested in.

## Install your API key

Rather than supply your API key for every query, you can install your key by calling

    Census.install_key! 'xxx'

This saves the key in a file in the gem's installation directory. In subsequent queries, the installed key will be used if no key is explicitly specified. Because the key is saved to the gem's directory, it will have to be reinstalled after the gem is upgraded.

## Future Work

* 1.2: Add functionality to let the user search for codes using regexes or strings.
* 2.0: Add (smart) geographic objects and table-level data requests, as in the acs package for R.

## Notes

* Currently will fail hard if (geo) columns and rows of data aren't returned in a consistent order from the API.
