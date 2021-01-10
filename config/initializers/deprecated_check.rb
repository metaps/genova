raise Genova::Exceptions::MigrationError, "Add 'GITHUB_ACCOUNT' to your .env file." if ENV.fetch('GITHUB_ACCOUNT', '').blank?

