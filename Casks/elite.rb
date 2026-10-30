cask "elite" do
  version "1.5.1"
  sha256 "8398f6b03e44796ecc88ba3ad0b28a9d72fffd5f9d47a96d43942de0d51b941b"

  # Source commit: e691630ccc3065748d4c02e90eed6a333da0d8b1
  url "https://github.com/stephenlclarke/elite/releases/download/v#{version}/Elite-#{version}-universal.zip"
  name "Elite"
  desc "Space trading and combat game inspired by BBC Micro Elite"
  homepage "https://github.com/stephenlclarke/elite"

  livecheck do
    url :homepage
    strategy :github_latest
  end

  depends_on macos: :sonoma

  app "Elite.app"
end
