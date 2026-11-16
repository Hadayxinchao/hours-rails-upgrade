# Class names that don't follow Zeitwerk's default camelization.
Rails.autoloaders.each do |autoloader|
  autoloader.inflector.inflect(
    "csv_download" => "CSVDownload",
    "entry_csv_generator" => "EntryCSVGenerator"
  )
end
