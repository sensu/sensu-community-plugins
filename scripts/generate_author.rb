require 'rubygems'
require 'git'
require 'logger'
require 'digest/md5'
require 'erb'

def find_all_authors
  g = Git.open(Dir.pwd)
  authors = {}
  g.object('master').log(1000000).each do |commit|
    authors[commit.author.email] ||= Author.new(commit.author)
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
  attr_accessor :commits
  attr :email
  attr :name
  attr :id

  def initialize(author)
    @commits = []
    @email = author.email
    @name = author.name
    @id = Digest::MD5.hexdigest(@email.downcase)
  end
  
  def same_as(other)
    other.name == name || other.email == email
  end

  def pretty_name
    first, last = name.split
    pretty_name = first
    pretty_name << " #{last.to_s[0..0]}." if last
    pretty_name
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

  def download_gravatar(dest)
    `wget #{gravatar_url} -O #{dest}`
  end
end

class CommitCounter
  attr_accessor :authors
  
  def initialize
    @authors = []
  end
  
  def add(author)
    index = authors.index { |p| p.same_as(author) }
    if index
      authors[index].commits += author.commits
    else
      authors << author
    end
  end
  
  def count
    sorted = authors.sort_by { |p| - p.commits.length }
  end
end

#desc 'Generate HTML pages.'
#task :default do
  counter = CommitCounter.new
  find_all_authors.each do |auth|
    counter.add auth
  end
  
  authors = counter.count
  
  authors.each do |author|
    file = "images/#{author.id}"
    author.download_gravatar(file) unless File.exists?(file)
  end

  write_template('templates/author.erb', 'author.html', binding())
#end
