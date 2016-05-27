require_relative './internet_monitor_logger.rb'

require 'aasm'
require 'speedtest'
require 'net/ping/http'

# Wraps monitoring functionality and basic configuration
class InternetMonitor
  include AASM

  aasm do
    state :idle, initial: true
    state :offline
    state :online

    event :go_online do
      transitions from: [:idle, :offline], to: :online do
        after do
          @logger.end_outage if aasm.from_state == :offline
          @logger.log 'Connection is online', :green
          @speed_measurer = Thread.new do
            Kernel.loop do
              measure_speed
              sleep @speed_measuring_delay
            end
          end
        end
      end
    end

    event :go_offline do
      transitions from: [:idle, :online], to: :offline do
        after do
          @logger.log 'Connection is offline', :red if aasm.from_state == :idle
          @speed_measurer.exit if aasm.from_state == :online
          @logger.start_outage
        end
      end
    end

    event :stop_monitoring do
      transitions from: [:online, :offline], to: :idle do
        after do
          @connection_monitor.exit
          @speed_measurer.exit
        end
      end
    end
  end

  def initialize(options = {})
    @logger = InternetMonitorLogger.new

    @connectivity_check_delay = options[:connectivity_check_delay] || 5
    @connection_check_host = options[:connection_check_host] || 'www.google.com'
    @speed_measuring_delay = options[:speed_measuring_delay] || 60 * 1
  end

  def start_monitoring
    return false unless idle?
    connection_active? ? go_online : go_offline
    start_speed_monitoring_thread
    true
  end

  private

  def connection_active?
    Net::Ping::HTTP.new(@connection_check_host).ping?
  end

  def start_speed_monitoring_thread
    @connection_monitor = Thread.new do
      Kernel.loop do
        if online?
          go_offline unless connection_active?
        elsif connection_active?
          go_online
        end
        sleep @connectivity_check_delay
      end
    end
  end

  def measure_speed
    speed_measure_results = Speedtest::Test.new.run
    @logger.log [
      format('Latency: %7.3f', speed_measure_results.latency.round(3)),
      '| Download Rate:', speed_measure_results.pretty_download_rate,
      '| Upload Rate:', speed_measure_results.pretty_upload_rate,
      '| Server:', speed_measure_results.server
    ].join(' '), :white
  rescue
    @logger.log 'Something went wrong when measuring connection speed', :yellow
  end
end
