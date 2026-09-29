#!/usr/bin/env python3
"""GitHub-only port of the old publisher. No credentials in arguments or logs.

Version assets are immutable. Re-running may resume a matching public version;
feed/download swaps restore their previous bytes on upload or verification error.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / 'Tools/mac-release'
OUTPUT = ROOT / 'build/mac-release'
REPO = 'ismailakdag/clockin'
API = f'https://api.github.com/repos/{REPO}'
BASE = f'https://github.com/{REPO}/releases/download'
FEED_URL = f'{BASE}/macos-updates/appcast.xml'
NS = {'sparkle': 'http://www.andymatuschak.org/xml-namespaces/sparkle'}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


class NoAuthRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # API/upload calls must never forward the Git credential on redirects.
        require(not req.has_header('Authorization'), 'Refusing authenticated redirect.')
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def http(method, url, token=None, body=None, data=None, content_type=None, allow=()):
    headers = {'User-Agent': 'clockin-mac-release'}
    if token:
        require(urllib.parse.urlparse(url).hostname in ('api.github.com', 'uploads.github.com'),
                'Refusing to send credential to another host.')
        headers['Authorization'] = 'Bearer ' + token
        headers['Accept'] = 'application/vnd.github+json'
        headers['X-GitHub-Api-Version'] = '2022-11-28'
    if body is not None:
        data = json.dumps(body).encode()
        content_type = 'application/json'
    if content_type:
        headers['Content-Type'] = content_type
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.build_opener(NoAuthRedirect).open(request, timeout=300) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        if error.code in allow:
            return error.code, b''
        # Do not echo service bodies, headers or credentials, even on errors.
        raise RuntimeError(f'{method} to GitHub returned HTTP {error.code}.') from None
    except urllib.error.URLError:
        raise RuntimeError('GitHub request failed; check connectivity and retry.') from None


def api(method, url, token, **kwargs):
    status, data = http(method, url, token, **kwargs)
    return status, json.loads(data) if data else None


def anonymous(url):
    return http('GET', f'{url}?nocache={time.time_ns()}')[1]


def check_public(url, expected):
    for attempt in range(10):
        try:
            downloaded = anonymous(url)
            if downloaded == expected:
                return downloaded
        except RuntimeError:
            pass
        if attempt < 9:
            time.sleep(3)
    raise RuntimeError('Anonymous download did not match: ' + url)


def github_token():
    result = subprocess.run(
        ['git', '-c', 'credential.interactive=false', 'credential', 'fill'],
        input=f'protocol=https\nhost=github.com\npath={REPO}.git\n\n',
        capture_output=True, text=True,
        env={**os.environ, 'GIT_TERMINAL_PROMPT': '0'})
    values = dict(line.split('=', 1) for line in result.stdout.splitlines() if '=' in line)
    require(result.returncode == 0 and values.get('password'), 'No stored GitHub credential for the destination repository.')
    return values['password']


def upload(token, release, name, data, content_type):
    url = release['upload_url'].split('{')[0]
    return api('POST', f'{url}?name={urllib.parse.quote(name)}', token,
               data=data, content_type=content_type)[1]


def swap(token, release, name, data, content_type):
    # Upload first so a failed upload leaves the old asset available.
    new = upload(token, release, f'uploading-{time.time_ns()}-{name}', data, content_type)
    for old in release['assets']:
        if old['name'] == name:
            api('DELETE', f'{API}/releases/assets/{old["id"]}', token)
    api('PATCH', f'{API}/releases/assets/{new["id"]}', token, body={'name': name})


def replace_verified(token, name, data, content_type, validator=None):
    url = f'{BASE}/macos-updates/{name}'
    release = api('GET', f'{API}/releases/tags/macos-updates', token)[1]
    require(any(a['name'] == name for a in release['assets']), 'Missing existing stable asset: ' + name)
    previous = anonymous(url)
    try:
        swap(token, release, name, data, content_type)
        live = check_public(url, data)
        if validator:
            validator(live)
    except Exception:
        try:
            fresh = api('GET', f'{API}/releases/tags/macos-updates', token)[1]
            swap(token, fresh, name, previous, content_type)
            check_public(url, previous)
        except Exception:
            raise RuntimeError(f'{name} replacement AND rollback failed. Restore the saved stable asset from build/mac-release before retrying.') from None
        raise RuntimeError(f'{name} replacement failed; previous bytes restored and checked anonymously.') from None


def verify_feed(data, dmg, info):
    with tempfile.TemporaryDirectory(prefix='verify-public-', dir=OUTPUT) as directory:
        work = Path(directory)
        (work / 'appcast.xml').write_bytes(data)
        shutil.copy2(dmg, work / dmg.name)
        subprocess.run(['swift', str(TOOLS / 'verify-release.swift'),
                        str(work / 'appcast.xml'), str(info)], check=True)


def require_new_build(previous_feed, feed, build):
    old_root = ET.fromstring(previous_feed)
    old_builds = [int(node.text) for node in old_root.findall('.//sparkle:version', NS)]
    require(old_builds, 'Live feed has no build numbers.')
    require(int(build) > max(old_builds) or (int(build) == max(old_builds) and previous_feed == feed),
            'Build must increase beyond the live feed; same-build retry requires identical feed bytes.')


def local_release(version):
    candidates = [p for p in (OUTPUT / 'releases').glob(f'{version}-*') if (p / 'ready').is_file()]
    require(len(candidates) == 1, 'Expected exactly one prepared release for this version; move other candidates aside.')
    release = candidates[0]
    build = release.name[len(version) + 1:]
    require(re.fullmatch(r'[1-9][0-9]*', build), 'Invalid prepared build number.')
    work = OUTPUT / f'{version}-{build}'
    app = work / 'export/Clockin.app'
    info = app / 'Contents/Info.plist'
    dmg = release / f'Clockin-{version}-{build}.dmg'
    notes = release / f'Clockin-{version}-{build}.md'
    commit = (release / 'source-commit.txt').read_text().strip()
    require(re.fullmatch(r'[a-f0-9]{40}', commit), 'Invalid recorded source commit.')
    require(not (release / 'source-status.txt').read_text().strip(), 'The archive was built from a dirty checkout; commit reviewed changes and build again.')
    current = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
    status = subprocess.check_output(['git', '-C', str(ROOT), 'status', '--porcelain', '--untracked-files=all'], text=True)
    require(current == commit and not status.strip(), 'Publish from the clean source commit used for the archive.')
    require(notes.read_bytes() == (ROOT / f'docs/release-notes-mac-{version}.md').read_bytes(), 'Release notes changed since packaging.')
    subprocess.run([str(TOOLS / 'verify-app.sh'), str(app), version, build], check=True)
    for path, kind in ((app, 'execute'), (dmg, 'open')):
        subprocess.run(['xcrun', 'stapler', 'validate', str(path)], check=True)
        command = ['spctl', '-a', '-vv', '--type', kind]
        if kind == 'open':
            command += ['--context', 'context:primary-signature']
        subprocess.run(command + [str(path)], check=True)
    subprocess.run(['codesign', '--verify', '--strict', str(dmg)], check=True)
    expected = ''.join(f'{digest((release / name).read_bytes())}  {name}\n'
                       for name in (dmg.name, 'appcast.xml'))
    require((release / 'SHA256SUMS').read_text() == expected, 'SHA256SUMS does not match the prepared files.')
    verify_feed((release / 'appcast.xml').read_bytes(), dmg, info)
    with info.open('rb') as stream:
        plist = plistlib.load(stream)
    require(plist['CFBundleVersion'] == build, 'Build metadata mismatch.')
    return release, build, dmg, notes, commit, info


def publish(version):
    release_dir, build, dmg, notes, commit, info = local_release(version)
    token = github_token()
    repo = api('GET', API, token)[1]
    require(repo.get('permissions', {}).get('push'), 'GitHub credential cannot publish to ' + REPO)
    status, remote_commit = api('GET', f'{API}/commits/{commit}', token, allow=(404, 422))
    require(status == 200 and remote_commit['sha'] == commit,
            'The build source commit must already exist in ismailakdag/clockin. Resolve licensing/source distribution before publishing; this script never pushes code.')
    # Save old stable bytes locally before any public mutation.
    previous_feed = anonymous(FEED_URL)
    previous_download = anonymous(f'{BASE}/macos-updates/Clockin.dmg')
    backup = Path(tempfile.mkdtemp(prefix='publish-backup-', dir=OUTPUT))
    (backup / 'appcast.xml').write_bytes(previous_feed)
    (backup / 'Clockin.dmg').write_bytes(previous_download)
    feed = (release_dir / 'appcast.xml').read_bytes()
    require_new_build(previous_feed, feed, build)
    tag = f'macos-v{version}'
    status, version_release = api('GET', f'{API}/releases/tags/{tag}', token, allow=(404,))
    if status == 404:
        # A pre-existing tag must already identify the build commit.
        tag_status, tag_commit = api('GET', f'{API}/commits/{tag}', token, allow=(404, 422))
        require(tag_status != 200 or tag_commit['sha'] == commit, 'Existing version tag points at another commit.')
        print('Creating draft versioned release, uploading immutable assets, then making it public.', flush=True)
        version_release = api('POST', f'{API}/releases', token, body={
            'tag_name': tag, 'target_commitish': commit, 'name': f'Clockin for Mac {version}',
            'body': notes.read_text().strip() + '\n\nRequires macOS 14 or later; Apple Silicon and Intel. Open the DMG and drag Clockin into Applications. The app and DMG are Developer ID signed and notarized.',
            'draft': True, 'prerelease': False, 'make_latest': 'false'})[1]
        for path in (dmg, release_dir / 'SHA256SUMS'):
            upload(token, version_release, path.name, path.read_bytes(), 'application/octet-stream')
        api('PATCH', f'{API}/releases/{version_release["id"]}', token,
            body={'draft': False, 'make_latest': 'false'})
    else:
        require(not version_release['draft'] and not version_release['prerelease'],
                'An incomplete draft/prerelease already exists. Inspect it manually; no assets were overwritten.')
        remote_tag = api('GET', f'{API}/commits/{tag}', token)[1]
        require(remote_tag['sha'] == commit, 'Existing release tag does not match the source commit.')
        print('Resuming existing public release; checking immutable assets before touching the feed.', flush=True)
    downloaded = check_public(f'{BASE}/{tag}/{dmg.name}', dmg.read_bytes())
    check_public(f'{BASE}/{tag}/SHA256SUMS', (release_dir / 'SHA256SUMS').read_bytes())
    stable = api('GET', f'{API}/releases/tags/macos-updates', token)[1]
    require(not stable['draft'] and not stable['prerelease'], 'Stable release must be public and not a prerelease.')
    api('PATCH', f'{API}/releases/{stable["id"]}', token, body={'make_latest': 'false'})
    print('Replacing and anonymously checking the fixed Clockin.dmg download.', flush=True)
    replace_verified(token, 'Clockin.dmg', downloaded, 'application/octet-stream')
    print('Publishing the signed feed last; then checking public bytes and signatures.', flush=True)
    replace_verified(token, 'appcast.xml', feed, 'application/xml',
                     lambda live: verify_feed(live, dmg, info))
    print(f'Published Clockin {version} ({build}). Previous stable bytes: {backup}', flush=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('version')
    parser.add_argument('--yes', action='store_true')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args(argv)
    require(re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', args.version), 'Version must be x.y.z.')
    if args.dry_run:
        for line in (
            f'Find exactly one ready {args.version}-BUILD release under {OUTPUT}/releases.',
            'Require a clean checkout at the recorded source commit and unchanged release notes.',
            'Verify app metadata, universal slices, Developer ID signatures, app/DMG stapling and Gatekeeper.',
            'Check SHA256SUMS and the signed feed/archive with the shipped public key.',
            'Read Git credential in memory; check push permission for ismailakdag/clockin.',
            'Require the exact build source commit in the destination repository and matching existing version tag.',
            'Back up the anonymous live feed and Clockin.dmg under build/mac-release; require a higher build (or identical retry).',
            f'Create draft macos-v{args.version} with make_latest=false; upload versioned DMG and SHA256SUMS.',
            'Publish the versioned release with make_latest=false; never overwrite version assets.',
            'For a retry, require an existing public release at the same source commit and identical public assets.',
            'Download versioned DMG and SHA256SUMS anonymously and require byte-for-byte equality.',
            'Keep macos-updates make_latest=false; upload temporary Clockin.dmg, swap name, check anonymously.',
            'Upload temporary signed appcast.xml LAST, swap name, check anonymous bytes and Ed25519 signatures.',
            'On stable asset swap/verification failure, restore previous bytes and verify the rollback anonymously.',
            'No commits, pushes, version edits, Keychain export, or website deployment.'):
            print(line)
        return
    require(args.yes, 'Publishing requires --yes; use --dry-run to preview.')
    publish(args.version)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, ValueError, KeyError, ET.ParseError, subprocess.CalledProcessError) as error:
        # subprocess failures here contain command names/public paths only.
        print(f'Publish stopped: {error}', file=sys.stderr)
        sys.exit(1)
