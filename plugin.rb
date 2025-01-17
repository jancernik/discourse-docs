# frozen_string_literal: true

# name: discourse-docs
# about: A plugin to make it easy to explore and find knowledge base documents in Discourse
# version: 0.1
# author: Justin DiRose
# url: https://github.com/discourse/discourse-docs
# transpile_js: true

enabled_site_setting :docs_enabled

register_asset "stylesheets/common/docs.scss"
register_asset "stylesheets/mobile/docs.scss"

register_svg_icon "sort-alpha-down"
register_svg_icon "sort-alpha-up"
register_svg_icon "sort-numeric-up"
register_svg_icon "sort-numeric-down"
register_svg_icon "far-circle"

load File.expand_path("lib/docs/engine.rb", __dir__)
load File.expand_path("lib/docs/query.rb", __dir__)

GlobalSetting.add_default :docs_path, "docs"

module ::Docs
  PLUGIN_NAME = "discourse-docs"
end

after_initialize do
  require_dependency "search"

  if SiteSetting.docs_enabled
    if Search.respond_to? :advanced_filter
      Search.advanced_filter(/in:(kb|docs)/) do |posts|
        selected_categories = SiteSetting.docs_categories.split("|")
        if selected_categories
          categories = Category.where("id IN (?)", selected_categories).pluck(:id)
        end

        selected_tags = SiteSetting.docs_tags.split("|")
        tags = Tag.where("name IN (?)", selected_tags).pluck(:id) if selected_tags

        posts.where(
          "category_id IN (?) OR topics.id IN (SELECT DISTINCT(tt.topic_id) FROM topic_tags tt WHERE tt.tag_id IN (?))",
          categories,
          tags,
        )
      end
    end
  end

  add_to_class(:topic_query, :list_docs_topics) { default_results(@options) }

  on(:robots_info) do |robots_info|
    robots_info[:agents] ||= []

    any_user_agent = robots_info[:agents].find { |info| info[:name] == "*" }
    if !any_user_agent
      any_user_agent = { name: "*" }
      robots_info[:agents] << any_user_agent
    end

    any_user_agent[:disallow] ||= []
    any_user_agent[:disallow] << "/#{GlobalSetting.docs_path}/"
  end

  add_to_serializer(:site, :docs_path) { GlobalSetting.docs_path }
end
