module GithubService
  module Commands
    class Base
      class << self
        def inherited(subclass)
          subclass.extend(CommandMethods)

          class_name = subclass.to_s.demodulize
          subclass.register_as(class_name.underscore)
        end
      end

      class_attribute :restriction

      attr_reader :issue

      def initialize(issue)
        @issue = issue
      end

      ##
      # Public interface to Command classes
      # Subclasses of Commands::Base should implement #_execute with
      # the following keyword arguments:
      #
      # issuer - The username of the user that issued the command
      # value -  The value of the command given
      #
      # No callers should ever use _execute directly, using execute! instead.
      #
      def execute!(issuer:, value:)
        if user_permitted?(issuer)
          _execute(:issuer => issuer, :value => value)
        end
      end

      private

      def _execute
        raise NotImplementedError
      end

      def user_permitted?(issuer)
        case self.class.restriction
        when nil
          true
        when :organization
          if GithubService.organization_member?(issue.organization_name, issuer)
            true
          else
            issue.add_comment("@#{issuer} Only members of the #{issue.organization_name} organization may use this command.")
            false
          end
        end
      end

      VALID_RESTRICTIONS = [:organization].freeze

      module CommandMethods
        def register_as(command_name)
          CommandDispatcher.register_command(command_name, self)
        end
        alias alias_as register_as

        def restrict_to(restriction)
          unless VALID_RESTRICTIONS.include?(restriction)
            raise RestrictionError, "'#{restriction}' is not a valid restriction"
          end
          self.restriction = restriction
        end
      end

      RestrictionError = Class.new(StandardError)
    end
  end
end
