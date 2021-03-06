#!/bin/bash

/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

brew install ccache
brew install fish
brew install cmake
brew install node
brew install python@2
brew install ruby
brew install jq

gem install rspec
gem install httparty
gem install persistent_httparty

brew upgrade
brew link --overwrite python@2
