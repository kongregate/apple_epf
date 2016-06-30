require 'logger'

module AppleEpf
  module Logging
    def self.logger
      @logger ||= initialize_logger
    end

    def self.logger=(logger)
      @logger = logger
    end

    def logger
      AppleEpf::Logging.logger
    end

    def logger_info(data)
      logger.info(data)
    end

    private

    def self.initialize_logger
      logfile = File.open(AppleEpf.log_file, File::WRONLY | File::APPEND | File::CREAT)
      logger = Logger.new(logfile, 'weekly')
      logger.level = Logger::DEBUG
      logger
    rescue
      p 'Unable to create logger'
      raise $ERROR_INFO
    end
  end
end
