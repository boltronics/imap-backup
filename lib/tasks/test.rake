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
      SimpleCov.at_exit { }
      run_server
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
      SimpleCov.at_exit { }
      Process.kill('TERM', pid)
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
    task :start do
      load_config
      create_working_directory
      fork_server
      save_config
      log = File.join(@config[:directory], 'imap.log')
      sleep 0.01 while not File.exist?(log)
      sleep 0.1 while not File.read(log).include?('open server')
    end

    desc 'Stop the email server process'
    task :stop do
      load_config
      stop_server
      delete_working_directory
      save_config
    end

    directory 'tmp'
  end
end
