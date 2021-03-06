require 'net/http'
require 'date'
require 'curb'
require 'digest/md5'

module AppleEpf
  class Downloader
    include AppleEpf::Logging
    include AppleEpf::Finder

    attr_accessor :type, :filename, :table, :filedate, :force_url

    attr_reader :download_to, :apple_filename_full
    attr_writer :dirpath
    def initialize(type, filename, table, filedate, force_url = nil, full_date = nil)
      @type = type
      @filename = filename # itunes, popularity, match, pricing
      @table = table
      @filedate = filedate
      @force_url = force_url
      @full_date = full_date
    end

    def prepare
      if @force_url
        @apple_filename_full = @force_url
      else
        get_filename_by_date_and_type
        @apple_filename_full = apple_filename_full_url(@apple_filename_full_path)
      end
      @download_to = File.join(dirpath, @apple_filename_full.split('/')[-2..-1].join('/'))
      _prepare_folders
    end

    def download
      prepare
      @download_processor = AppleEpf.download_processor.new(@apple_filename_full, @download_to)
      @download_processor.download_and_check
      @download_to
    end

    def dirpath
      File.expand_path(File.join((@dirpath || AppleEpf.extract_dir), @type))
    end

    def get_filename_by_date_and_type
      case @type
      when 'full'
        path = "#{main_dir_date}/#{filename}#{main_dir_date}/#{table}.tbz"
      when 'incremental'
        date_of_file = date_to_epf_format(@filedate)
        path = "#{main_dir_date}/incremental/#{date_of_file}/#{filename}#{date_of_file}/#{table}.tbz"
      else
        path = ''
      end

      # Return false if no url was suggested or file does not exist
      raise AppleEpf::DownloaderError.new('Unable to find out what file do you want to download') if path.empty?

      _full_url = apple_filename_full_url(path)
      unless file_exists?(_full_url)
        if @type == 'incremental'
          # force prev week. Apple sometimes put files for Sunday to prev week, not current.
          path = "#{main_dir_date(true)}/incremental/#{date_of_file}/#{filename}#{date_of_file}/#{table}.tbz"
          _full_url = apple_filename_full_url(path)
          raise AppleEpf::FileNotExist.new("File does not exist #{path}") unless file_exists?(_full_url)
        else
          raise AppleEpf::FileNotExist.new("File does not exist #{path}")
        end
      end

      @apple_filename_full_path = path
      @apple_filename_full_path
    end

    def downloaded_file_base_name
      File.basename(@download_to, '.tbz') # popularity20130109
    end

    private

    def apple_filename_full_url(path)
      File.join(Finder::ITUNES_FULL_URL, path)
    end

    def _prepare_folders
      logger_info "Create folders for path: #{@download_to}"
      FileUtils.mkpath(File.dirname(@download_to))
    end

    def main_dir_date(force_last = false)
      if @full_date
        main_folder_date = @full_date
      else
        if @type == 'incremental'
          # from Mon to Thurday dumps are in prev week folder
          this_or_last = @filedate.wday <= 4 || force_last ? 'last' : 'this'
        elsif @type == 'full'
          # full downloads usually are done only once. user can determine when it should be done
          this_or_last = 'this'
        end

        main_folder_date = Chronic.parse("#{this_or_last} week wednesday", now: @filedate.to_time).to_date
      end

      date_to_epf_format(main_folder_date)
    end
  end
end
