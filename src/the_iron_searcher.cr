require "option_parser"

VERSION = "0.1.0"

options = {
  # the following at the default options value
  "recursive" => false,
  "method" => "fiber",
  "skip_output" => false
}

OptionParser.parse do |parser|
  parser.banner = "Welcome to The Iron Searcher! \n\nUsage: fe [options] SEARCH_TERM SEARCH_DIRECTORY \n"

  parser.on "-r", "--recursive", "Recursively search files in sub-directories" do
    options["recursive"] = true
  end

  parser.on "--skip-output", "Do not print to stdout the results of the search (this option was made for benchmark runs)" do
    options["skip_output"] = true
  end

  parser.on "--serial", "Search in serial (one file at a time), as opposed to using fibers (multiple files at the same time)" do
        options["method"] = "serial"
  end

  parser.on "-v", "--version", "Show version" do
    puts "Version #{VERSION}"
    exit
  end

  parser.on "-h", "--help", "Show help" do
    puts parser
    exit
  end

  parser.missing_option do |option_flag|
    STDERR.puts "ERROR: #{option_flag} is missing something.\n\n"
    STDERR.puts ""
    STDERR.puts parser
    exit(1)
  end

  parser.invalid_option do |option_flag|
    STDERR.puts "ERROR: #{option_flag} is not a valid option.\n\n"
    STDERR.puts parser
    exit(1)
  end
end

arguments = {} of String => String

arguments["search_term"] = ARGV.shift { "" }
if arguments["search_term"].nil? || arguments["search_term"].empty?
  puts "missing argument: NO search term provided"
  exit
end

arguments["search_directory_path"] = ARGV.shift { "" }
if arguments["search_directory_path"].nil? || arguments["search_directory_path"].empty?
  puts "missing argument: NO search directory path provided"
  exit
end

files_to_search_in = [] of String
if Dir.exists? arguments["search_directory_path"]
  if options["recursive"]
    files_to_search_in = Dir.glob("#{arguments["search_directory_path"]}/**/*")
  else
    files_to_search_in = Dir.glob("#{arguments["search_directory_path"]}/*")
  end
elsif File.exists? arguments["search_directory_path"]
  files_to_search_in = [arguments["search_directory_path"]]
end

def ignore_file?(file)
  skip_locations = ["bin/", "tmp/", "_site/", "log/", "node_modules/"]
  skip_locations.each do |skip_location|
    if File.directory? file
      return true
    elsif file.includes? skip_location
      return true
    end
  end

  return false
end

files_to_search_in.reject! { |file| ignore_file? file }

def search_in_file(search_term, file, skip_output)
  File.read_lines(file).each do |line|
    if line.includes? search_term
      puts "#{file}: #{line}" unless skip_output
    end
  end 
end

def serial_search(search_term, files, skip_output)
  files.each do |file|
    search_in_file search_term, file, skip_output
  end
end

def fiber_search(search_term, files, skip_output)
  channel = Channel(String|Nil).new

  files.each do |file|
    spawn do
      channel.send search_in_file search_term, file, skip_output
    end
  end

  files.size.times do
    channel.receive
  end
end

case options["method"]
when "fiber"
  fiber_search arguments["search_term"], files_to_search_in, options["skip_output"]
else 
  serial_search arguments["search_term"], files_to_search_in, options["skip_output"]
end