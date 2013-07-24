#!/usr/bin/env ruby
require 'rvm'

# This script will create a fully-working gov.uk-style setup locally

organisation = 'theodi'

projects     = {
  signonotron2:      'signon',
  static:            'static',
  panopticon:        'panopticon',
  publisher:         'publisher',
  content_api:       'contentapi',
  frontend:          'www',
}

def colour text, colour
  "\x1b[%sm%s\x1b[0m" % [
    colour,
    text
  ]
end

def red text
  colour text, "31"
end

def green text
  colour text, "32"
end
  
puts green "We're going to grab all the actual applications we need."

pwd = `pwd`.strip

projects.each_pair do |project, servername|

  if not Dir.exists? project.to_s

    puts "%s %s" % [
      green("Cloning"),
      red(project)
    ]

    system "git clone git@github.com:#{organisation}/#{project}.git"
    system "rvm in #{project} do bundle"
  end    
end

exit

system "ln -sf #{pwd}/frontend ~/.pow/private-frontend"

puts "\x1B[32m"
puts "Now we need to generate application tokens in the signonotron."
puts "\x1B[0m"

def oauth_id(output)
  output.match(/config.oauth_id     = '(.*?)'/)[1]
end

def oauth_secret(output)
  output.match(/config.oauth_secret = '(.*?)'/)[1]
end

Dir.chdir("signonotron2") do
  RVM.use! '.'

  puts "\x1B[32m"
  puts "Setting up signonotron database..."
  puts "\x1B[0m"

  system "mysqladmin -u root create signonotron2_development"
  system "mysql -u root < ../db_setup.sql"

  system "rake db:schema:load"
  
  puts "\x1B[32m"
  puts "Make signonotron work in dev mode..."
  puts "\x1B[0m"

  system "bundle exec ./script/make_oauth_work_in_dev"
  
  puts "\x1B[32m"
  puts "Generating application keys for \x1B[31mpublisher\x1B[0m"
  puts "\x1B[0m"

  str = `rake applications:create name=Publisher description="Content editing" home_uri="http://publisher.dev" redirect_uri="http://publisher.dev/auth/gds/callback"`
  File.open('../publisher/.powenv', 'a') do |f|
    f << "export PUBLISHER_OAUTH_ID=#{oauth_id(str)}\n"
    f << "export PUBLISHER_OAUTH_SECRET=#{oauth_secret(str)}\n"
  end
  
  puts "\x1B[32m"
  puts "Generating application keys for \x1B[31mpanopticon\x1B[0m"
  puts "\x1B[0m"

  str = `rake applications:create name=Panopticon description="Metadata management" home_uri="http://panopticon.dev" redirect_uri="http://panopticon.dev/auth/gds/callback"`
  File.open('../panopticon/.powenv', 'a') do |f|
    f << "export PANOPTICON_OAUTH_ID=#{oauth_id(str)}\n"
    f << "export PANOPTICON_OAUTH_SECRET=#{oauth_secret(str)}\n"
  end
  
  puts "\x1B[32m"
  puts "We'll generate a couple of sample users for you. You can add more by doing something like:"
  puts "\x1B[31m"
  puts "$ cd signonotron2"
  puts "$ rvm use .."
  puts "$ bundle exec rake users:create name='Alice' email=alice@example.com applications=Publisher,Panopticon"
  puts "\x1B[0m"

  system "GOVUK_APP_DOMAIN=dev DEV_DOMAIN=dev bundle exec rake users:create name='Alice' email=alice@example.com applications=Publisher,Panopticon"
  system "GOVUK_APP_DOMAIN=dev DEV_DOMAIN=dev bundle exec rake users:create name='Bob' email=bob@example.com applications=Publisher,Panopticon"

end

