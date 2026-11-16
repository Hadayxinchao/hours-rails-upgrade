namespace :paperclip do
  desc "Copy Paperclip client logos into Active Storage for every tenant (idempotent)"
  task migrate_logos: :environment do
    PaperclipLogoMigration.new.run
  end
end
