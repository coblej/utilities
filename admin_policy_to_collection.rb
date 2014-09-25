DEFAULT_PERMISSIONS = [{:type=>"group", :access=>"read", :name=>"public"}]

@collection_pids = []

def already_changed?(obj)
  apo_pid = admin_policy_pid(obj)
  if obj.is_a? Collection
    if obj.default_permissions == DEFAULT_PERMISSIONS && apo_pid.nil?
      return true
    else
      return false
    end
  else
    if apo_pid.nil?
      return false
    else
      if @collection_pids.include? apo_pid
        return true
      else
        begin
          apo = ActiveFedora::Base.find(apo_pid)
        rescue ActiveFedora::ObjectNotFoundError
          return false
        end
        if apo.is_a? Collection
          @collection_pids << obj.admin_policy_id
          return true
        else
          return false
        end
      end
    end
  end
end

def process_change(obj, old_apo_pid)
  puts "WARNING: #{obj.class.name} #{obj.pid} does not validate ... saving anyway" unless obj.valid?
  if obj.save(validate: false)
    obj.reload
    puts "#{obj.class.name} #{obj.pid} changed admin_policy from #{old_apo_pid} to #{obj.admin_policy_id}"
    log_event(obj, old_apo_pid, obj.admin_policy_id)
  else
    puts "ERROR: Error saving #{obj.class.name} #{obj.pid}"      
  end
end

def event_detail(old_apo_pid, new_apo_pid)
  detail = <<-EOS
Changed admin_policy relationship object from #{old_apo_pid.nil? ? '<nil>' : old_apo_pid} to #{new_apo_pid.nil? ? '<nil>' : new_apo_pid}
  EOS
end

def log_event(obj, old_apo_pid, new_apo_pid)
  UpdateEvent.create(pid: obj.pid, 
                    summary: "governing admin_policy changed",
                    detail: event_detail(old_apo_pid, new_apo_pid))
end

def admin_policy_pid(obj)
  solr_results = ActiveFedora::SolrService.query(ActiveFedora::SolrService.construct_query_for_pids([obj.pid]))
  if solr_results.nil? || solr_results.empty?
    return nil
  else
    admin_policy_uris = solr_results.first[DulHydra::IndexFields::IS_GOVERNED_BY]
    if admin_policy_uris.nil? || admin_policy_uris.empty?
      return nil
    else
      return admin_policy_uris.first.split("/").last
    end
  end
end

puts "================================="
puts "Processing Collections, Items, and Components"
puts "================================="
Collection.find_each do |coll|
  puts "#{coll.pid}...#{coll.title.first}"
  @collection_pids << coll.pid
  if already_changed?(coll)
    puts "Collection #{coll.pid} already changed ... skipping"
  else
    save_apo_pid = admin_policy_pid(coll)
    coll.default_permissions = DEFAULT_PERMISSIONS
    coll.clear_relationship(:is_governed_by)
    process_change(coll, save_apo_pid)
  end
  coll_item_pids = ActiveFedora::SolrService.query(coll.association_query(:children), rows: 999999).map { |r| r["id"] }
  coll_item_pids.each do |item_pid|
    item = Item.find(item_pid)
    if already_changed?(item)
      puts "Item #{item.pid} already changed ... skipping"
    else
      save_apo_pid = admin_policy_pid(item)
      item.clear_relationship(:is_governed_by)
      item.admin_policy = coll
      process_change(item, save_apo_pid)
    end
    item_comp_pids = ActiveFedora::SolrService.query(item.association_query(:children), rows: 999999).map { |r| r["id"] }
    item_comp_pids.each do |comp_pid|
      comp = Component.find(comp_pid)
      if already_changed?(comp)
        puts "Component #{comp.pid} already changed ... skipping"
      else
        save_apo_pid = admin_policy_pid(comp)
        comp.clear_relationship(:is_governed_by)
        comp.admin_policy = coll
        process_change(comp, save_apo_pid)
      end
    end
  end
  puts "================================="
end

puts "================================="
puts "Processing Targets"
puts "================================="
Target.find_each do |target|
  puts "#{target.pid}...#{target.title.first}"
  if already_changed?(target)
    puts "Target #{target.pid} already changed ... skipping"
  else
    save_apo_pid = admin_policy_pid(target)
    target.clear_relationship(:is_governed_by)
    if target.collection
      target.admin_policy = target.collection
      process_change(target, save_apo_pid)
    else
      puts "WARNING: Target #{target.pid} does not have a collection"
    end
  end
  puts "================================="
end

puts "================================="
puts "Processing Attachments"
puts "================================="
Attachment.find_each do |att|
  puts "#{att.pid}...#{att.title.first}"
  if already_changed?(att)
    puts "Attachment #{att.pid} already changed ... skipping"
  else
    save_apo_pid = admin_policy_pid(att)
    att.clear_relationship(:is_governed_by)
    if att.attached_to
      if att.attached_to.is_a?(Collection)
        att.admin_policy = att.attached_to
      else
        att.admin_policy = att.attached_to.admin_policy
      end
      process_change(att, save_apo_pid)
    else
      puts "WARNING: Attachment #{att.pid} is not attached to anything"
    end
  end
  puts "================================="
end

