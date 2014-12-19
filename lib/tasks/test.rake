require 'fileutils'
require 'rims'
require 'tmpdir'
require 'yaml'

module TestEmailServerHelpers
  # This file holds configuration
  # and transient data (PID and temp directory)
  # Keys are Symbols
  def config_filename
    'rims.yaml'
  end

  def default_config
    {
      port: 1360,
    }
  end

  def load_config
    if File.exist?(config_filename)
      @config = YAML.load(File.read(config_filename))
    else
      @config = default_config
    end
  end

  def save_config
    File.open(config_filename, 'w') { |f| f.write @config.to_yaml }
  end
  
  def create_working_directory
    @config[:directory] = Dir.mktmpdir(nil, 'tmp')
  end

  def delete_working_directory
    FileUtils.rm_rf @config.delete(:directory)
  end

  def fork_server
    pid = fork do
      run_server
      Kernel.exit!
    end
    @config[:pid] = pid
  end

  def run_server
    RIMS::Cmd.run_cmd([
      'server',
      '--base-dir=' + @config[:directory],
      '--username=user@example.com',
      '--password=password',
      "--ip-port=#{@config[:port]}",
    ])
  end

  def stop_server
    pid = @config.delete(:pid)
    fork do
      Process.kill('TERM', pid)
      Kernel.exit!
    end
    Process.waitpid pid
  rescue Errno::ESRCH
    # It doesn't matter if the process was already dead
  end
end

namespace :test do
  namespace :email_server do
    include TestEmailServerHelpers

    desc 'Start the email server process'
    task start: [:config] do
      create_working_directory
      fork_server
      save_config
    end

    desc 'Stop the email server process'
    task stop: [:config] do
      stop_server
      delete_working_directory
      save_config
    end

    task :config do
      load_config
    end

    directory 'tmp'
  end
end
