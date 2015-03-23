puts "================================="
puts "Assigning structural metadata"
puts "================================="
assigned = 0
existing = 0
colls = Collection.all
colls.each do |coll|
  puts "Collection: #{coll.pid}"
  items = coll.items
  items.each do |item|
    puts "Item: #{item.pid}"
    q = item.association_query(:children)
    rows = 9999
    sort = "#{Ddr::IndexFields::IDENTIFIER} ASC"
    comp_pids = ActiveFedora::SolrService.query(q, rows: rows, sort: sort).map { |r| r["id"] }
    comp_pids.each do |comp_pid|
      comp = Component.find(comp_pid)
      if comp.file_use && comp.order
        puts "Component: #{comp.pid} ... Existing structural metadata"
        existing += 1
      else
        puts "Component: #{comp.pid} ... Assigning structural metadata"
        comp.assign_struct_metadata!
        assigned += 1
      end
    end
  end
end
puts "======================================================"
puts "Existing structural metadata: #{existing} #{'Component'.pluralize(existing)}"
puts "Assigned structural metadata: #{assigned} #{'Component'.pluralize(assigned)}"
puts "======================================================"
