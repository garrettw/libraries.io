module PackageManager
  class Drupal < Base
    URL = 'https://www.drupal.org'
    COLOR = '#4F5D95'

    def self.package_link(project, version = nil)
      "https://www.drupal.org/project/#{project.name}" + (version ? "/releases/#{version}" : "")
    end

    def self.project_names
      get_html("https://www.drupal.org/project/project_module/index").css('.view-project-index .view-content li').map{|li| li.css('a').first.try(:text) }
    end

    def self.recent_names
      u = 'https://www.drupal.org/project/project_module/feed/all'
      new_packages = SimpleRSS.parse(get_raw(u)).items.map(&:title)
      (updated.map { |t| t.split(' ').first } + new_packages).uniq
    end

    def self.project(name)
      {
        name: name,
        page: get_html("https://www.drupal.org/project/#{name}")
      }
    end

    def self.mapping(project)
      return false unless project["versions"].any?
      # for version comparison of php, we want to reject any dev versions unless
      # there are only dev versions of the project
      versions = project["versions"].values.reject {|v| v["version"].include? "dev" }
      if versions.empty?
        versions = project["versions"].values
      end
      # then we'll use the most recently published as our most recent version
      latest_version = versions.sort_by { |v| v["time"] }.last
      {
        :name =>  latest_version['name'],
        :description => latest_version['description'],
        :homepage => latest_version['home_page'],
        :keywords_array => Array.wrap(latest_version['keywords']),
        :licenses => latest_version['license'].join(','),
        :repository_url => repo_fallback(project['repository'],latest_version['home_page']),
        :versions => project["versions"]
      }
    end
  end
end
