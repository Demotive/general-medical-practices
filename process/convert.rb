#!/usr/bin/env ruby

require "csv"
require "json"

ODS_PRACTICE_HEADER = %w(
  organisation_code
  name
  national_grouping
  high_level_health_geography
  address_line_1
  address_line_2
  address_line_3
  address_line_4
  address_line_5
  postcode
  open_date
  close_date
  status_code
  organisation_sub_type_code
  commissioner
  join_provider_purchaser_date
  left_provider_purchaser_date
  contact_telephone_number
  null_1
  null_2
  null_3
  amended_record_indicator
  null_4
  provider_purchaser
  null_5
  prescribing_setting
  null_6
)

class Practice
  def initialize(ods_data:, choices_data:)
    @ods_data = ods_data
    @choices_data = choices_data
  end

  def complete_record?
    !ods_data.empty?
  end

  def organisation_code
    ods_data.fetch("organisation_code")
  end

  def active?
    ods_data.fetch("status_code") == "A"
  end

  def gp_practice?
    ods_data.fetch("prescribing_setting") == "4"
  end

  def to_hash
    {
      organisation_code: organisation_code,
      name: formatted_name,
      location: location_hash,
      contact_telephone_number: contact_telephone_number,
    }
  end

private
  attr_reader :ods_data, :choices_data

  def location_hash
    {
      address: address,
      latitude: latitude,
      longitude: longitude,
    }.reject { |_, v| v.nil? }
  end

  def formatted_name
    name.split(/\b/).map(&:capitalize).join
  end

  def name
    ods_data.fetch("name")
  end

  def address
    [*address_parts, postcode]
      .join(", ")
      .split(/\b/)
      .map { |a| a =~ /[^A-Z]/ ? a : a.capitalize }
      .join
  end

  def address_parts
    address_columns
      .map { |f| ods_data.fetch(f) }
      .reject(&:empty?)
  end

  def address_columns
    %w(
      address_line_1
      address_line_2
      address_line_3
      address_line_4
      address_line_5
    )
  end

  def postcode
    ods_data.fetch("postcode")
  end

  def contact_telephone_number
    ods_data.fetch("contact_telephone_number")
  end

  def latitude
    choices_data.fetch("Latitude", nil)
  end

  def longitude
    choices_data.fetch("Longitude", nil)
  end
end

def usage_message
  "Usage: #{$0} choices_data_file.csv ods_data_file.csv [ods_amendment_file_1.csv ...]"
end

def load_ods_practitioners_csv(file_name)
  hash = {}

  CSV.read(file_name, headers: ODS_PRACTICE_HEADER).each { |row|
    hash[row.fetch("organisation_code")] = row.to_hash
  }

  hash
end

def load_choices_csv(file_name)
  hash = {}

  CSV.read(file_name, col_sep: "\u00AC", quote_char: "\x00", encoding: "ISO-8859-1", headers: true).each do |row|
    hash[row.fetch("OrganisationCode")] = row.to_hash
  end

  hash
end

ods_file = ARGV.fetch(1) { abort(usage_message) }
ods_amendments = ARGV.drop(2)
ods_data_files = [ods_file] + ods_amendments
ods_data = ods_data_files
  .map(&method(:load_ods_practitioners_csv))
  .reduce(&:merge)

choices_data_file = ARGV.fetch(0) { abort(usage_message) }
choices_data = load_choices_csv(choices_data_file)

organisation_codes = ods_data.keys | choices_data.keys

practice_data = organisation_codes
  .lazy
  .map { |code|
    Practice.new(
      ods_data: ods_data.fetch(code, {}),
      choices_data: choices_data.fetch(code, {}),
    )
  }
  .select(&:complete_record?)
  .select(&:active?)
  .select(&:gp_practice?)
  .sort_by(&:organisation_code)

puts JSON.pretty_generate(
  practice_data.map(&:to_hash),
  indent: "    ",
)
