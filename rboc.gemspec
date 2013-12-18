Gem::Specification.new do |s|
  s.name        = 'rboc'
  s.version     = '1.0.1-alpha'
  s.date        = '2013-12-16'
  s.summary     = 'An interface to the API provided by the U.S. Census Bureau'
  s.description = s.summary
  s.authors     = ['Joshua Tokle']
  s.email       = 'jtokle@gmail.com'
  s.files       = ['lib/rboc.rb',
                   'lib/rboc/geo.rb',
                   'lib/rboc/data.rb',
                   'data/acs_1yr_profile_2012.xml'
                  ]
  s.homepage    = "http://github.com/jotok/rboc"
  s.license     = 'Public Domain'

  s.add_runtime_dependency 'curb', '~> 0.8.5'
  s.add_runtime_dependency 'json', '~> 1.8.1'
end
