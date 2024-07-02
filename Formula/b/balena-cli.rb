require "language/node"

class BalenaCli < Formula
  desc "Command-line tool for interacting with the balenaCloud and balena API"
  homepage "https://www.balena.io/docs/reference/cli/"
  url "https://registry.npmjs.org/balena-cli/-/balena-cli-18.2.13.tgz"
  sha256 "38e0de302895a816fbcca18ed4264e054aecefd688c20a2d7afc5caf3027110e"
  license "Apache-2.0"

  livecheck do
    url "https://registry.npmjs.org/balena-cli/latest"
    regex(/["']version["']:\s*?["']([^"']+)["']/i)
  end

  bottle do
    sha256                               arm64_sonoma:   "a7730902a08680aa986d6655f8a3a4abe3bcc62de313147db396ad0b09fe7224"
    sha256                               arm64_ventura:  "84cf7b867a7421f0503d4e5954f70d3196b01783315c90b30ac6621877d6548c"
    sha256                               arm64_monterey: "35debb8aafab2f2defd61c64db4196adb8be81a53b593b8e78a13afc2fd40e03"
    sha256                               sonoma:         "c9b4613d4b85b80a5153080efa0bf28736afa15473a1c29f19800ef4e7eb7566"
    sha256                               ventura:        "f58196d11326c3bf83953003dcab29cad329fa59cc8d4cfa673630b32d4bd7c1"
    sha256                               monterey:       "d28c1e90ab0ea6ecc9a8a247d66a41fce535bb8b6cf8a9de396a705f09bd24aa"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "6cd26a6b96c4304b6e507ce16ec8243860fe560df4d45b89657a6a3eba26077d"
  end

  # need node@20, and also align with upstream, https://github.com/balena-io/balena-cli/blob/master/.github/actions/publish/action.yml#L21
  depends_on "node@20"

  on_macos do
    depends_on "macos-term-size"
  end

  on_linux do
    depends_on "libusb"
    depends_on "systemd" # for libudev
    depends_on "xz" # for liblzma
  end

  def install
    ENV.deparallelize

    system "npm", "install", *Language::Node.std_npm_install_args(libexec)
    bin.install_symlink Dir["#{libexec}/bin/*"]

    # Remove incompatible pre-built binaries
    os = OS.kernel_name.downcase
    arch = Hardware::CPU.intel? ? "x64" : Hardware::CPU.arch.to_s
    node_modules = libexec/"lib/node_modules/balena-cli/node_modules"
    node_modules.glob("{ffi-napi,ref-napi}/prebuilds/*")
                .each { |dir| dir.rmtree if dir.basename.to_s != "#{os}-#{arch}" }

    (node_modules/"lzma-native/build").rmtree
    (node_modules/"usb").rmtree if OS.linux?

    term_size_vendor_dir = node_modules/"term-size/vendor"
    term_size_vendor_dir.rmtree # remove pre-built binaries

    if OS.mac?
      macos_dir = term_size_vendor_dir/"macos"
      macos_dir.mkpath
      # Replace the vendored pre-built term-size with one we build ourselves
      ln_sf (Formula["macos-term-size"].opt_bin/"term-size").relative_path_from(macos_dir), macos_dir

      unless Hardware::CPU.intel?
        # Replace pre-built x86_64 binaries with native binaries
        %w[denymount macmount].each do |mod|
          (node_modules/mod/"bin"/mod).unlink
          system "make", "-C", node_modules/mod
        end
      end
    end

    # Replace universal binaries with native slices
    deuniversalize_machos
  end

  test do
    ENV.prepend_path "PATH", Formula["node@20"].bin

    assert_match "Logging in to balena-cloud.com",
      shell_output("#{bin}/balena login --credentials --email johndoe@gmail.com --password secret 2>/dev/null", 1)
  end
end
