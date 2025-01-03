class Autobrr < Formula
  desc "Modern, easy to use download automation for torrents and usenet"
  homepage "https://autobrr.com/"
  url "https://github.com/autobrr/autobrr/archive/refs/tags/v1.56.0.tar.gz"
  sha256 "6cfe24dbe44d4cbe30da3da342654820628e82a905f72b05301f4c9f7dc02317"
  license "GPL-2.0-or-later"

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "e8cef40004e529398cc8bd489971b783f4534c764e201dee1c02d781a699e373"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "e8cef40004e529398cc8bd489971b783f4534c764e201dee1c02d781a699e373"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "e8cef40004e529398cc8bd489971b783f4534c764e201dee1c02d781a699e373"
    sha256 cellar: :any_skip_relocation, sonoma:        "da8cf21bfd06e5eb8cb8e49f2e408b24bb4502fd667b80094e2f1e553704efcb"
    sha256 cellar: :any_skip_relocation, ventura:       "da8cf21bfd06e5eb8cb8e49f2e408b24bb4502fd667b80094e2f1e553704efcb"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "49d9908f5cd659fba815bd5e2b9d14c39faeeebf3d8566308ac52a2ff570f6c9"
  end

  depends_on "go" => :build
  depends_on "node" => :build
  depends_on "pnpm" => :build

  def install
    system "pnpm", "install", "--dir", "web"
    system "pnpm", "--dir", "web", "run", "build"

    ldflags = "-s -w -X main.version=#{version} -X main.commit=#{tap.user}"

    system "go", "build", *std_go_args(output: bin/"autobrr", ldflags:), "./cmd/autobrr"
    system "go", "build", *std_go_args(output: bin/"autobrrctl", ldflags:), "./cmd/autobrrctl"
  end

  def post_install
    (var/"autobrr").mkpath
  end

  service do
    run [opt_bin/"autobrr", "--config", var/"autobrr/"]
    keep_alive true
    log_path var/"log/autobrr.log"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/autobrrctl version")

    port = free_port

    (testpath/"config.toml").write <<~TOML
      host = "127.0.0.1"
      port = #{port}
      logLevel = "INFO"
      checkForUpdates = false
      sessionSecret = "secret-session-key"
    TOML

    pid = fork do
      exec bin/"autobrr", "--config", "#{testpath}/"
    end
    sleep 4

    begin
      system "curl", "-s", "--fail", "http://127.0.0.1:#{port}/api/healthz/liveness"
    ensure
      Process.kill("TERM", pid)
      Process.wait(pid)
    end
  end
end
