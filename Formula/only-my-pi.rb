# Generated from e63e1a3b870fb548ce4c2c08ed25d5b767b7e21b; core identity sha256:14ac2484055e3eb092103e74754666d6f19490dd2d1da577861ba4e301f30600
class OnlyMyPi < Formula
  desc "Guarded terminal coding agent built on Pi (Public Preview)"
  homepage "https://github.com/Ricardo121380/only-my-pi"
  url "https://github.com/Ricardo121380/only-my-pi/releases/download/v0.4.0-preview.2/only-my-pi-0.4.0-preview.2.tgz"
  version "0.4.0-preview.2"
  sha256 "4d210c70dad327c87de488e8fa7bd1fc566849a4f1aa1b151080789798b7e0bb"
  license "MIT"

  depends_on arch: :arm64
  depends_on macos: :sonoma
  depends_on "node@24"
  depends_on "git"
  skip_clean :all

  resource "only-my-pi-runtime-darwin-arm64" do
    url "https://github.com/Ricardo121380/only-my-pi/releases/download/v0.4.0-preview.2/only-my-pi-runtime-darwin-arm64-0.4.0-preview.2.tgz"
    sha256 "c239dc21695179b092b8d56afe317734912bb79234eec1c27186776eb39a4804"
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
        {"formatVersion":1,"channel":"homebrew","version":"0.4.0-preview.2"}
      JSON
    end
    system Formula["node@24"].opt_bin/"node", libexec/"lib/node_modules/only-my-pi/loader.mjs", "--verify-install"
  end

  def caveats
    <<~EOS
      This is OMP 0.4.0-preview.2, a Public Preview.
      Run omp; use omp admin pi for model authentication.
      Existing Pi configuration and sessions are preserved on uninstall.
    EOS
  end

  test do
    assert_match "only-my-pi 0.4.0-preview.2", shell_output("#{bin}/omp --version")
    assert_match '"channel": "homebrew"', shell_output("#{bin}/omp admin version --json")
    assert_match '"ok": true', shell_output("#{bin}/omp admin doctor --json")
    assert_match "0.84.3", shell_output("#{bin}/omp admin pi --version")
    refute_path_exists testpath/".pi"
  end
end
