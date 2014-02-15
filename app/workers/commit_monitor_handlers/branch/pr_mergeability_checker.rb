class CommitMonitorHandlers::Branch::PrMergeabilityChecker
  include Sidekiq::Worker

  def self.handled_branch_modes
    [:pr]
  end

  attr_reader :branch

  def perform(branch_id)
    @branch = CommitMonitorBranch.find(branch_id)
    return unless branch.pull_request?
    process_mergeability
  end

  private

  def process_mergeability
    was_mergeable = branch.mergeable?
    currently_mergeable = branch.repo.with_git_service do |git|
      git.mergeable?(branch.name, "master")
    end

    write_to_github if was_mergeable && !currently_mergeable

    branch.update_attributes!(:mergeable => currently_mergeable)
  end

  def write_to_github
    logger.info("#{self.class.name}##{__method__} Updating pull request #{branch.pr_number} with merge issue.")

    GithubService.call(:repo => branch.repo) do |github|
      github.issues.comments.create(
        :issue_id => branch.pr_number,
        :body     => "This pull request is not mergeable.  Please rebase and repush."
      )
    end
  end
end
