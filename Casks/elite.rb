cask "elite" do
  version "1.4.0"
  sha256 "a9e8a165eac6a8c483ec71b73992ad838c13b606232d45aee4fe236e6655ed7a"

  # Artifact commit: bba862c558530ea2d40d634f84fbd490d9cc3401
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
