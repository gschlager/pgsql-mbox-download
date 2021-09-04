# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'nokogiri'
end

require 'nokogiri'
require 'open-uri'
require 'fileutils'
require 'yaml'
require 'date'

DATA_DIR = (ENV['DATA_DIR'] || '~/data/import')
BASE_URL = 'https://www.postgresql.org'
ALL_LISTS_URL = "#{BASE_URL}/list/"
MBOX_USERNAME = 'archives'
MBOX_PASSWORD = 'antispam'

class PostgresqlMailingList
  ListMetadata = Struct.new(:name, :description, :link, :category_name, :files)

  def download_mbox_files
    lists.each do |metadata|
      initialize_list_directory(metadata)
      mbox_links = find_mbox_links(metadata)

      puts "#{metadata.name}: #{mbox_links.size} mbox files"

      mbox_links.each do |mbox_link|
        download_mbox(metadata, mbox_link)
      end
    end
  end

  def lists
    all_lists = []
    page = Nokogiri::HTML(open_url(ALL_LISTS_URL))

    page.css('#pgContentWrap h5').each do |list_header_element|
      list_row_elements(list_header_element).each do |list_row_element|
        metadata = create_list_metadata(list_header_element, list_row_element)
        all_lists << metadata if metadata
      end
    end

    all_lists
  end

  def list_row_elements(list_header_element)
    list_header_element.at_css('+ table tbody').css('tr')
  end

  def create_list_metadata(list_header_element, list_row_element)
    link_element = list_row_element.at_css('th a[href^="/list/"]')
    description_element = list_row_element.at_css('td')
    return if !link_element || !description_element || !list_header_element

    list_name = link_element.text
    list_description = description_element.inner_html

    ListMetadata.new(list_name, list_description, link_element['href'],
                     list_header_element.text, mbox_file_hashes(list_name))
  end

  def metadata_filename(list_name)
    File.join(list_directory(list_name), 'metadata.yml')
  end

  def mbox_file_hashes(list_name)
    filename = metadata_filename(list_name)
    File.exist?(filename) ? YAML.load_file(filename).files : {}
  end

  def update_metadata(metadata, filename)
    current_month = Date.today.strftime('%Y%m')
    month_of_previous_week = (Date.today - 7).strftime('%Y%m')

    return unless filename.end_with?(current_month, month_of_previous_week)

    metadata.files[File.basename(filename)] = calc_checksum(filename)
    write_metadata(metadata)
  end

  def find_mbox_links(metadata)
    page = Nokogiri::HTML(open_url("#{BASE_URL}#{metadata.link}"))
    page.css('#pgContentWrap a:contains("mbox")').map { |a| a['href'] }
  end

  def initialize_list_directory(metadata)
    directory = list_directory(metadata.name)
    FileUtils.mkdir_p(directory)

    write_metadata(metadata)
  end

  def write_metadata(metadata)
    filename = metadata_filename(metadata.name)

    File.open(filename, 'w') do |f|
      f.write(metadata.to_yaml(line_width: -1))
    end
  end

  def download_mbox(metadata, mbox_link)
    base_filename = File.basename(mbox_link)
    filename = File.join(list_directory(metadata.name), base_filename)
    uri = URI("#{BASE_URL}#{mbox_link}")

    if needs_download?(filename, uri, metadata)
      puts "    Downloading #{base_filename}"
      download_file(filename, uri)
      update_metadata(metadata, filename)
    else
      puts "    Skipping #{base_filename}"
    end
  end

  def download_file(filename, uri)
    create_http(uri) do |http|
      request = Net::HTTP::Get.new(uri)
      request.basic_auth(MBOX_USERNAME, MBOX_PASSWORD)

      http.request(request) do |response|
        write_response_to_file(response, filename)
      end
    end
  end

  def write_response_to_file(response, filename)
    File.open(filename, 'w') do |io|
      response.read_body do |chunk|
        io.write(chunk)
      end
    end
  end

  def needs_download?(filename, uri, metadata)
    return false if File.exist?(filename) && file_checksums_match?(filename, metadata)

    create_http(uri) do |http|
      request = Net::HTTP::Head.new(uri)
      request.basic_auth(MBOX_USERNAME, MBOX_PASSWORD)

      response = http.request(request)
      return response['Content-Length'] != File.size?(filename).to_s
    end
  end

  def file_checksums_match?(filename, metadata)
    checksum = metadata.files[File.basename(filename)]
    checksum && calc_checksum(filename) == checksum
  end

  def calc_checksum(filename)
    Digest::SHA256.file(filename).hexdigest
  end

  def list_directory(list_name)
    File.join(DATA_DIR, sanitize_filename(list_name))
  end

  def sanitize_filename(filename)
    bad_chars = %w(/ \\ ? % * : | " < > .)
    bad_chars.each { |bad_char| filename.gsub!(bad_char, '_') }
    filename
  end

  def create_http(uri)
    tries ||= 3

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      yield http
    end
  rescue Net::OpenTimeout
    retry unless (tries -= 1).zero?
  end

  def open_url(url)
    tries ||= 3
    URI.open(url)
  rescue Net::OpenTimeout
    retry unless (tries -= 1).zero?
  end
end

PostgresqlMailingList.new.download_mbox_files
