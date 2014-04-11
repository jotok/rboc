Gem::Specification.new do |s|
  s.name        = 'rboc'
  s.version     = '1.1.0'
  s.date        = '2014-04-11'
  s.summary     = 'An interface to the API provided by the U.S. Census Bureau'
  s.description = s.summary
  s.authors     = ['Joshua Tokle']
  s.email       = 'jtokle@gmail.com'
  s.files       = ['lib/rboc.rb',
                   'lib/rboc/census.rb',
                   'lib/rboc/geo.rb',
                   'lib/rboc/data.rb',
                  ]
  s.homepage    = "http://github.com/jotok/rboc"
  s.license     = 'Public Domain'

  s.add_runtime_dependency 'curb', '~> 0.8'
  s.add_runtime_dependency 'json', '~> 1.8'
end
