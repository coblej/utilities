dryrun = true

puts "Dry Run: #{dryrun}"

puts "================================="
puts "Deleting AdminPolicy objects"
puts "================================="
apos = ActiveFedora::Base.where(active_fedora_model_ssi: 'AdminPolicy')
apos.each do |apo|
  puts "Deleting Admin Policy #{apo.pid}"
  unless dryrun
    apo.delete
  end
end
