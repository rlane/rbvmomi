# @note +download+ and +upload+ require +curl+. If +curl+ is not in your +PATH+
#       then set the +CURL+ environment variable to point to it.
# @todo Use an HTTP library instead of executing +curl+.
class RbVmomi::VIM::Datastore
  CURLBIN = ENV['CURL'] || "curl" #@private

  # Check whether a file exists on this datastore.
  # @param path [String] Path on the datastore.
  def exists? path
    req = Net::HTTP::Head.new mkuripath(path)
    req.initialize_http_header 'cookie' => _connection.cookie
    resp = _connection.http.request req
    case resp
    when Net::HTTPSuccess
      true
    when Net::HTTPNotFound
      false
    else
      fail resp.inspect
    end
  end

  # Download a file from this datastore.
  # @param remote_path [String] Source path on the datastore.
  # @param local_path [String] Destination path on the local machine.
  # @return [void]
  def download remote_path, local_path
    url = "http#{_connection.http.use_ssl? ? 's' : ''}://#{_connection.http.address}:#{_connection.http.port}#{mkuripath(remote_path)}"
    pid = spawn CURLBIN, "-k", '--noproxy', '*', '-f',
                "-o", local_path,
                "-b", _connection.cookie,
                url,
                :out => '/dev/null'
    Process.waitpid(pid, 0)
    fail "download failed" unless $?.success?
  end

  # Upload a file to this datastore.
  # @param remote_path [String] Destination path on the datastore.
  # @param local_path [String] Source path on the local machine.
  # @return [void]
  def upload remote_path, local_path
    url = "http#{_connection.http.use_ssl? ? 's' : ''}://#{_connection.http.address}:#{_connection.http.port}#{mkuripath(remote_path)}"
    pid = spawn CURLBIN, "-k", '--noproxy', '*', '-f',
                "-T", local_path,
                "-b", _connection.cookie,
                url,
                :out => '/dev/null'
    Process.waitpid(pid, 0)
    fail "upload failed" unless $?.success?
  end

  # Find a file in the sub-directories of a datastore
  # The last match is returned
  def find_file_path file
    @results = find_file(file)
    @results.each do |result|
    result.file.each do |file_info|
      return result.folderPath if file == file_info.path
    end
  end

  fail "Could not find file"
  end

  def get_file_info file
    @results = find_file(file)
    @results.each do |result|
      result.file.each do |file_info|
        return file_info if file == file_info.path
      end
    end

    fail "Could not find file"
  end

  private

  def find_file file
    @ds_path = "[#{self.info.name}]"
    
    @disk_flags = RbVmomi::VIM::VmDiskFileQueryFlags.new(:capacityKb => true, :diskType => true, :thin => false, :hardwareVersion => false)
    @disk_query = RbVmomi::VIM::VmDiskFileQuery.new(:details => @disk_flags)
    @detail_flags = RbVmomi::VIM::FileQueryFlags.new(:fileOwner => false, :fileSize => false, :fileType => true, :modification => false)

    @query_spec = RbVmomi::VIM::HostDatastoreBrowserSearchSpec.new(:query => [*@disk_query], :details => @detail_flags)
  self.browser.SearchDatastoreSubFolders_Task(:datastorePath => @ds_path, :searchSpec => @query_spec).wait_for_completion
  end

  def datacenter
    return @datacenter if @datacenter
    x = parent
    while not x.is_a? RbVmomi::VIM::Datacenter
      x = x.parent
    end
    fail unless x.is_a? RbVmomi::VIM::Datacenter
    @datacenter = x
  end

  def mkuripath path
    "/folder/#{URI.escape path}?dcPath=#{URI.escape datacenter.name}&dsName=#{URI.escape name}"
  end
end
