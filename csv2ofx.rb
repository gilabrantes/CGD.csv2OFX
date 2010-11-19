#!/usr/bin/env ruby
require 'rubygems'
require 'builder'

unless ARGV.size == 1
	puts "Usage: csv2ofx <csv_file>"
	exit 1
end

transactions = Array.new

input = File.open(ARGV[0], "rb")
lines = input.readlines

i = 0
chk_ctr = 0
cc_deb_ctr = 0
cc_cred_ctr = 0

lines.each do |line|
	puts line
	puts "Processing line #{i+1}"
	i += 1

	if bits = line.match(/".*?\d\d-\d\d-\d\d\d\d";"(\d\d-\d\d-\d\d\d\d)";"(.*?)";"(.*?)";"(.*?)";".*?"/)
		chk_ctr +=1
		raw_deb = bits[3]
		raw_cred = bits[4]
	elsif bits = line.match(/".*?\d\d-\d\d-\d\d\d\d";"(\d\d-\d\d-\d\d\d\d)";"(.*?)";"(.*?)";"(.*?)"/)
		cc_cred_ctr +=1
		raw_deb = bits[3]
		raw_cred = bits[4]
	elsif bits = line.match(/".*?\d\d-\d\d-\d\d\d\d";"(\d\d-\d\d-\d\d\d\d)";"(.*?)";"(.*?)"/)
		cc_deb_ctr +=1
		raw_deb = bits[3]
		raw_cred = ""
	else
		next
	end

	deb = raw_deb.gsub(".", "").gsub!(",", ".").to_f
	cred = raw_cred.gsub(".", "").gsub!(",", ".").to_f
	
	t = { :date => bits[1].split("-").reverse.join(""),
		  :name => bits[2],
		  :amount => raw_deb != "" ? (deb * -1) : cred,
		  :display => "",
		  :to => ""}
	
	transactions << t
end

if chk_ctr > 0
	puts "Checking account statement detected"
	ACCTYPE = "checking"
	account = lines[6].scan(/\"(.*?)\"/)[1][0]
	if cc_deb_ctr != 0
		puts "[WARNING] Some transactions with a CC DEB type were detected, double check the file and script"
	end
	if cc_cred_ctr != 0
		puts "[WARNING] Some transactions with a CC DEB type were detected, double check the file and script"
	end
else
	puts "Credit card account statement detected"
	ACCTYPE = "credit card"
	account = "ISIC"
	if chk_ctr != 0
		puts "[WARNING] Some transactions with a checking type were detected, double check the file and script"
	end
end

output = File.new("statements#{transactions.first[:date]}_#{transactions.last[:date]}.ofx", "w")

output.puts '<?xml version="1.0" encoding="UTF-8" standalone="no"?>'
output.puts '<?OFX OFXHEADER="200" DATA="OFXSGML" VERSION="211" SECURITY="NONE" OLDFILEUID="NONE" NEWFILEUID="NONE"?>'

x = Builder::XmlMarkup.new(:target => output, :indent => 2)

x.OFX {
    
  x.BANKMSGSRSV1 {
    
    x.STMTTRNRS {
            
      x.STMTRS {
        
        x.CURDEF "EUR"
		x.BANKACCTFROM {
			x.BANKID ""
			x.ACCTID account
			x.ACCTTYPE ACCTYPE
		}
                
        x.BANKTRANLIST {
			x.DTSTART transactions.first[:date]
			x.DTEND transactions.last[:date]
          
          transactions.each do |transaction|
                    
            x.STMTTRN {
            
              x.NAME transaction[:name]
              x.DTPOSTED transaction[:date]              
              x.TRNAMT transaction[:amount]              
              x.MEMO transaction[:name]
            
            }
            
          end
          
        }
        
      }
      
    }
    
  }
}
