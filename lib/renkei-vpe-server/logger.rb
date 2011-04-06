require 'logger'

module RenkeiVPE
  class Logger < Logger
    def self.init(log_file)
      raise "Logger is already initialized" if @logger
      @logger = Logger.new(log_file, 'daily')
      @logger.formatter = RenkeiVPELogFormatter.new
      @logger.level = Logger::INFO
    end

    def self.get_logger
      if @logger
        return @logger
      else
        raise "Call #{self.class}.init(file_name) beforehand."
      end
    end

    def set_level(level_str)
      level_str.upcase!
      case level_str
      when 'FATAL'
        @level = Logger::FATAL
      when 'ERROR'
        @level = Logger::ERROR
      when 'WARN'
        @level = Logger::WARN
      when 'INFO'
        @level = Logger::INFO
      when 'DEBUG'
        @level = Logger::DEBUG
      end
    end
  end

  class RenkeiVPELogFormatter < Logger::Formatter
    Format = "%s [%5s]: %s\n"

    def call(severity, time, progname, msg)
      Format % [format_datetime(time), severity, msg2str(msg)]
    end

    def format_datetime(time)
      time.strftime('%Y-%m-%d %H:%M:%S')
    end
  end

end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
