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
    bin.install ".build/release/gh-switcher-menubar"
  end

  service do
    run [opt_bin/"gh-switcher-menubar"]
    keep_alive true
    process_type :interactive
  end

  test do
    assert_match "gh-switcher 0.1.0", shell_output("#{bin}/gh-switcher version")
  end
end
