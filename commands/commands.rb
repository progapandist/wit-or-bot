require 'httparty'
require 'json'
require_relative '../ui/ui'
# Everything in this module will become private methods for Dispatch classes
# and will exist in a shared namespace.
module Commands
  class << self
    attr_accessor :nlu
  end

  def setup_understander
    @nlu = Rubotnik::WitUnderstander.new("ZI243GVZYMZFWGIFMGI4PNUNLGVFLFUZ")
  end

  def question_type(type)
    !@nlu.entity_values(@message.text, :intent).empty? &&
    @nlu.entity_values(@message.text, :intent).include?(type)
  end

  def nlu_handle_questions
    setup_understander # can't do without it to enable caching
    @message.typing_on
    if question_type('or_question')
      handle_or_question_unchecked
    elsif question_type('what_question')
      puts "what question"
      handle_what_question
    elsif question_type('where_question')
      puts "where question"
      next_command :nlu_handle_questions
    elsif question_type('who_question')
      puts "who question"
      next_command :nlu_handle_questions
    elsif question_type('when_question')
      puts "when question"
      handle_when_question
      next_command :nlu_handle_questions
    else
      say "Doesn't look like a question to me"
    end
    @message.typing_off
  end

  def handle_what_question
    @message.typing_on
    say "What are the options? Use 'or' to separate them"
    @message.typing_off
    next_command :handle_or_question_checked
  end

  def handle_when_question
    @message.typing_on
    say "When do you think? Use 'or' to separate them"
    @message.typing_off
    next_command :handle_or_question_checked
  end

  def handle_or_question_unchecked
    @message.typing_on
    choice = @nlu.entity_values(@message.text, :option).sample
    say choice
    @message.typing_off
    stop_thread
  end

  def handle_or_question_checked
    setup_understander
    if question_type('or_question')
      @message.typing_on
      choice = @nlu.entity_values(@message.text, :option).sample
      say choice
      @message.typing_off
      stop_thread
    else
      say "doesn't look like an OR question to me, try again?"
      next_command :handle_or_question_checked
    end
  end

end
