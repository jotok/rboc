PROJECT = 'rboc'
GEMSPEC_FILE = "#{PROJECT}.gemspec"

GEMSPEC = eval File.read(GEMSPEC_FILE)

task :default => [:build, :install]

task :build do |t|
  sh "gem build #{GEMSPEC_FILE}"
end

task :install do |t|
  sh "gem install #{PROJECT}-#{GEMSPEC.version}.gem"
end
