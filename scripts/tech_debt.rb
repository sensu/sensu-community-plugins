require 'github_api'

sensu_path = ''
Dir.chdir sensu_path

tech_debt_yellow = 'YELLOW'
tech_debt_orange = 'ORANGE'
tech_debt_red = 'RED'

github = Github.new do |c|
  c.oauth_token = ''
end

yellow_debt = ''
orange_debt = ''
red_debt = ''

Dir.glob('**/*').each do |file|
  next unless File.file?(file)
  File.open(file) do |f|
    f.each_line do |line|
      yellow_debt << "* #{ file } #YELLOW\n" if line.include?(tech_debt_yellow)
    end
  end
end

Dir.glob('**/*').each do |file|
  next unless File.file?(file)
  File.open(file) do |f|
    f.each_line do |line|
      orange_debt << "* #{ file } #ORANGE\n" if line.include?(tech_debt_orange)
    end
  end
end

Dir.glob('**/*').each do |file|
  next unless File.file?(file)
  File.open(file) do |f|
    f.each_line do |line|
      red_debt << "* #{ file } #RED\n" if line.include?(tech_debt_red)
    end
  end
end

github.issues.edit user: 'sensu',
repo: 'sensu-community-plugins',
number: '891',
body: "#{ yellow_debt }"

github.issues.edit user: 'sensu',
repo: 'sensu-community-plugins',
number: '892',
body: "#{ orange_debt }"

github.issues.edit user: 'sensu',
repo: 'sensu-community-plugins',
number: '893',
body: "#{ red_debt }"
