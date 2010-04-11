require "rubygems"
require "safariwatir"
require "nokogiri"
require "prowl"
require "logger"

def logger
  @logger ||= Logger.new($stdout)
end

# ==============================
# = Store these somewhere safe =
# ==============================

print "Enter customer number: "
number = gets.chomp

print "Enter PIN: "
pin = gets.chomp.split("")

print "Enter Password: "
pass = gets.chomp.split("")

# ==============================
# = Loads the site and logs in =
# ==============================

logger.info "Starting safari"

@s = Watir::Safari.new
@s.hide

logger.info "Loading nwolb"

@s.goto "http://nwolb.com/"; sleep 3
@f = @s.frame("ctl00_secframe")
logger.info "Page loaded"

logger.info "Entering customer number"
@f.text_field(:id, "ctl00_mainContent_LI5TABA_DBID_edit").set(number)
@f.button(:value, "Log in").click
logger.info "Submitted"

label_regex = /Enter the (\d)\w{2} (?:number|character)/

# Fill in the PIN fields
logger.info "Filling in PIN fields"
i = @f.label(:id, "ctl00_mainContent_LI6DDALALabel").text[label_regex, 1].to_i
@f.text_field(:id, "ctl00_mainContent_LI6PPEA_edit").set(pin[i-1])

i = @f.label(:id, "ctl00_mainContent_LI6DDALBLabel").text[label_regex, 1].to_i
@f.text_field(:id, "ctl00_mainContent_LI6PPEB_edit").set(pin[i-1])

i = @f.label(:id, "ctl00_mainContent_LI6DDALCLabel").text[label_regex, 1].to_i
@f.text_field(:id, "ctl00_mainContent_LI6PPEC_edit").set(pin[i-1])
logger.info "PIN fields filled in"

# Fill in the Password fields
logger.info "Filling in password fields"
i = @f.label(:id, "ctl00_mainContent_LI6DDALDLabel").text[label_regex, 1].to_i
@f.text_field(:id, "ctl00_mainContent_LI6PPED_edit").set(pass[i-1])

i = @f.label(:id, "ctl00_mainContent_LI6DDALELabel").text[label_regex, 1].to_i
@f.text_field(:id, "ctl00_mainContent_LI6PPEE_edit").set(pass[i-1])

i = @f.label(:id, "ctl00_mainContent_LI6DDALFLabel").text[label_regex, 1].to_i
@f.text_field(:id, "ctl00_mainContent_LI6PPEF_edit").set(pass[i-1])
logger.info "Password fields filled in"

# Submit PIN/Password page
@f.button(:value, "Next").click
logger.info "Submitted PIN & Password form"
sleep 1

# Submit the next page, which is USUALLY adverts
# We _MIGHT_ end up a page with a checkbox to tick at this point
# need to handle that somehow
@f.button(:value, "Next").click
logger.info "Submitted the advert page"

sleep 3

# ================================
# = Mines the data from the page =
# ================================
logger.info "Grabbing data from the page"
js_to_extract_table_html = %{return window.top.frames[0].document.getElementById("ctl00_mainContent_Accounts").innerHTML}
@table_html = @f.send(:scripter).send(:execute, js_to_extract_table_html)
logger.info "Extracted HTML from page"

logger.info "Closing Browser"
@s.close

logger.info "Parsing HTML extract"
doc = Nokogiri::HTML.parse("<table>#{@table_html}</table>")

@output = []

doc.search("table tr").each do |row|
  # Only keep the summary rows
  next unless row[:title] && row[:title][/Select row/]

  cells = row.search("td").map {|x| x.text }.values_at(0, 3, 4)
  @output << "#{cells[0]}: #{cells[1]} (#{cells[2]})"
end

logger.info "HTML extract parsed"

# ==============================
# = Sends the data to my phone =
# ==============================

logger.info "Sending output to Prowl"
file = File.open(File.expand_path("~/.prowl"), "r").read.chomp
p = Prowl.new(:apikey => file, :application => "Mac Mini", :event => "Bank Totals")
p.add(:description => @output.join("\n"))

logger.info "All done!"