module RedstoneBot
  # Lets you associate some kind of id (usually an integer) to different
  # classes and then create them using the integer.
  # tid stands for "type id".
  module HasTids
    def self.extended(klass)
      types = {}
      klass.singleton_class.send(:define_method, :types) { types }
    end
    
    # This is called in the subclass definitions.
    def tid_is(tid)
      @tid = tid
      types[tid] = self
    end
    
    attr_reader :tid

    # This is only called on self.
    def create(tid, *args)
      klass = types[tid] or raise ArgumentError, "Unrecognized type of #{name}: #{tid}"
      klass.new(*args)
    end
  end
end