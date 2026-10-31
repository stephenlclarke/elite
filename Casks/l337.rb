cask "l337" do
  version "1.6.0"
  sha256 "f8e3ee6aaa785975273ee959635c0a9b1dca14f0d7c181cdfb6edb7db7b777a2"

  # Source commit: 05b3cd499058b1d2b2b532dd79a1018fae61c1bc
  url "https://github.com/stephenlclarke/l337/releases/download/v#{version}/L337-#{version}-universal.zip"
  name "L337"
  desc "Space trading and combat game inspired by BBC Micro Elite"
  homepage "https://github.com/stephenlclarke/l337"

  livecheck do
    url :homepage
    strategy :github_latest
  end

  depends_on macos: :sonoma

  app "L337.app"
end
