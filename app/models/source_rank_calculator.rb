class SourceRankCalculator
  def initialize(project, max_dependent_projects: nil, max_dependent_repositories: nil, max_stars: nil, max_forks: nil, max_watchers: nil)
    @project = project
    @max_dependent_projects = max_dependent_projects
    @max_dependent_repositories = max_dependent_repositories
    @max_stars = max_stars
    @max_forks = max_forks
    @max_watchers = max_watchers
  end

  def self.maximums(platform)
    {
      max_stars: max_stars(platform),
      max_dependent_projects:max_dependent_projects(platform),
      max_dependent_repositories: max_dependent_repositories(platform),
      max_forks: max_forks(platform),
      max_watchers: max_watchers(platform)
    }
  end

  def overall_score
    (overall_scores.values.sum/overall_scores.values.length.to_f).round
  end

  def popularity_score
    popularity_scores.values.sum/popularity_scores.values.length.to_f
  end

  def community_score
    community_scores.values.sum/community_scores.values.length.to_f
  end

  def quality_score
    quality_scores.values.sum/quality_scores.values.length.to_f
  end

  def dependencies_score
    dependencies_scores.values.sum/dependencies_scores.values.length.to_f
  end

  def breakdown
    {
      overall_score: overall_score,
      popularity: {
        score: popularity_score,
        dependent_projects: dependent_projects_score,
        dependent_repositories: dependent_repositories_score,
        stars: stars_score,
        forks: forks_score,
        watchers: watchers_score
      },
      community: {
        score: community_score,
        contribution_docs: contribution_docs,
        recent_releases: recent_releases_score,
        brand_new: brand_new_score,
        contributors: contributors_score,
        maintainers: maintainers_score
      },
      quality: {
        score: quality_score,
        basic_info: basic_info,
        status: status_score,
        multiple_versions: multiple_versions_score,
        semver: semver_score,
        stable_release: stable_release_score
      },
      dependencies: {
        score: dependencies_score,
        outdated_dependencies: outdated_dependencies_score,
        dependencies_count: dependencies_count_score,
        direct_dependencies: direct_dependencies_scores
      }
    }
  end

  def basic_info_score
    basic_info.values.select{|v| v}.length/basic_info.values.length.to_f*100
  end

  def contribution_docs_score
    contribution_docs.values.select{|v| v}.length/contribution_docs.values.length.to_f*100
  end

  def dependent_projects_score
    return 0 if max_dependent_projects.zero?
    Math.log10(@project.dependents_count)/Math.log10(max_dependent_projects)*100
  end

  def dependent_repositories_score
    return 0 if max_dependent_repositories.zero?
    Math.log10(@project.dependent_repos_count)/Math.log10(max_dependent_repositories)*100
  end

  def stars_score
    return 0 if max_stars.zero?
    Math.log10(@project.stars)/Math.log10(max_stars)*100
  end

  def forks_score
    return 0 if max_forks.zero?
    Math.log10(@project.forks)/Math.log10(max_forks)*100
  end

  def watchers_score
    return 0 if max_watchers.to_f.zero?
    Math.log10(@project.watchers)/Math.log10(max_watchers)*100
  end

  def status_score
    inactive_statuses.include?(@project.status) ? 0 : 100
  end

  def recent_releases_score
    return 0 unless published_releases.length > 0
    published_releases.any? {|v| v.published_at && v.published_at > 6.months.ago } ? 100 : 0
  end

  def brand_new_score
    return 0 unless published_releases.length > 0
    published_releases.any? {|v| v.published_at && v.published_at < 6.months.ago } ? 100 : 0
  end

  def semver_score
    published_releases.sort_by(&:published_at).last(10).all?(&:follows_semver?) ? 100 : 0
  end

  def multiple_versions_score
    return 0 if @project.versions_count < 2
    return 100 if @project.versions_count > 5
    50
  end

  def stable_release_score
    published_releases.any?(&:greater_than_1?) ? 100 : 0
  end

  def contributors_score
    return 0 if @project.contributions_count < 2
    return 100 if @project.contributions_count > 5
    50
  end

  def maintainers_score
    return 0 if @project.registry_users.size < 2
    return 100 if @project.registry_users.size > 5
    50
  end

  def outdated_dependencies_score
    return 100 unless has_versions?
    latest_version.try(:any_outdated_dependencies?) ? 0 : 100
  end

  def dependencies_count_score
    return 100 unless has_versions?
    return 0 if direct_dependencies.length > 100
    100 - direct_dependencies.length
  end

  def direct_dependencies_score
    return 100 unless has_versions?
    dep_scores = direct_dependencies.map(&:sourcerank_2).compact
    return 100 if dep_scores.empty?
    dep_scores.sum/dep_scores.length
  end

  def direct_dependencies_scores
    Hash[direct_dependencies.collect { |d| [d.project_name, d.sourcerank_2] } ]
  end

  def self.max_stars(platform)
    Project.platform(platform)
           .joins(:repository)
           .order('repositories.stargazers_count DESC NULLS LAST')
           .limit(1)
           .pluck(:stargazers_count)
           .first || 0
  end

  def self.max_dependent_projects(platform)
    Project.platform(platform)
           .order('dependents_count DESC NULLS LAST')
           .limit(1)
           .pluck(:dependents_count)
           .first || 0
  end

  def self.max_dependent_repositories(platform)
    Project.platform(platform)
           .order('dependent_repos_count DESC NULLS LAST')
           .limit(1)
           .pluck(:dependent_repos_count)
           .first || 0
  end

  def self.max_forks(platform)
    Project.platform(platform)
           .joins(:repository)
           .order('repositories.forks_count DESC NULLS LAST')
           .limit(1)
           .pluck(:forks_count)
           .first || 0
  end

  def self.max_watchers(platform)
    Project.platform(platform)
           .joins(:repository)
           .order('repositories.subscribers_count DESC NULLS LAST')
           .limit(1)
           .pluck(:subscribers_count)
           .first || 0
  end

  private

  def has_versions?
    @project.versions_count > 0
  end

  def latest_version
    @latest_version ||= @project.latest_version
  end

  def direct_dependencies
    return [] unless has_versions?
    latest_version.runtime_dependencies
  end

  def published_releases
    @published_releases ||= has_versions? ? @project.versions : @project.tags.published
  end

  def inactive_statuses
    ["Deprecated", "Removed", "Unmaintained", "Hidden"]
  end

  def max_dependent_projects
    @max_dependent_projects ||= self.class.max_dependent_projects(@project.platform)
  end

  def max_dependent_repositories
    @max_dependent_repositories ||= self.class.max_dependent_repositories(@project.platform)
  end

  def max_stars
    @max_stars ||= self.class.max_stars(@project.platform)
  end

  def max_forks
    @max_forks ||= self.class.max_forks(@project.platform)
  end

  def max_watchers
    @max_watchers ||= self.class.max_watchers(@project.platform)
  end

  def popularity_scores
    {
      dependent_projects: dependent_projects_score,
      dependent_repositories: dependent_repositories_score,
      stars: stars_score,
      forks: forks_score,
      watchers: watchers_score
    }
  end

  def quality_scores
    {
      basic_info: basic_info_score,
      status: status_score,
      multiple_versions: multiple_versions_score,
      semver: semver_score,
      stable_release: stable_release_score
    }
  end

  def community_scores
    {
      contribution_docs: contribution_docs_score,
      recent_releases: recent_releases_score,
      brand_new: brand_new_score,
      contributors: contributors_score,
      maintainers: maintainers_score
    }
  end

  def dependencies_scores
    {
      outdated_dependencies: outdated_dependencies_score,
      dependencies_count: dependencies_count_score,
      direct_dependencies: direct_dependencies_score
    }
  end

  def basic_info
    {
      description:    @project.description.present?,
      homepage:       @project.homepage.present?,
      repository_url: @project.repository_url.present?,
      keywords:       @project.keywords.present?,
      readme:         @project.try(:repository).try(:readme).present?,
      license:        @project.normalized_licenses.present?
    }
  end

  def contribution_docs
    {
      code_of_conduct: @project.has_coc.present?,
      contributing:    @project.has_contributing.present?,
      changelog:       @project.has_changelog.present?
    }
  end

  def overall_scores
    {
      popularity: popularity_score,
      community: community_score,
      quality: quality_score,
      dependencies: dependencies_score
    }
  end
end
