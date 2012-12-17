require 'rubygems'
require 'git'
require 'logger'
require 'digest/md5'
require 'erb'

def download_gravatar(email, dest)
  `wget #{email_to_gravatar_url(email)} -O #{dest}`
end

def find_all_authors
  g = Git.open(Dir.pwd)
  authors = {}
  g.log(1000000).each do |commit|
    authors[commit.author.email] ||= Author.new(commit.author.email)
    authors[commit.author.email].commits << commit
  end
  authors.values.sort{|x,y| y.commits.length <=> x.commits.length}
end

def write_template(template, dest, var_binding)
  renderer = ERB.new(File.read(template))
  output = renderer.result(var_binding)  
  f = File.open(dest, 'w')
  f.write(output)
  f.close()  
end

class Author
  attr :commits
  attr :email
  attr :id

  def initialize(email)
    @commits = []
    @email = email
    @id = Digest::MD5.hexdigest(@email.downcase)
  end

  def files_changed
    files = []
    commits.each do |commit|      
      commit.diff_parent.each do |diff|
        files << diff.path
      end
    end
    files.uniq.sort
  rescue
    []
  end

  def handlers_changed
    @handlers_changed ||= files_changed.select{|path| path.match('handlers')}.sort
    @handlers_changed
  end

  def plugins_changed
    @plugins_changed ||= files_changed.select{|path| path.match('plugins')}.sort
    @plugins_changed
  end

  def gravatar_url
    hash = Digest::MD5.hexdigest(@email.downcase)
    default = 'https://secure.gravatar.com/avatar/f944437e121d4e1efc45dfaec2651550'
    "http://www.gravatar.com/avatar/#{hash}?d=#{default}"    
  end
end

desc "Generate HTML pages."
task :default do
  authors = find_all_authors()

  authors.each do |author|
    file = "images/#{author.id}"
    download_gravatar(author.email, file) unless File.exists?(file)
  end

  write_template('templates/index.erb', 'index.html', binding())
end
