cask "elite" do
  version "1.3.1"
  sha256 "2452a5a486b6b772c323a6c0647e9c217a9c7c55e0fe4f2df768073bc1541ad2"

  url "https://raw.githubusercontent.com/stephenlclarke/elite/1ef005e0c73971a360a0e3bb52792a9286a761d3/releases/macos/Elite-#{version}-universal.zip"
  name "Elite"
  desc "Space trading and combat game inspired by BBC Micro Elite"
  homepage "https://github.com/stephenlclarke/elite"

  livecheck do
    skip "Published archives are pinned to a reviewed repository commit"
  end

  depends_on macos: :sonoma

  app "Elite.app"
end
