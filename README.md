# Valkyrie::CloudSearch

An Amazon Web Services CloudSearch metadata backend for [Valkyrie](https://github.com/samvera-labs/valkyrie)

[![CircleCI](https://circleci.com/gh/samvera-labs/valkyrie-cloud_search.svg?style=svg)](https://circleci.com/gh/samvera-labs/valkyrie-cloud_search)
[![Coverage Status](https://coveralls.io/repos/github/samvera-labs/valkyrie-cloud_search/badge.svg?branch=master)](https://coveralls.io/github/samvera-labs/valkyrie-cloud_search?branch=master)

## Requirements

### Ruby version
Ruby 2.3 or above

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'valkyrie-cloud_search'
```

## Usage

Follow the Valkyrie README to get a development or production environment up and running. To enable CloudSearch support,
add the following to your application's `config/initializers/valkyrie.rb`:

    Valkyrie::MetadataAdapter.register(
      Valkyrie::Persistence::CloudSearch::MetadataAdapter.new(
          cloud_search: Aws::CloudSearchDomain::Client.new(endpoint: CLOUDSEARCH_ENDPOINT),
          redis: Redis.new(host: REDIS_ELASTICACHE_ENDPOINT)
      ),
      :cloud_search
    )

You can then use `:cloud_search` as a metadata adapter value in `config/valkyrie.yml`

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/samvera-labs/valkyrie-cloud_search/.

## License

`Valkyrie::CloudSearch` is available under [the Apache 2.0 license](LICENSE).
