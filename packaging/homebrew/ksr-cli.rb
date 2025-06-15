class KsrCli < Formula
  desc "CLI tool for Kafka Schema Registry"
  homepage "https://github.com/aywengo/ksr-cli"
  url "https://github.com/aywengo/ksr-cli/releases/download/v1.0.0/ksr-cli-darwin-amd64.tar.gz"
  sha256 "SHA256_PLACEHOLDER"
  license "MIT"
  version "1.0.0"

  depends_on "go" => :build

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/aywengo/ksr-cli/releases/download/v1.0.0/ksr-cli-darwin-amd64.tar.gz"
      sha256 "AMD64_SHA256_PLACEHOLDER"
    end
    if Hardware::CPU.arm?
      url "https://github.com/aywengo/ksr-cli/releases/download/v1.0.0/ksr-cli-darwin-arm64.tar.gz"
      sha256 "ARM64_SHA256_PLACEHOLDER"
    end
  end

  def install
    bin.install "ksr-cli"
    
    # Generate and install shell completions
    output = Utils.safe_popen_read("#{bin}/ksr-cli", "completion", "bash")
    (bash_completion/"ksr-cli").write output
    
    output = Utils.safe_popen_read("#{bin}/ksr-cli", "completion", "zsh")
    (zsh_completion/"_ksr-cli").write output
    
    output = Utils.safe_popen_read("#{bin}/ksr-cli", "completion", "fish")
    (fish_completion/"ksr-cli.fish").write output
  end

  test do
    # Test basic functionality
    system "#{bin}/ksr-cli", "help"
    
    # Test version output
    assert_match version.to_s, shell_output("#{bin}/ksr-cli --version")
    
    # Test config command (should work without registry)
    system "#{bin}/ksr-cli", "config", "--help"
  end
end
