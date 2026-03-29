#
#  xunsu.rb
#  Xunsu
#
#  Created by Yefga on 29/03/26.
#

class Xunsu < Formula
  desc "Swift-native iOS/macOS automation tool"
  homepage "https://github.com/yefga/Xunsu"
  url "https://github.com/yefga/Xunsu/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "7cbc299e20b5a1f15bf0b9a538fa4ef04838d4e2946b420a95cf5d97a5a04b83"
  license "MIT"

  depends_on xcode: ["16.0", :build]
  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/xunsu"
  end

  test do
    assert_match "0.1.0", shell_output("#{bin}/xunsu --version")
  end
end
