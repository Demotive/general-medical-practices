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
  def initialize(data)
    @data = data
  end

  def organisation_code
    data.fetch("organisation_code")
  end

  def active?
    data.fetch("status_code") == "A"
  end

  def gp_practice?
    data.fetch("prescribing_setting") == "4"
  end

  def to_hash
    {
      organisation_code: organisation_code,
      name: formatted_name,
      address: address,
      contact_telephone_number: contact_telephone_number,
    }
  end

private
  attr_reader :data

  def formatted_name
    name.split(/\b/).map(&:capitalize).join
  end

  def name
    data.fetch("name")
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
      .map { |f| data.fetch(f) }
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
    data.fetch("postcode")
  end

  def contact_telephone_number
    data.fetch("contact_telephone_number")
  end
end

def usage_message
  "Usage: #{$0} ods_data_file.csv [ods_amendment_file_1.csv ...]"
end

def load_ods_practitioners_csv(file_name)
  hash = {}

  CSV.read(file_name, headers: ODS_PRACTICE_HEADER).each { |row|
    hash[row.fetch("organisation_code")] = row.to_hash
  }

  hash
end

ods_file = ARGV.fetch(0) { abort(usage_message) }
ods_amendments = ARGV.drop(1)
ods_data_files = [ods_file] + ods_amendments

practice_data = ods_data_files
  .map(&method(:load_ods_practitioners_csv))
  .reduce(&:merge)
  .values
  .lazy
  .map(&Practice.method(:new))
  .select(&:active?)
  .select(&:gp_practice?)
  .sort_by(&:organisation_code)

puts JSON.pretty_generate(
  practice_data.map(&:to_hash),
  indent: "    ",
)
