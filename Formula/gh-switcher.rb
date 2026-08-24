class GhSwitcher < Formula
  desc "Switch GitHub CLI accounts together with their SSH keys"
  homepage "https://github.com/mobilepur/github-account-switcher"
  license "MIT"
  head "https://github.com/mobilepur/github-account-switcher.git", branch: "main"

  depends_on xcode: ["15.0", :build]
  depends_on "gh"

  def install
    system "swift", "build", "--disable-sandbox", "-c", "release"
    bin.install ".build/release/gh-switcher"
    app = prefix/"GitHub Account Switcher.app"
    (app/"Contents/MacOS").install ".build/release/gh-switcher-menubar"
    (app/"Contents").install "App/Info.plist"
    system "codesign", "--force", "--deep", "--sign", "-", app
    bin.install_symlink app/"Contents/MacOS/gh-switcher-menubar"
  end

  def caveats
    <<~EOS
      Start the menu bar app with:
        open "#{opt_prefix}/GitHub Account Switcher.app"

      You can then enable Start at Login from the menu bar settings.
    EOS
  end

  test do
    assert_match "gh-switcher 0.1.0", shell_output("#{bin}/gh-switcher version")
  end
end
