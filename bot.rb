# rubocop:disable Metrics/BlockLength
# require 'dotenv/load' # leave this line commented while working with heroku
require 'facebook/messenger'
require 'sinatra'
require_relative 'rubotnik/rubotnik'
require_relative 'helpers/helpers'
include Facebook::Messenger
include Helpers # mixing helpers into the common namespace
# so they can be used outside of Dispatches

############# START UP YOUR BOT, SET UP GREETING AND MENU ###################

# NB: Subcribe your bot to your page here.
Facebook::Messenger::Subscriptions.subscribe(access_token: ENV['ACCESS_TOKEN'])

# Enable "Get Started" button, greeting and persistent menu for your bot
# Rubotnik::BotProfile.enable
# Rubotnik::PersistentMenu.enable

####################### ROUTE MESSAGES HERE ################################

Bot.on :message do |message|
  Rubotnik::MessageDispatch.new(message).route do

    bind 'ok', 'fine', 'got it', 'more', 'next', 'thanks', 'cool' do
      say "Ask another question!"
    end

    bind 'hello', 'hey', 'yo', 'hi' do
     say 'Hi! I can make decisions for you. I understand different kinds of questions'
    end

    wit_bind to: :nlu_handle_questions

    # default do
    #   say "ok"
    # end

  end
end

######################## ROUTE POSTBACKS HERE ###############################

Bot.on :postback do |postback|
  Rubotnik::PostbackDispatch.new(postback).route do

  end
end

#############################################################################

get '/' do
  'Nothing to look at'
end
