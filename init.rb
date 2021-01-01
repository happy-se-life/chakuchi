Redmine::Plugin.register :chakuchi do
  name 'Chakuchi plugin'
  author 'Kohei Nomura'
  description 'Chakuchi plugin shows estimated completion date of the version.'
  version '0.0.1'
  url 'https://github.com/happy-se-life/chakuchi'
  author_url 'mailto:kohei_nom@yahoo.co.jp'

  # Display menu item at the project
  menu :project_menu, :display_tab, { :controller => 'chakuchi', :action => 'index' }, :caption => :chakuchi_menu_caption, :param => :project_id

  # Enable permission for the project
  project_module :chakuchi do
    permission :display_tab, {:chakuchi => [:index]}
  end
end
