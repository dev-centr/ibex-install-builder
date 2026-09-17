# frozen_string_literal: true

class Ibex < Formula
  desc "Install Builder Extension — author packages and put tools on PATH"
  homepage "https://github.com/dev-centr/ibex-install-builder"
  version "0.2.0"
  license "MIT"

  on_macos do
    url "https://github.com/dev-centr/ibex-install-builder/releases/download/v#{version}/ibex-macos-amd64"
    sha256 "7e1ca47ee91a4e84d1e6f9c265458bc9ed3bf808c96e92376efbb62a8e7509cf"
  end

  on_linux do
    url "https://github.com/dev-centr/ibex-install-builder/releases/download/v#{version}/ibex-linux-amd64"
    sha256 "c5af04972acc0380da8006f5957fb3e2b2d7f0073a38f1c458250ee1fb2cce9e"
  end

  def install
    binary = Dir["ibex-*"].first || "ibex-macos-amd64"
    chmod 0755, binary if File.exist?(binary)
    bin.install binary => "ibex"
  end

  test do
    assert_match "ibex", shell_output("#{bin}/ibex --version")
  end
end
