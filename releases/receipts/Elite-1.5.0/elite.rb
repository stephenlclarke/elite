cask "elite" do
  version "1.5.0"
  sha256 "c393a4bbfe1b04741393e74cf25ed587ef379d4fc21ca7e5decab14c42b1fdb1"

  # Source commit: ca2e5b2865f808e1d3c4fde4e7f076b6c7a9ce09
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
