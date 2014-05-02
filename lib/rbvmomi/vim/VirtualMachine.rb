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

  # Retrieve all virtual controllers
  # @return [Array] Array of virtual controllers
  def controllers
    self.config.hardware.device.grep(RbVmomi::VIM::VirtualController)
  end

  # Add specified VMDK as a disk to VM
  def add_vmdk(options={})
    defaults = {
      :controller => "SCSI controller 0",
    }
    options = defaults.merge(options)
      fail "Please provide a datastore" unless options[:datastore].is_a? RbVmomi::VIM::Datastore

    @ds = options[:datastore]
    @vmdk = options[:vmdk]

    @file_path = @ds.find_file_path(@vmdk)
    @full_file_path = "#{@file_path}#{@vmdk}"

    @disk_backing_info = RbVmomi::VIM::VirtualDiskFlatVer2BackingInfo.new(  :datastore => @ds, 
                                                                            :fileName => @full_file_path, 
                                                                            :diskMode => "persistent")

    @vm_controllers = self.controllers

    @vm_controller = nil
    @vm_controllers.each { |c| @vm_controller = c if c.deviceInfo.label == options[:controller] }
    fail "Could not find Virtual Controller #{options[:controller]}" if @vm_controller.nil?

    # Because the unit number starts at 0, count will return the next value we can use
    @unit_number = @vm_controller.device.count

    @capacityKb  = @ds.get_file_info(@vmdk).capacityKb
    @disk = RbVmomi::VIM::VirtualDisk.new(:controllerKey => @vm_controller.key, 
                                          :unitNumber => @unit_number,
                                          :key => -1,
                                          :backing => @disk_backing_info,
                      :capacityInKB => @capacityKb)
    @dev_spec = RbVmomi::VIM::VirtualDeviceConfigSpec.new(  :operation => RbVmomi::VIM::VirtualDeviceConfigSpecOperation.new('add'),
                                                            :device => @disk)
    @vm_spec = RbVmomi::VIM::VirtualMachineConfigSpec.new( :deviceChange => [*@dev_spec] )

    puts "Reconfiguring #{self.name} to add VMDK: #{@full_file_path}"
    ReconfigVM_Task( :spec => @vm_spec ).wait_for_completion
  end
end
