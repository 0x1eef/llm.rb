# frozen_string_literal: true

class LLM::Function
  ##
  # The {LLM::Function::Ractor::Job} class manages execution and mailbox
  # coordination for a single ractor-backed function call.
  class Ractor::Job
    ##
    # @param [::Ractor] mailbox
    # @param [Class] runner_class
    # @param [String, nil] id
    # @param [String] name
    # @param [Hash, Array, nil] arguments
    # @return [LLM::Function::Ractor::Job]
    def initialize(mailbox, runner_class, id, name, arguments)
      @mailbox = mailbox
      @runner_class = runner_class
      @id = id
      @name = name
      @arguments = arguments
    end

    ##
    # @return [void]
    def call
      spawn
      wait
    end

    private

    def wait
      done = false
      result = nil
      waiters = []
      loop do
        case ::Ractor.receive
        in [:done, *data]
          result ||= data
          done = true
          waiters.each { _1.send(result) }
          break unless waiters.empty?
          waiters.clear
        in [:alive?, reply]
          reply.send(!done)
        in [:wait, reply]
          if done
            reply.send(result)
            break
          else
            waiters << reply
          end
        in [:interrupt]
          @tool&.send(:interrupt)
        end
      end
    end

    def spawn
      @tool = ::Ractor.new(@mailbox, @runner_class, @id, @name, @arguments) do |mailbox, runner_class, id, name, arguments|
        ::Thread.new do
          ::Ractor.receive == :interrupt or next
          ::Thread.main.raise(LLM::Interrupt)
        rescue ::Ractor::Error
        end
        kwargs = Hash === arguments ? arguments.transform_keys(&:to_sym) : arguments
        mailbox.send([:done, id, name, runner_class.new.call(**kwargs)])
      rescue LLM::Interrupt
        mailbox.send([:done, id, name, {cancelled: true, reason: "interrupted"}])
      rescue => ex
        mailbox.send([:done, id, name, {error: true, type: ex.class.name, message: ex.message}])
      end
    end
  end
end
