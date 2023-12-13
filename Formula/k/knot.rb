class Knot < Formula
  desc "High-performance authoritative-only DNS server"
  homepage "https://www.knot-dns.cz/"
  url "https://secure.nic.cz/files/knot-dns/knot-3.3.3.tar.xz"
  sha256 "aab40aab2acd735c500f296bacaa5c84ff0488221a4068ce9946e973beacc5ae"
  license all_of: ["GPL-3.0-or-later", "0BSD", "BSD-3-Clause", "LGPL-2.0-or-later", "MIT"]

  livecheck do
    url "https://secure.nic.cz/files/knot-dns/"
    regex(/href=.*?knot[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  bottle do
    sha256 arm64_sonoma:   "3d50a75207a416ba6af0fc428be958c6e5c5e389dfa7b6363235e78e2ad0d6b5"
    sha256 arm64_ventura:  "95b5469826dbccc6db3acbfca9810b1bf064d5b401ec4df76e9e3ce6c4fe291d"
    sha256 arm64_monterey: "3456046f61f1de341f3e843a84aac03af8941e5531b9582a16ad0e853bfcea84"
    sha256 sonoma:         "25c1b33cf59e1e4ede5dda52f275a678f6bf1f564b2ec2578cc7f22536ef190b"
    sha256 ventura:        "e9e1092cfdf3fced88eabed8c2d957ded42ca9d65101908532139457b31ae6b0"
    sha256 monterey:       "df61cd8351c3751b65002a656f7b9ba911eed64a419de9ceccb0678b01548e31"
    sha256 x86_64_linux:   "d4b0205a35f1a49a253436d77f82f96b4608b77be0078d01874f3e96c3abde4b"
  end

  head do
    url "https://gitlab.nic.cz/knot/knot-dns.git", branch: "master"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  depends_on "pkg-config" => :build
  depends_on "sphinx-doc" => :build
  depends_on "fstrm"
  depends_on "gnutls"
  depends_on "libidn2"
  depends_on "libnghttp2"
  depends_on "lmdb"
  depends_on "protobuf-c"
  depends_on "userspace-rcu"

  uses_from_macos "libedit"

  # build patch to use `IPV6_PKTINFO` on macOS
  # submitted issue and build patch via https://gitlab.nic.cz/knot/knot-dns/-/issues/909
  patch :DATA

  def install
    system "autoreconf", "-fvi" if build.head?
    system "./configure", "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--with-configdir=#{etc}",
                          "--with-storage=#{var}/knot",
                          "--with-rundir=#{var}/run/knot",
                          "--prefix=#{prefix}",
                          "--with-module-dnstap",
                          "--enable-dnstap",
                          "--enable-quic"

    inreplace "samples/Makefile", "install-data-local:", "disable-install-data-local:"

    system "make"
    system "make", "install"
    system "make", "install-singlehtml"

    (buildpath/"knot.conf").write(knot_conf)
    etc.install "knot.conf"
  end

  def post_install
    (var/"knot").mkpath
  end

  def knot_conf
    <<~EOS
      server:
        rundir: "#{var}/knot"
        listen: [ "0.0.0.0@53", "::@53" ]

      log:
        - target: "stderr"
          any: "info"

      control:
        listen: "knot.sock"

      template:
        - id: "default"
          storage: "#{var}/knot"
    EOS
  end

  service do
    run opt_sbin/"knotd"
    require_root true
    input_path "/dev/null"
    log_path "/dev/null"
    error_log_path var/"log/knot.log"
  end

  test do
    system bin/"kdig", "@94.140.14.140", "www.knot-dns.cz", "+quic"
    system bin/"khost", "brew.sh"
    system sbin/"knotc", "conf-check"
  end
end

__END__
diff --git a/src/knot/server/quic-handler.c b/src/knot/server/quic-handler.c
index 0944900..f8ab263 100644
--- a/src/knot/server/quic-handler.c
+++ b/src/knot/server/quic-handler.c
@@ -13,6 +13,9 @@
     You should have received a copy of the GNU General Public License
     along with this program.  If not, see <https://www.gnu.org/licenses/>.
  */
+#ifdef __APPLE__
+#define __APPLE_USE_RFC_3542 /* to use IPV6_PKTINFO */
+#endif

 #include <netinet/in.h>
 #include <string.h>
diff --git a/src/knot/server/udp-handler.c b/src/knot/server/udp-handler.c
index 3b06fa9..5d85877 100644
--- a/src/knot/server/udp-handler.c
+++ b/src/knot/server/udp-handler.c
@@ -14,7 +14,9 @@
     along with this program.  If not, see <https://www.gnu.org/licenses/>.
  */

-#define __APPLE_USE_RFC_3542
+#ifdef __APPLE__
+#define __APPLE_USE_RFC_3542 /* to use IPV6_PKTINFO */
+#endif

 #include <assert.h>
 #include <dlfcn.h>
