# TODO: Guard against non-text messages in the DSL

module Rubotnik
  # Routing for messages
  class MessageDispatch
    attr_accessor :nlu
    include Commands

    def initialize(message, nlu: nil)
      @message = message
      p @message.class
      p @message
      @user = UserStore.instance.find_or_create_user(@message.sender['id'])
      @nlu = nlu
    end

    def route(&block)
      if @user.current_command
        command = @user.current_command
        execute(command)
        puts "Command #{command} is executed for user #{@user.id}" # log
      else
        bind_commands(&block)
      end
    end

    private

    def bind_commands(&block)
      @matched = false
      instance_eval(&block)
    end

    def bind(*regex_strings, all: false, to: nil, start_thread: {})
      regexps = regex_strings.map { |rs| /^#{rs}/i }
      proceed = regexps.any? { |regex| @message.text =~ regex }
      proceed = regexps.all? { |regex| @message.text =~ regex } if all
      return unless proceed
      @matched = true
      if block_given?
        yield
        return
      end
      handle_command(to, start_thread)
    end

    def handle_command(to, start_thread)
      if start_thread.empty?
        puts "Command #{to} is executed for user #{@user.id}"
        execute(to)
        @user.reset_command
        puts "Command is reset for user #{@user.id}"
      else
        # say definition is located in Helpers module mixed into bot.rb
        say(start_thread[:message], quick_replies: start_thread[:quick_replies])
        @user.assign_command(to)
        puts "Command #{to} is set for user #{@user.id}"
      end
    end

    def disallow_non_text
      return true if text_message?
      @user.reset_command
      yield if block_given?
      return true 
    end

    def default
      return if @matched
      puts 'None of the commands were recognized' # log
      yield
      @user.reset_command
    end

    def nlu_bind(to: nil)
      if @matched
        @user.reset_command
        return
      end
      puts 'Wit bind enabled' # log
      if block_given?
        yield
        return
      else
        execute(to) if to
      end
    end


    def execute(command)
      method(command).call
    end
  end
end
