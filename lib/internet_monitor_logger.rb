require 'aasm'
require 'colorize'

# Wraps logging functionality and configuration
class InternetMonitorLogger
  include AASM

  aasm do
    state :logging_online, initial: true
    state :logging_offline

    event :start_outage do
      transitions from: :logging_online, to: :logging_offline do
        after do
          @outage_started_at = Time.now
          log 'Outage started', :red
        end
      end
    end

    event :end_outage do
      transitions from: :logging_offline, to: :logging_online do
        after do
          @outage_finished_at = Time.now
          mm, ss = (@outage_finished_at - @outage_started_at).divmod 60
          hh, mm = mm.divmod 60
          dd, hh = hh.divmod 24

          message = ''
          message << "#{dd} days, " unless dd == 0
          message << "#{hh} hours, " unless hh == 0
          message << "#{mm} minutes, " unless mm == 0
          message << "#{ss.to_i} seconds." unless ss == 0

          log "Outage over. Total time: #{message}", :red
        end
      end
    end
  end

  def log(message, color)
    color = color.to_s.downcase.sub(' ', '_').to_sym
    color = String.colors.include?(color) ? color : :white
    puts "[#{Time.now.strftime '%d/%m/%Y %H:%M:%S'}] #{message}".send color
  end
end
