require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'
require 'time'


def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def clean_number(number)
  number = number.to_s.gsub(/[-\s().]/, '')
  number = number[1..-1] if number.length > 10 && number[0] == '1'
  return "Not a valid number." unless number.length == 10

  number
end

def reg_time(date_time, times)
  time_str = date_time.split(" ")[1]
  if time_str.length == 4
    time_str += " PM"
    time_obj = Time.strptime(time_str, "%I:%M %P")
  else
    time_obj = Time.parse(time_str)
  end

  times.push(time_obj.hour)
  times
end

def reg_day(date_time, day_arr)
  date_str = date_time.split(" ")[0]

  if date_str.include?('/')
    parts = date_str.split('/')
    if parts[0].to_i > 12
      date_obj = Date.strptime(date_str, '%d/%m/%Y')
    else
      date_obj = Date.strptime(date_str, '%m/%d/%Y')
    end
  else
    # Handle other date formats if needed
    begin
      date_obj = Date.parse(date_str)
    rescue ArgumentError
      puts "Unsupported date format: #{date_str}"
      return day_arr
    end
  end

  day_arr.push(date_obj.wday)
  day_arr
end

def peak_register(register_times, peaks)
  register_times.each do |time|
      peaks[time] += 1
  end
  peaks = peaks.sort_by { |_key, value| value}.to_h
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'
peaks = Hash.new(0)
day_peaks = Hash.new(0)
times = []
day_arr = []
contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  date = row[:regdate]
  day_arr = reg_day(date, day_arr)
  times = reg_time(date, times)

  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  numbers = clean_number(row[:homephone])
  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)
end

peaks = peak_register(times, peaks)
day_peaks = peak_register(day_arr, day_peaks)

puts "Peak registration hour is #{peaks.key(peaks.values.max)}:00 on #{Date::DAYNAMES[day_peaks.key(day_peaks.values.max)]}"
