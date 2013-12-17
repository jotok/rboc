# rboc

The rboc gem is a ruby interface to the data API provided by the U.S. Census Bureau (the "boc" in rboc stands for Bureau of the Census).

Roadmap:
* 1.0: A lightweight rubyish wrapper around the Census API. The user has to explicity specify variable and FIPS codes.
* 1.2: Add functionality to let the user search for codes using regexes or strings.
* 2.0: Add (smart) geographic objects and table-level data requests, as in the acs package for R.

Code examples:

    result = Census.acs(year: 2011) do |q|
      q.variables = ['B00001_001E', 'B00001_001M']
      q.geo.summary_level = 'tract'
      q.geo.contained_in = { 'state' => 11 }
      q.api_key = 'xxx'
    end
    
    result = Census.acs(year: 2011) do |q|
      q.get('B00001_001E', 'B00001_001M').for('tract').in('state' => 11).key('xxx')
    end
    
Notes:
* Currently will fail hard if (geo) columns and rows of data aren't returned in a consistent order from the API.
