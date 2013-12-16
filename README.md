# rboc

The rboc gem is a ruby interface to the data API provided by the U.S. Census Bureau (the "boc" in rboc stands for Bureau of the Census).

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
    
