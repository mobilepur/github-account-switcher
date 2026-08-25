cask "github-account-switcher" do
  version :latest
  sha256 :no_check

  url "https://github.com/mobilepur/github-account-switcher/releases/latest/download/GitHub-Account-Switcher.tar.gz"
  name "GitHub Account Switcher"
  desc "Switch GitHub CLI accounts and SSH identities from the menu bar"
  homepage "https://github.com/mobilepur/github-account-switcher"

  depends_on formula: "gh"
  depends_on macos: :sonoma

  app "GitHub Account Switcher.app"
  binary "gh-switcher"
end
