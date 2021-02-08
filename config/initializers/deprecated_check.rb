raise Genova::Exceptions::MigrationError, "Add 'GITHUB_ACCOUNT' to your .env file." if ENV.fetch('GITHUB_ACCOUNT', '').blank?
raise Genova::Exceptions::MigrationError, "Add 'SLACK_HOST' to your .env file." if ENV.fetch('SLACK_HOST', '').blank?
raise Genova::Exceptions::MigrationError, "Add 'SLACK_PORT' to your .env file." if ENV.fetch('SLACK_PORT', '').blank?
