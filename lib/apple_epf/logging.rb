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
      if STDOUT == AppleEpf.log_file
        log_file = STDOUT
      else
        log_file = File.open(File.expand_path(AppleEpf.log_file), File::WRONLY | File::APPEND | File::CREAT)
      end
      logger = Logger.new(log_file, 'weekly')
      logger.level = Logger::DEBUG
      logger
    rescue
      p 'Unable to create logger'
      raise $ERROR_INFO
    end
  end
end
