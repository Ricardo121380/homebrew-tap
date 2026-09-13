# Generated from 38e71adc8c2c52cc332db288f5dcdd14f73bd8cb; core identity sha256:a7af13f85bafadd22f591f88071078ffba8268c2ddee786f35bc000b10a4b75a
class OnlyMyPi < Formula
  desc "Guarded terminal coding agent built on Pi (Public Preview)"
  homepage "https://github.com/Ricardo121380/only-my-pi"
  url "https://github.com/Ricardo121380/only-my-pi/releases/download/v0.4.0-preview.1/only-my-pi-0.4.0-preview.1.tgz"
  version "0.4.0-preview.1"
  sha256 "d2db715b33e0120cf21c66fdd882cfb44a7bc0c3573d77c2ec7ab0f792e3cd37"
  license "MIT"

  depends_on arch: :arm64
  depends_on macos: :sonoma
  depends_on "node@24"
  depends_on "git"
  skip_clean :all

  resource "only-my-pi-runtime-darwin-arm64" do
    url "https://github.com/Ricardo121380/only-my-pi/releases/download/v0.4.0-preview.1/only-my-pi-runtime-darwin-arm64-0.4.0-preview.1.tgz"
    sha256 "2a8a22df9550ce5949af97c16df0c5f8e66babe30713efb979f6265ef4d143a2"
  end

  def install
    cli = libexec/"lib/node_modules/only-my-pi"
    cli.install Dir["*"]
    # Preserve the verified archive through Homebrew's Mach-O relocation pass.
    libexec.install resource("only-my-pi-runtime-darwin-arm64").cached_download => "runtime.tgz"
    node = Formula["node@24"].opt_bin/"node"
    (cli/"omp").write <<~SH
      #!/bin/sh
      export PATH="#{Formula["node@24"].opt_bin}:#{Formula["git"].opt_bin}:$PATH"
      exec "#{node}" "#{cli}/loader.mjs" "$@"
    SH
    chmod 0755, cli/"omp"
    bin.install_symlink cli/"omp"
  end

  def post_install
    runtime = libexec/"lib/node_modules/only-my-pi-runtime-darwin-arm64"
    unless runtime.exist?
      runtime.mkpath
      system "/usr/bin/tar", "-xzf", libexec/"runtime.tgz", "-C", runtime, "--strip-components", "1"
      File.write(runtime/"distribution-installation.json", <<~JSON)
        {"formatVersion":1,"channel":"homebrew","version":"0.4.0-preview.1"}
      JSON
    end
    system Formula["node@24"].opt_bin/"node", libexec/"lib/node_modules/only-my-pi/loader.mjs", "--verify-install"
  end

  def caveats
    <<~EOS
      This is OMP 0.4.0-preview.1, a Public Preview.
      Run omp; use omp admin pi for model authentication.
      Existing Pi configuration and sessions are preserved on uninstall.
    EOS
  end

  test do
    assert_match "only-my-pi 0.4.0-preview.1", shell_output("#{bin}/omp --version")
    assert_match '"channel": "homebrew"', shell_output("#{bin}/omp admin version --json")
    assert_match '"ok": true', shell_output("#{bin}/omp admin doctor --json")
    assert_match "0.84.3", shell_output("#{bin}/omp admin pi --version")
    refute_path_exists testpath/".pi"
  end
end
