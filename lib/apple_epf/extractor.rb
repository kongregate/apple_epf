module AppleEpf
  class Extractor
    class FileEntry < Struct.new(:tbz_file); end

    attr_reader :file_entry, :filename, :dirname, :basename
    attr_accessor :keep_tbz_after_extract

    def initialize(filename)
      @filename = filename

      @dirname = File.dirname(@filename)
      @basename = File.basename(@filename)
    end

    # TODO: use multithread uncompressing tool
    def perform
      @extracted_files = []

      extract = extract_command(filename)

      AppleEpf::Logging.logger.error("here it is!!!")
      AppleEpf::Logging.logger.error("cd #{dirname} && #{extract}")
      result = system "cd #{dirname} && #{extract}"

      if result
        _extracted_files = @extracted_files.map { |f| File.join(@dirname, f) }
        @file_entry = FileEntry.new(@filename)
        FileUtils.remove_file(@filename, true) unless keep_tbz_after_extract?
      else
        raise "Unable to extract files from #{@filename}"
      end

      @file_entry
    end

    private

    def extract_command(filename)
      "#{archiver_path} -xf #{filename}"
    end

    def archiver_path
      AppleEpf.archiver_path
    end

    def keep_tbz_after_extract?
      !!keep_tbz_after_extract || AppleEpf.keep_tbz_after_extract
    end
  end
end
