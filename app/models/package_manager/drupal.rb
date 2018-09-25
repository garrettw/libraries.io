module PackageManager
  class Drupal < Base
    URL = 'https://www.drupal.org'
    COLOR = '#4F5D95'

    def self.project_names
      get_html("https://www.drupal.org/project/project_module/index").css('.view-project-index .view-content li').map{|li| li.css('a').first.try(:text) }
    end

    def self.project(name)
      {
        name: name,
        page: get_html("https://www.drupal.org/project/#{name}")
      }
    end

    def self.mapping(project)
      {
        name: project[:name],
        keywords_array: Array(project[:page].css('#content div:first a')[1..-1].map(&:text)),
        description: description(project[:page]),
        licenses: find_attribute(project[:page], 'License'),
        homepage: find_attribute(project[:page], 'Home page'),
        repository_url: repo_fallback(repository_url(find_attribute(project[:page], 'Source repository')), find_attribute(project[:page], 'Home page'))
      }
    end

    def self.versions(project)
      versions = find_attribute(project[:page], 'Versions')
      versions = find_attribute(project[:page], 'Version') if versions.nil?
      versions.delete('(info)').split(',').map(&:strip).map do |v|
        {
          :number => v
        }
      end
    end
    
    def self.dependencies(name, version, _project)
      json = get_json("https://lib.haxe.org/p/#{name}/#{version}/raw-files/haxelib.json")
      return [] unless json['dependencies']
      json['dependencies'].map do |dep_name, dep_version|
        {
          project_name: dep_name,
          requirements: dep_version.empty? ? '*' : dep_version,
          kind: 'runtime',
          platform: self.name.demodulize
        }
      end
    rescue
      []
    end

    def self.recent_names
      u = 'https://www.drupal.org/project/project_module/feed/all'
      
      titles = SimpleRSS.parse(get_raw(u)).items.map(&:title)
      titles.map { |t| t.split(' ').first }.uniq
      
      new_packages = SimpleRSS.parse(get_raw(u)).items.map(&:title)
      (updated.map { |t| t.split(' ').first } + new_packages).uniq
    end
    
    def self.install_instructions(project, version = nil)
      "gem install #{project.name}" + (version ? " -v #{version}" : "")
    end

    def self.package_link(project, version = nil)
      "https://www.drupal.org/project/#{project.name}" + (version ? "/releases/#{version}" : "")
    end
    
    def self.download_url(name, version = nil)
      "https://rubygems.org/downloads/#{name}-#{version}.gem"
    end
    
    def self.documentation_url(name, version = nil)
      "http://www.rubydoc.info/gems/#{name}/#{version}"
    end
  end
end
