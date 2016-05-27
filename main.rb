require_relative './lib/internet_monitor.rb'

internet_monitor = InternetMonitor.new(
  # tests connection every 5 secs once gone offline
  connectivity_check_delay: 5,

  # checks connection against google
  connection_check_host: 'www.google.com',

  # tests connection speed every 10 minutes
  speed_measuring_delay: 60 * 10
)

puts '(Press <enter> to stop)'
if internet_monitor.start_monitoring
  gets
  internet_monitor.stop_monitoring
else
  'Something went wrong. Please contact support :p'
end
