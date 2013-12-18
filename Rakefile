PROJECT = 'rboc'
GEMSPEC_FILE = "#{PROJECT}.gemspec"
API_KEY_FILE = 'data/installed_key'

f = File.open GEMSPEC_FILE
GEMSPEC = eval f.read
f.close

task :default => [:build, :install]

task :build do |t|
  sh "gem build #{GEMSPEC_FILE}"
end

task :install do |t|
  sh "gem install #{PROJECT}-#{GEMSPEC.version}.gem"
  
  if File.exists? API_KEY_FILE
    puts "installing API key"
    require 'rboc'
    File.open(API_KEY_FILE) {|f| Census.install_key! f.read}
  end
end
