require 'nokogiri'

module AppleEpf
  class Main
    attr_reader :downloader, :filedate, :files_matrix
    attr_accessor :store_dir, :keep_tbz_after_extract

    def initialize(filedate, files_matrix = nil, store_dir = nil, keep_tbz_after_extract = nil)
      @filedate = filedate
      @files_matrix = files_matrix || AppleEpf.files_matrix
      @store_dir = store_dir
      @keep_tbz_after_extract = !!keep_tbz_after_extract || AppleEpf.keep_tbz_after_extract
    end

    def self.get_list(url = current_url, response_hash = {})
      curl = Curl::Easy.new(url)
      curl.http_auth_types = :basic
      curl.username = AppleEpf.apple_id
      curl.password = AppleEpf.apple_password
      curl.follow_location = true
      curl.max_redirects = 5
      curl.perform
      body = curl.body_str

      matcher = %r{\A(itunes|match|popularity|pricing)(\d{8})\/\z}
      matchables = Nokogiri::HTML(body).xpath('//td/a').map(&:text)
      matchables.each_with_object(response_hash) do |s, all|
        m = s.match(matcher)
        next unless m
        all[m[2]] ||= {}
        all[m[2]][m[1]] = url + "/#{m[1]}#{m[2]}"
      end
    end

    module BaseActions
      def download_all_files
        downloaded_files = []

        @files_matrix.each_pair do |filename, tables|
          tables.each do |table|
            begin
              downloaded = download(filename, table)
              downloaded_files << downloaded
              yield(downloaded) if block_given?
            rescue AppleEpf::DownloaderError
              AppleEpf::Logging.logger.fatal "Failed to download file #{filename}"
              AppleEpf::Logging.logger.fatal $ERROR_INFO
              next
            end
          end
        end

        downloaded_files
      end

      def download_and_extract_all_files
        extracted_files = []

        download_all_files.each do |downloader|
          begin
            extracted_file = extract(downloader)
            extracted_files << extracted_file
            yield(extracted_file) if block_given?
          rescue => e
            AppleEpf::Logging.logger.error "Failed to extract file #{extracted_file}"
            AppleEpf::Logging.logger.error e
            AppleEpf::Logging.logger.error e.backtrace
            next
          end
        end

        extracted_files
      end

      def download(filename, table)
        downloader = AppleEpf::Downloader.new(type, filename.to_s, table, @filedate)
        downloader.dirpath = @store_dir if @store_dir
        downloader.download
        downloader
      end

      def extract(downloader)
        downloaded_file = downloader.download_to
        extractor = AppleEpf::Extractor.new(downloaded_file)
        extractor.keep_tbz_after_extract = @keep_tbz_after_extract if @keep_tbz_after_extract
        extractor.perform
        extractor.file_entry
      end
    end
  end

  class Incremental < Main
    include BaseActions

    def type
      'incremental'
    end

    def self.incremental_url
      'https://feeds.itunes.apple.com/feeds/epf/v4/full/current/incremental'
    end

    def self.get_file_list
      curl = Curl::Easy.new(incremental_url)
      curl.http_auth_types = :basic
      curl.username = AppleEpf.apple_id
      curl.password = AppleEpf.apple_password
      curl.follow_location = true
      curl.max_redirects = 5
      curl.perform
      body = curl.body_str

      matcher = %r{\A(\d{8})\/\z}
      matchables = Nokogiri::HTML(body).xpath('//td/a').map(&:text)
      result = matchables.each_with_object({}) do |s, all|
        m = s.match(matcher)
        next unless m
        date = m[1]
        get_list("#{incremental_url}/#{date}", all)
      end

      result
    end
  end

  class Full < Main
    include BaseActions

    def type
      'full'
    end

    def self.current_url
      'https://feeds.itunes.apple.com/feeds/epf/v4/full/current'
    end

    def self.get_file_list
      get_list
    end
  end
end
