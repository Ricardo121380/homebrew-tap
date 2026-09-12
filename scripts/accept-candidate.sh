#!/bin/bash
set -euo pipefail
candidate="$RUNNER_TEMP/omp-candidate/native-candidate"
evidence="$RUNNER_TEMP/omp-brew-evidence"
mkdir -p "$evidence"
exec > >(tee "$evidence/lifecycle.log") 2>&1
export OMP_ACCEPTANCE_CANDIDATE="$candidate"
python3 - <<'PY'
import os,json,hashlib
from pathlib import Path
p=Path(os.environ['OMP_ACCEPTANCE_CANDIDATE']);r=json.loads((p/'build-receipt.json').read_text())
assert r['sourceCommit']==os.environ['SOURCE_COMMIT']
for a in r['artifacts']:
 assert hashlib.sha256((p/a['filename']).read_bytes()).hexdigest()==a['sha256'][7:]
f=(p/'only-my-pi.rb').read_text()
base='https://github.com/Ricardo121380/only-my-pi/releases/download/v'+r['version']
assert f.count(base)==2
(p/'local-formula.rb').write_text(f.replace(base,p.as_uri()))
PY
brew tap-new --no-git omp-acceptance/local
formula="$(brew --repository)/Library/Taps/omp-acceptance/homebrew-local/Formula/only-my-pi.rb"
cp "$candidate/local-formula.rb" "$formula"
if brew help trust >/dev/null 2>&1; then brew trust --formula omp-acceptance/local/only-my-pi; fi
mkdir -p "$RUNNER_TEMP/omp-user/.pi/agent/sessions"
export PI_CODING_AGENT_DIR="$RUNNER_TEMP/omp-user/.pi/agent"
printf '%s\n' 'retained session fixture' > "$PI_CODING_AGENT_DIR/sessions/preserve.txt"
printf '%s\n' '{}' > "$PI_CODING_AGENT_DIR/settings.json"
check_identity() {
  omp admin version --json > "$evidence/$1-version.json"
  omp admin doctor --json > "$evidence/$1-doctor.json"
  jq -e --arg source "$SOURCE_COMMIT" '.ok == true and .sourceCommit == $source and .installation.channel == "homebrew"' "$evidence/$1-version.json"
  test "$(cat "$PI_CODING_AGENT_DIR/sessions/preserve.txt")" = 'retained session fixture'
  test "$(cat "$PI_CODING_AGENT_DIR/settings.json")" = '{}'
}
brew install --formula omp-acceptance/local/only-my-pi
check_identity install
brew test omp-acceptance/local/only-my-pi
python3 - "$formula" <<'PY'
import sys
from pathlib import Path
p=Path(sys.argv[1]);f=p.read_text();assert '  revision ' not in f
p.write_text(f.replace('  license "MIT"','  revision 1\n  license "MIT"'))
PY
brew upgrade --formula omp-acceptance/local/only-my-pi
check_identity upgrade
brew uninstall --formula omp-acceptance/local/only-my-pi
test ! -e "$(brew --prefix)/bin/omp"
test "$(cat "$PI_CODING_AGENT_DIR/sessions/preserve.txt")" = 'retained session fixture'
brew install --formula omp-acceptance/local/only-my-pi
check_identity reinstall
brew uninstall --formula omp-acceptance/local/only-my-pi
python3 - "$candidate" "$evidence" <<'PY'
import sys,json,hashlib
from pathlib import Path
c,e=map(Path,sys.argv[1:]);r=json.loads((c/'build-receipt.json').read_text())
report={'status':'HOMEBREW_CANDIDATE_LIFECYCLE_PASS','sourceCommit':r['sourceCommit'],'distributionId':r['distributionId'],'buildReceiptSha256':'sha256:'+hashlib.sha256((c/'build-receipt.json').read_bytes()).hexdigest(),'install':True,'formulaTest':True,'revisionUpgrade':True,'uninstall':True,'reinstall':True,'userDataPreserved':True,'publicTapInstall':False,'notes':['Exact signed candidate bytes; only formula asset URLs adapted to local files.','Upgrade is a formula revision upgrade of the same candidate, not a previous product version migration.']}
(e/'acceptance.json').write_text(json.dumps(report,indent=2)+'\n')
PY
