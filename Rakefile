PROJECT = 'rboc'
GEMSPEC_FILE = "#{PROJECT}.gemspec"
API_KEY_FILE = 'data/installed_key'

GEMSPEC = eval File.read(GEMSPEC_FILE)

task :default => [:build, :install]

task :build do |t|
  sh "gem build #{GEMSPEC_FILE}"
end

task :install do |t|
  sh "gem install #{PROJECT}-#{GEMSPEC.version}.gem"
  
  if File.exists? API_KEY_FILE
    print 'installing API key... '
    require 'rboc'
    Census.install_key! File.read(API_KEY_FILE)
    puts 'ok'
  end
end
