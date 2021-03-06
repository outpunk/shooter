#!/usr/bin/env ruby
require 'rubygems'
require "digest"
require "rb-fsevent"
require 'terminal-notifier'
require "yaml"

class Shooter
  def initialize(path, config)
    @config   = config
    @entries  = Dir.entries(@config[:local_path])
    @path     = path
  end

  def notify(url)
    TerminalNotifier.notify(url, title: "File uploaded") if @config[:show_notification]
    if @config[:play_sound]
      sound = File.expand_path(@config[:sound], @path)
      `afplay '#{sound}'`
    end
  end

  def upload(filename)
    unless filename.nil? || filename.to_s[0] == "."
      digest      = Digest::MD5.hexdigest(filename)[0..15]
      source      = "#{@config[:local_path]}/#{filename}"
      remote_file = "#{digest}#{File.extname(filename)}"
      destination = "#{@config[:user]}@#{@config[:host]}:#{@config[:remote_path]}/#{remote_file}"
      url         = "#{@config[:url]}/#{remote_file}"
      
      `scp '#{source}' #{destination}`
      `echo #{url} | tr -d '\n' | pbcopy`
      `rm '#{source}'` if @config[:remove_source]

      notify url
    end
  end

  def run
    fsevent = FSEvent.new
    fsevent.watch @config[:local_path] do |directories|
      dir         = directories.first
      old_entries = @entries
      @entries    = Dir.entries(dir)
      filename    = (@entries - old_entries).first

      upload filename
    end
    fsevent.run
  end
end

shooter_path = File.dirname(File.expand_path(__FILE__))
config = YAML.load_file("#{shooter_path}/config.yml")
config = config.inject({}) { |hash,(k,v)| hash[k.to_sym] = v; hash }

Process.daemon
Shooter.new(shooter_path, config).run