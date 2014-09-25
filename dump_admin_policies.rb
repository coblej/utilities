puts "================================="
puts "Dumping AdminPolicy objects"
puts "================================="
AdminPolicy.find_each do |apo|
  puts "#{apo.pid}...#{apo.title.first}"
  puts "Default Permissions: #{apo.default_permissions}"
  puts "(Object) Permissions: #{apo.permissions}"
  puts "================================="
end