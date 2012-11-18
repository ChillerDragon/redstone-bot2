require_relative '../uninspectable'
require_relative '../body'

# TODO: add some primitive falling?

module RedstoneBot
  class BasicBot
    include Synchronizer
    include Uninspectable

    attr_reader :client, :body
      
    def initialize(client)
      @client = client
      @client.synchronizer = self
      @mutex = Mutex.new
      
      setup
    end
        
    def setup
      @body = Body.new(@client, self)
      
      @client.listen do |p|
        if p.is_a?(Packet::Disconnect)
          puts "Connection terminated by server.  Position = #{@body.position}"
          exit 2
        end
      end

    end

    def start_bot
      @client.start
    end
        
    extend Forwardable
    def_delegators :@body, :position, :look_at, :distance_to, :closest, :wait_for_next_position_update
    def_delegators :@client, :chat, :time_string
  end
end