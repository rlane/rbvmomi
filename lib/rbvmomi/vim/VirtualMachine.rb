class RbVmomi::VIM::VirtualMachine
  # Retrieve the MAC addresses for all virtual NICs.
  # @return [Hash] Keyed by device label.
  def macs
    Hash[self.config.hardware.device.grep(RbVmomi::VIM::VirtualEthernetCard).map { |x| [x.deviceInfo.label, x.macAddress] }]
  end
  
  # Retrieve all virtual disk devices.
  # @return [Array] Array of virtual disk devices.
  def disks
    self.config.hardware.device.grep(RbVmomi::VIM::VirtualDisk)
  end

  # Retrieve all snapshots for this Virtual Machine
  # @return [Array] Array of VirtualMachineSnapshotTrees
  def snapshot_list(node=nil)
    unless node
      if self.snapshot
        node = self.snapshot.rootSnapshotList
      else
        return []
      end
    end

    list = []

    node.each do |child|
      list << child

      unless child.childSnapshotList.empty?
        list << snapshot_list(child.childSnapshotList)
      end
    end

    list.flatten
  end

  # Retrieve a snapshot object by name
  # @return VirtualMachineSnapshot for named snapshot
  def find_snapshot(name)
    snapshot_list.each do |snapshot|
      return snapshot.snapshot if snapshot.name == name
    end
    return nil
  end

end
