# IiifToJekyll

IiifToJekyll is designed to produce a static digital edition site from the 
Readux digital editing platform.  The library reads from a IIIF manifest and
annotation server, writing to a Jekyll template/theme directory.

## Dependencies

IiifToJekyll currently depends on a IIIF Bundle exported from Readux as its input 
manifest (while pulling annotations from the live Readux site), but should
be adaptible to work with any IIIF manifest and set of annotations.

IiifToJekyll adds data files to a Jekyll theme directory extracted from
https://github.com/ecds/digitaledition-jekylltheme

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'iiif_to_jekyll'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install iiif_to_jekyll

## Usage

For command-line usage, run 
	$ ./bin/iiif_to_jekyll export_dir digitaledition-jekylltheme_dir

After this has been run, you can see your exported edition:
	$ cd digitaledition-jekylltheme_dir
	$ bundle update
	$ jekyll serve

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

