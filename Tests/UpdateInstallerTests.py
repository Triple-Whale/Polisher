import pathlib
import plistlib
import subprocess
import tempfile
import time

root = pathlib.Path(__file__).resolve().parents[1]
fixture = pathlib.Path(tempfile.mkdtemp(prefix='polisher-installer-tests-'))
helper = root / 'Polisher/Resources/install-update.sh'


def make_app(path, marker, version):
    executable = path / 'Contents/MacOS/Test'
    executable.parent.mkdir(parents=True)
    source = path.parent / (version + '.c')
    source.write_text('#include <stdio.h>\nint main(void) { FILE *f = fopen("' + str(marker) + '", "w"); if (!f) return 1; fputs("' + version + '", f); fclose(f); return 0; }\n')
    subprocess.run(['clang', str(source), '-o', str(executable)], check=True)
    with (path / 'Contents/Info.plist').open('wb') as out:
        plistlib.dump({'CFBundleIdentifier': 'com.triplewhale.polisher.installer-test', 'CFBundleName': 'Polisher Installer Test', 'CFBundleExecutable': 'Test', 'CFBundlePackageType': 'APPL', 'CFBundleVersion': version, 'LSUIElement': True}, out)
    (path / 'version.txt').write_text(version)


def await_marker(marker, expected):
    for _ in range(50):
        if marker.exists() and marker.read_text() == expected:
            return
        time.sleep(.1)
    raise AssertionError('Updated app did not launch: ' + str(marker))


success = fixture / 'success with spaces'
installed = success / 'Polisher.app'
staging = success / '.Polisher-update-test'
candidate = staging / 'download/Polisher.app'
marker = success / 'launched.txt'
make_app(installed, marker, '27')
make_app(candidate, marker, '28')
status = success / 'status.txt'
subprocess.run(['bash', str(helper), '99999999', str(candidate), str(installed), str(staging), str(status)], check=True)
assert (installed / 'version.txt').read_text() == '28'
assert (staging / 'Previous.app/version.txt').read_text() == '27'
assert not status.exists()
await_marker(marker, '28')

rollback = fixture / 'rollback'
installed = rollback / 'Polisher.app'
staging = rollback / '.Polisher-update-test'
staging.mkdir(parents=True)
marker = rollback / 'launched.txt'
make_app(installed, marker, '27')
candidate = installed / 'nested/Polisher.app'
make_app(candidate, marker, '28')
status = rollback / 'status.txt'
result = subprocess.run(['bash', str(helper), '99999999', str(candidate), str(installed), str(staging), str(status)], capture_output=True)
assert result.returncode == 1
assert (installed / 'version.txt').read_text() == '27'
assert 'restored' in status.read_text()
await_marker(marker, '27')
print('Installer replacement, relaunch, paths with spaces, and rollback tests passed')
