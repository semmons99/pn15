module Stacker
  def self.parse(file)
    stacker = Interpreter.new

    File.foreach(file) do |command|
      command = command.chop.strip
      next if command == ""

      stacker.execute command
    end

    puts stacker.stack.reverse.map(&:inspect).join("\n")
  end

  class Interpreter
    attr_reader :stack

    def initialize
      @stack = []

      @procs = Hash.new{|h,k| h[k] = Array.new}
      @proc  = nil

      @if_stack = []

      @loop_stack = []
      @loop_cnt = 0
      @in_loop = false
    end

    def execute(command)
      if @if_stack.length > 0
        if command == "IF"
          if [:pass, :ignore].include? @if_stack.last
            @if_stack.push :ignore
            return
          end
        end

        return if @if_stack.last == :ignore && command != "THEN"

        if command == "ELSE"
          if @if_stack.last == :take
            @if_stack.pop
            @if_stack.push :pass
          elsif @if_stack.last == :pass
            @if_stack.pop
            @if_stack.push :take
          end
          return
        elsif command == "THEN"
          @if_stack.pop
          return
        end

        return if @if_stack.last == :pass
      end

      if @proc
        if command == "/PROCEDURE"
          @proc = nil
        else
          @procs[@proc].push command
        end
        return
      end

      if @in_loop
        if command == "/TIMES"
          @in_loop = false
          @loop_cnt.times do
            @loop_stack.each{|c| execute c}
          end
          @loop_stack = []
          @loop_cnt = 0
        else
          @loop_stack.push command
        end
        return
      end

      case command
      when /^PROCEDURE (.*)$/
        @proc = $1
      when "IF"
        if @stack.pop == :true
          @if_stack.push :take
        else
          @if_stack.push :pass
        end
        return
      when "TIMES"
        @in_loop = true
        @loop_cnt = @stack.pop
      when "DUP"
        @stack.push @stack.last
      when "SWAP"
        @stack.pop(2).reverse.each{|v| @stack.push v}
      when "DROP"
        @stack.pop
      when "ROT"
        vals = @stack.pop(3)
        @stack.push vals[1]
        @stack.push vals[2]
        @stack.push vals[0]
      when "ADD"
        pbo :+
      when "SUBTRACT"
        pbo :-
      when "MULTIPLY"
        pbo :*
      when "DIVIDE"
        pbo :/
      when "MOD"
        pbo :%
      when "<"
        pbo :<
      when ">"
        pbo :>
      when "="
        pbo :==
      when /^:(.*)$/
        @stack.push $1.to_sym
      else
        if @procs.keys.include? command
          @procs[command].each{|c| execute c}
        else
          @stack.push command.to_i
        end
      end
    end

    private

    def perform_binary_operation(method)
      vals = stack.pop(2)
      @stack.push symbolize(vals[0].send(method, vals[1]))
    end
    alias_method :pbo, :perform_binary_operation

    def symbolize(val)
      if val == true
        :true
      elsif val == false
        :false
      else
        val
      end
    end
  end
end
