require "redstone_bot/bot"
require "redstone_bot/chat_evaluator"
require 'forwardable'
require "redstone_bot/pathfinder"

module RedstoneBot
  module Bots; end

  class Bots::DavidBot < RedstoneBot::Bot
    extend Forwardable
    
    def setup
      standard_setup
      
      @ce = ChatEvaluator.new(self, @client)
      
      @body.on_position_update do
        @body.look_at @entity_tracker.closest_entity
      end

      waypoint = [109, 71, 237]
      @body.on_position_update do
        move_to(waypoint)
      end

      
      @pathfinder = Pathfinder.new(@chunk_tracker)
      
      @client.listen do |p|
        case p
        when :start
          #@client.later(5) do
          #  tmphax_find_path
          #end
        when Packet::ChatMessage
          if p.message == "<Elavid> t"
            tmphax_find_path
          end
        
          puts p
        when Packet::Disconnect
          exit 2
        end
      end      
      
    end

    def tmphax_find_path
      @pathfinder.start = @body.position.to_a.collect(&:to_i)
      @pathfinder.bounds = [94..122, 69..78, 233..261]
      @pathfinder.goal = [104, 73, 240]
      puts "Finding path from #{@pathfinder.start} to #{@pathfinder.goal}..."
      result = @pathfinder.find_path
      puts "t: " + result.inspect
    end
    
    def inspect
      to_s
    end
    
    def move_to(waypoint)
      speed = 1
      waypoint = Vector[*waypoint]
      dir = waypoint - @body.position
      if dir.norm < 0.2
        puts "success"
        return
      end
      
      d = dir.normalize*speed*@body.update_period
      #puts "%7.4f %7.4f %7.4f" % [d[0], d[1], d[2]]
      @body.position += d
      @body.stance = @body.position[1] + 1
      @body.on_ground = true #false      
    end
    
    def_delegator :@chunk_tracker, :block_type, :block_type
    def_delegator :@client, :chat, :chat
  end
end